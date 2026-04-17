//
//  TemplateMatchEngine.swift
//  ENVI
//
//  Phase 3, Task 2 — slot-to-asset matching engine.
//
//  Given a `VideoTemplate` (from Task 1 — VideoTemplateModels) and the
//  user's `ClassificationCache`, this actor:
//
//    1. For each slot, queries the cache with a SwiftData `Predicate` that
//       encodes every hard filter we can push down (mediaType, isUtility,
//       aestheticsScore, creationDate window). Remaining hard filters that
//       depend on decoded metadata (orientation, subtype bits, duration,
//       label inclusion/exclusion) are applied in-memory immediately after.
//
//    2. Scores each candidate on a 0..1 scale using the weights from
//       03-PLAN.md:
//         +0.40  label intersection with slot.preferredLabels
//         +0.20  normalized aesthetics score
//         +0.15  face / person count match
//         +0.10  recency-preference window match
//         +0.10  "within last 30 days" recency bonus
//         +0.05  favorite OR burst user-pick
//
//    3. Picks a best match per slot greedily (highest-score slot first), and
//       then attempts a "cohesion pass" via `EmbeddingIndex.clusters()` /
//       `findSimilar(to:k:)` to prefer a visually coherent set. When every
//       filled slot ends up in the same cluster, each slot receives a +0.10
//       cohesion bonus (capped at 1.0 overall).
//
//    4. Respects the global constraint: no asset fills two slots. Used IDs
//       are tracked through the whole populate pass.
//
//    5. Returns up to 5 alternates per slot for the swap flow.
//
//  The engine is isolated to its own actor — all public methods are `async`
//  and safe to call from the main actor. Cache and index accesses hop to
//  their own actors naturally.
//
//  NOTE: Phase 3, Task 1 (`VideoTemplateModels.swift`) is written in
//  parallel with this file. This engine references types defined there by
//  name: `VideoTemplate`, `TemplateSlot`, `MediaRequirements`, `FilledSlot`,
//  `PopulatedTemplate`, `MediaTypeFilter`, `Orientation`,
//  `FaceCountFilter`, `PersonCountFilter`, `RecencyPreference`,
//  `PHAssetMediaSubtypeFilter`. The Task 1 spec in `.planning/phases/
//  template-tab-v1/03-PLAN.md` is authoritative for those types.
//

import Foundation
import Photos
import SwiftData

// MARK: - Engine

actor TemplateMatchEngine {

    // MARK: Config

    /// Minimum total score a candidate must exceed to fill a slot.
    /// Below this the slot stays empty (contributes 0 to `fillRate`).
    static let matchThreshold: Double = 0.3

    /// How many top-scoring alternates (runner-ups) we surface per slot.
    static let alternatesCount: Int = 5

    /// Cohesion bonus applied per filled slot when the selected set clusters.
    static let cohesionBonus: Double = 0.10

    /// Absolute cap so bonuses can't push a score past 1.0.
    static let maxScore: Double = 1.0

    // MARK: Init

    init() {}

    // MARK: - Public API

    /// Populate a single template against the user's classified library.
    func populate(
        template: VideoTemplate,
        from cache: ClassificationCache,
        using index: EmbeddingIndex
    ) async -> PopulatedTemplate {
        // Candidate pool per slot, pre-filtered + pre-scored against this slot.
        // Score arrays stay parallel to the candidate arrays so we can
        // re-rank during the cohesion pass without re-scoring.
        var perSlotScored: [[ScoredCandidate]] = []
        perSlotScored.reserveCapacity(template.slots.count)

        for slot in template.slots {
            let candidates = await candidates(for: slot, from: cache)
            let scored = candidates
                .map { ScoredCandidate(asset: $0, score: Self.score($0, against: slot)) }
                .sorted { $0.score > $1.score }
            perSlotScored.append(scored)
        }

        // Greedy assignment — slots are processed in their declared order.
        // For each slot we pick the highest-score candidate whose localID is
        // not already used. Candidates below `matchThreshold` are skipped,
        // leaving the slot empty (contributes to fill rate).
        var usedIDs = Set<String>()
        var chosen: [Int: ScoredCandidate] = [:]

        for (slotIdx, scored) in perSlotScored.enumerated() {
            guard let pick = scored.first(where: { !usedIDs.contains($0.asset.localIdentifier) }),
                  pick.score >= Self.matchThreshold
            else { continue }
            chosen[slotIdx] = pick
            usedIDs.insert(pick.asset.localIdentifier)
        }

        // Cohesion pass. Only meaningful when 2+ slots were filled.
        let clusterMap = await index.clusters()
        if chosen.count >= 2 {
            await applyCohesionPass(
                chosen: &chosen,
                usedIDs: &usedIDs,
                perSlotScored: perSlotScored,
                clusterMap: clusterMap,
                index: index
            )
        }

        // Materialize FilledSlots in original slot order.
        var filled: [FilledSlot] = []
        filled.reserveCapacity(template.slots.count)
        var totalScore: Double = 0
        var filledCount: Int = 0

        for (slotIdx, slot) in template.slots.enumerated() {
            let pick = chosen[slotIdx]
            let alternates: [ClassifiedAsset] = Self.alternates(
                from: perSlotScored[slotIdx],
                excludingChosen: pick?.asset.localIdentifier,
                excludingUsed: usedIDs,
                limit: Self.alternatesCount
            )

            if let pick {
                totalScore += pick.score
                filledCount += 1
            }

            filled.append(
                FilledSlot(
                    slot: slot,
                    matchedAsset: pick?.asset,
                    matchScore: pick?.score ?? 0,
                    alternates: alternates
                )
            )
        }

        let fillRate: Double = template.slots.isEmpty
            ? 0
            : Double(filledCount) / Double(template.slots.count)
        let overall: Double = filledCount == 0 ? 0 : totalScore / Double(filledCount)

        return PopulatedTemplate(
            template: template,
            filledSlots: filled,
            fillRate: fillRate,
            overallScore: overall,
            previewThumbnail: nil
        )
    }

    /// Populate a list of templates. Each template gets an independent used-
    /// ID set so an asset can appear in different templates at once — the
    /// within-template uniqueness constraint is still enforced.
    func populateAll(
        templates: [VideoTemplate],
        from cache: ClassificationCache,
        using index: EmbeddingIndex
    ) async -> [PopulatedTemplate] {
        var out: [PopulatedTemplate] = []
        out.reserveCapacity(templates.count)
        for t in templates {
            out.append(await populate(template: t, from: cache, using: index))
        }
        return out
    }

    /// Swap a single slot's matched asset for the given one. Re-computes
    /// the score for the swapped slot and refreshes `overallScore` /
    /// `fillRate`. Does not re-score the other slots.
    func swap(
        slot: TemplateSlot,
        in populated: PopulatedTemplate,
        to asset: ClassifiedAsset
    ) -> PopulatedTemplate {
        var newSlots = populated.filledSlots
        guard let idx = newSlots.firstIndex(where: { $0.slot.id == slot.id }) else {
            return populated
        }

        let newScore = Self.score(asset, against: slot)
        let old = newSlots[idx]

        // Merge old alternates so we can surface the previously-picked asset
        // as a future candidate (but drop the asset we just swapped in).
        var altPool: [ClassifiedAsset] = old.alternates
        if let prevPick = old.matchedAsset {
            altPool.insert(prevPick, at: 0)
        }
        altPool.removeAll { $0.localIdentifier == asset.localIdentifier }
        let newAlternates = Array(altPool.prefix(Self.alternatesCount))

        newSlots[idx] = FilledSlot(
            slot: slot,
            matchedAsset: asset,
            matchScore: newScore,
            alternates: newAlternates
        )

        // Recompute aggregate stats.
        let filledCount = newSlots.reduce(into: 0) { $0 += $1.matchedAsset == nil ? 0 : 1 }
        let scoreSum = newSlots.reduce(0.0) { $0 + ($1.matchedAsset == nil ? 0 : $1.matchScore) }
        let total = populated.template.slots.count
        let fillRate = total == 0 ? 0 : Double(filledCount) / Double(total)
        let overall = filledCount == 0 ? 0 : scoreSum / Double(filledCount)

        return PopulatedTemplate(
            template: populated.template,
            filledSlots: newSlots,
            fillRate: fillRate,
            overallScore: overall,
            previewThumbnail: populated.previewThumbnail
        )
    }

    // MARK: - Candidate fetching

    /// Runs the hard-filter predicate against the cache, then applies the
    /// filters that require decoded metadata (orientation, subtype bits,
    /// duration, label inclusion / exclusion).
    private func candidates(
        for slot: TemplateSlot,
        from cache: ClassificationCache
    ) async -> [ClassifiedAsset] {
        let req = slot.requirements

        // Push-down filters: mediaType, isUtility, aestheticsScore, creationDate.
        let mediaTypeInts: Set<Int> = Set(req.acceptedMediaTypes.map { Self.phMediaTypeInt(for: $0) })
        let requireNonUtility = req.requireNonUtility
        let minAesthetics = req.minimumAestheticsScore
        let sinceDate: Date? = Self.creationDateFloor(for: req.recencyPreference)

        let predicate = #Predicate<ClassifiedAsset> { asset in
            mediaTypeInts.contains(asset.mediaType)
                && (!requireNonUtility || asset.isUtility == false)
                && asset.aestheticsScore >= minAesthetics
                && (sinceDate == nil || (asset.creationDate != nil && asset.creationDate! >= sinceDate!))
        }

        let base: [ClassifiedAsset]
        do {
            base = try await cache.query(predicate: predicate)
        } catch {
            return []
        }

        // In-memory refinement for filters that need decoded metadata.
        return base.filter { Self.passesInMemoryFilters($0, requirements: req) }
    }

    // MARK: - Cohesion pass

    /// If the initial greedy picks span multiple clusters, attempt to swap
    /// low-confidence picks for alternates that belong to the dominant
    /// cluster. When every filled slot ends up in the same cluster (post-
    /// swap) we apply a per-slot `+cohesionBonus`.
    private func applyCohesionPass(
        chosen: inout [Int: ScoredCandidate],
        usedIDs: inout Set<String>,
        perSlotScored: [[ScoredCandidate]],
        clusterMap: [String: Int],
        index: EmbeddingIndex
    ) async {
        guard !clusterMap.isEmpty else { return }

        // Tally clusters across chosen picks. -1 (noise) is excluded.
        var counts: [Int: Int] = [:]
        for (_, c) in chosen {
            if let label = clusterMap[c.asset.localIdentifier], label >= 0 {
                counts[label, default: 0] += 1
            }
        }
        // Pick the dominant cluster (the one most chosen slots are in).
        guard let dominant = counts.max(by: { $0.value < $1.value })?.key else { return }

        // Sort chosen slots by ascending score — low-confidence ones first.
        let slotOrder: [Int] = chosen
            .sorted { $0.value.score < $1.value.score }
            .map { $0.key }

        for slotIdx in slotOrder {
            guard let current = chosen[slotIdx] else { continue }
            // Already in the dominant cluster? Nothing to swap.
            if clusterMap[current.asset.localIdentifier] == dominant { continue }

            // Look at alternates: prefer one in the dominant cluster that
            // still meets threshold and isn't used elsewhere.
            let alt = perSlotScored[slotIdx].first { cand in
                cand.asset.localIdentifier != current.asset.localIdentifier
                    && !usedIDs.contains(cand.asset.localIdentifier)
                    && cand.score >= Self.matchThreshold
                    && clusterMap[cand.asset.localIdentifier] == dominant
            }

            // Fallback: use embedding similarity to find a close neighbour
            // that is itself in our slot's candidate pool AND in-cluster.
            var swapPick: ScoredCandidate? = alt
            if swapPick == nil {
                let neighbours = await index.findSimilar(
                    to: current.asset.localIdentifier,
                    k: 10
                )
                let neighbourSet = Set(neighbours)
                swapPick = perSlotScored[slotIdx].first { cand in
                    cand.asset.localIdentifier != current.asset.localIdentifier
                        && !usedIDs.contains(cand.asset.localIdentifier)
                        && cand.score >= Self.matchThreshold
                        && neighbourSet.contains(cand.asset.localIdentifier)
                        && clusterMap[cand.asset.localIdentifier] == dominant
                }
            }

            if let pick = swapPick {
                usedIDs.remove(current.asset.localIdentifier)
                usedIDs.insert(pick.asset.localIdentifier)
                chosen[slotIdx] = pick
            }
        }

        // Final cohesion check — if every chosen slot is now in the dominant
        // cluster, apply the bonus.
        let allCohesive = chosen.values.allSatisfy {
            clusterMap[$0.asset.localIdentifier] == dominant
        }
        if allCohesive {
            for (k, v) in chosen {
                chosen[k] = ScoredCandidate(
                    asset: v.asset,
                    score: min(Self.maxScore, v.score + Self.cohesionBonus)
                )
            }
        }
    }

    // MARK: - Scoring

    /// Combined 0..1 slot-fit score. Components are documented in the
    /// module header and 03-PLAN.md.
    static func score(_ asset: ClassifiedAsset, against slot: TemplateSlot) -> Double {
        let req = slot.requirements
        var score: Double = 0

        // 1. Label match (+0.40 max).
        if !req.preferredLabels.isEmpty {
            let preferred = Set(req.preferredLabels.map { $0.lowercased() })
            let have = Set(asset.topLabels.map { $0.lowercased() })
            let hits = preferred.intersection(have).count
            score += 0.40 * (Double(hits) / Double(preferred.count))
        }

        // 2. Aesthetics (+0.20 max, normalizes -1..1 to 0..1).
        let aestheticNorm = max(0, min(1, (asset.aestheticsScore + 1) / 2))
        score += 0.20 * aestheticNorm

        // 3. Face / person count match (+0.15 max).
        if faceCountMatches(req.preferredFaceCount, faceCount: asset.faceCount)
            && personCountMatches(req.preferredPersonCount, personCount: asset.personCount)
        {
            score += 0.15
        }

        // 4. Recency-preference window (+0.10).
        if let creation = asset.creationDate,
           let since = creationDateFloor(for: req.recencyPreference),
           creation >= since
        {
            score += 0.10
        }

        // 5. General recency — last 30 days (+0.10). Intentionally separate
        //    from the slot's explicit recencyPreference so a slot asking for
        //    "any" still rewards fresh content (per 03-PLAN).
        if let creation = asset.creationDate,
           creation >= Date().addingTimeInterval(-30 * 86_400)
        {
            score += 0.10
        }

        // 6. Favorite / burst user-pick (+0.05). Requires decoding
        //    ExtractedMetadata (AssetSurface) from the cached blob.
        if let surface = decodeSurface(from: asset) {
            let isPick = (surface.burstSelectionTypesRawValue
                & PHAssetBurstSelectionType.userPick.rawValue) != 0
            if surface.isFavorite || isPick {
                score += 0.05
            }
        }

        return min(Self.maxScore, score)
    }

    // MARK: - In-memory filter evaluation

    /// Applies filters that require decoded metadata. Fast-paths when the
    /// filter is nil / empty so we don't decode the blob unnecessarily.
    static func passesInMemoryFilters(
        _ asset: ClassifiedAsset,
        requirements req: MediaRequirements
    ) -> Bool {
        // Excluded labels (no decode needed).
        if !req.excludedLabels.isEmpty {
            let have = Set(asset.topLabels.map { $0.lowercased() })
            let excluded = Set(req.excludedLabels.map { $0.lowercased() })
            if !have.isDisjoint(with: excluded) { return false }
        }

        // Subtype bits — bitmask check against the raw PHAssetMediaSubtype.
        let subtype = PHAssetMediaSubtype(rawValue: asset.mediaSubtypeRaw)
        for required in req.requireSubtypes {
            if !subtype.contains(Self.phSubtype(for: required)) { return false }
        }
        for excluded in req.excludeSubtypes {
            if subtype.contains(Self.phSubtype(for: excluded)) { return false }
        }

        // Orientation + duration need the decoded AssetSurface.
        let needsSurface = req.preferredOrientation != nil || req.durationRange != nil
        if needsSurface {
            guard let surface = decodeSurface(from: asset) else {
                // No metadata decoded → fail the hard filter conservatively.
                return false
            }
            if let pref = req.preferredOrientation {
                let actual = orientation(pixelWidth: surface.pixelWidth,
                                         pixelHeight: surface.pixelHeight)
                if actual != pref { return false }
            }
            if let range = req.durationRange {
                let dur = surface.duration ?? 0
                if !range.contains(dur) { return false }
            }
        }

        return true
    }

    // MARK: - Helpers

    /// Decodes the `AssetSurface` out of the cached metadata blob.
    static func decodeSurface(from asset: ClassifiedAsset) -> AssetSurface? {
        guard !asset.metadata.isEmpty else { return nil }
        return (try? JSONDecoder().decode(ExtractedMetadata.self, from: asset.metadata))?.surface
    }

    /// Map a `PHAssetMediaSubtypeFilter` (Task 1 enum) to the canonical
    /// `PHAssetMediaSubtype` bit used in the bitmask check.
    static func phSubtype(for filter: PHAssetMediaSubtypeFilter) -> PHAssetMediaSubtype {
        switch filter {
        case .screenshot:  return .photoScreenshot
        case .panorama:    return .photoPanorama
        case .hdr:         return .photoHDR
        case .live:        return .photoLive
        case .depthEffect: return .photoDepthEffect
        case .slomo:       return .videoHighFrameRate
        case .timelapse:   return .videoTimelapse
        case .cinematic:   return .videoCinematic
        case .spatial:     return .spatialMedia
        }
    }

    /// Map a `MediaTypeFilter` (Task 1 enum) to the raw `PHAssetMediaType`
    /// integer that ClassifiedAsset.mediaType stores.
    static func phMediaTypeInt(for filter: MediaTypeFilter) -> Int {
        switch filter {
        case .photo: return PHAssetMediaType.image.rawValue
        case .video: return PHAssetMediaType.video.rawValue
        case .livePhoto: return PHAssetMediaType.image.rawValue
        }
    }

    /// Floor date for a recency preference, or nil for "any".
    static func creationDateFloor(for recency: RecencyPreference) -> Date? {
        switch recency {
        case .any: return nil
        case .recent30Days: return Date().addingTimeInterval(-30 * 86_400)
        case .recent7Days: return Date().addingTimeInterval(-7 * 86_400)
        }
    }

    /// Derives an `Orientation` from pixel dimensions.
    static func orientation(pixelWidth: Int, pixelHeight: Int) -> Orientation {
        if pixelWidth == pixelHeight { return .square }
        return pixelWidth > pixelHeight ? .landscape : .portrait
    }

    static func faceCountMatches(_ filter: FaceCountFilter?, faceCount: Int) -> Bool {
        guard let filter else { return true }
        switch filter {
        case .any: return true
        case FaceCountFilter.none: return faceCount == 0
        case .exactly(let n): return faceCount == n
        case .group: return faceCount >= 2
        }
    }

    static func personCountMatches(_ filter: PersonCountFilter?, personCount: Int) -> Bool {
        guard let filter else { return true }
        switch filter {
        case .any: return true
        case PersonCountFilter.none: return personCount == 0
        case .exactly(let n): return personCount == n
        case .group: return personCount >= 2
        }
    }

    /// Build the alternates list for a slot: top N candidates excluding
    /// the chosen pick and anything used elsewhere in this template.
    static func alternates(
        from scored: [ScoredCandidate],
        excludingChosen chosenID: String?,
        excludingUsed usedIDs: Set<String>,
        limit: Int
    ) -> [ClassifiedAsset] {
        var out: [ClassifiedAsset] = []
        out.reserveCapacity(limit)
        for cand in scored {
            let id = cand.asset.localIdentifier
            if id == chosenID { continue }
            if usedIDs.contains(id) { continue }
            if cand.score < Self.matchThreshold { break } // scored is desc-sorted
            out.append(cand.asset)
            if out.count >= limit { break }
        }
        return out
    }
}

// MARK: - Internal value types

/// A candidate + its pre-computed slot-fit score. Used internally by the
/// greedy assignment loop so we don't re-score during the cohesion pass.
struct ScoredCandidate {
    let asset: ClassifiedAsset
    let score: Double
}
