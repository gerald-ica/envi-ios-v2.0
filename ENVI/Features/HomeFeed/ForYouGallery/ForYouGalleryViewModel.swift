import Foundation
import Combine
import Photos

/// ViewModel powering the For You / Gallery dual-mode Tab 0.
///
/// Loads template-generated content pieces from camera-roll classifications,
/// manages approve/disapprove state, and feeds the Gallery grid with approved
/// items from `ApprovedMediaLibraryStore`.
@MainActor
final class ForYouGalleryViewModel: ObservableObject {

    // MARK: - Segment

    enum Segment: String, CaseIterable {
        case forYou = "FOR YOU"
        case gallery = "GALLERY"
    }

    // MARK: - Loading Phase

    enum LoadingPhase: Equatable {
        case idle
        case analyzing       // Camera roll classification in progress
        case matchingTemplates // TemplateMatchEngine running
        case ready
        case empty           // No content could be generated
        case error(String)
    }

    // MARK: - Published State

    @Published var selectedSegment: Segment = .forYou
    @Published private(set) var forYouItems: [ContentItem] = []
    @Published private(set) var galleryItems: [LibraryItem] = []
    /// Camera-roll-derived suggestions that populate the Gallery when the user
    /// hasn't yet approved enough content to fill the grid. These are NOT
    /// persisted through `ApprovedMediaLibraryStore` — they're an always-live
    /// view over the most recent camera-roll assets so the gallery never
    /// renders as placeholders on a fresh install or before the user has
    /// swiped through any For You cards.
    @Published private(set) var suggestedGalleryItems: [LibraryItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingGallery = false
    @Published private(set) var loadingPhase: LoadingPhase = .idle
    @Published var searchQuery: String = ""
    @Published var showSearch = false

    // MARK: - Dependencies

    private let approvedStore: ApprovedMediaLibraryStore
    private let matchEngine: TemplateMatchEngine
    private let templateRepo: VideoTemplateRepository
    private let embeddingIndex: EmbeddingIndex
    private let identityResolver: ForYouIdentityResolver
    private let assemblyCoordinator: ForYouAssemblyCoordinator
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Seen Items Tracker

    /// Tracks asset/template combos that have been shown to the user (approved or
    /// disapproved) so they never reappear. Persisted to UserDefaults.
    private static let seenItemsKey = "ForYouGalleryViewModel.seenItemIDs"

    private var seenItemIDs: Set<String> {
        didSet {
            let array = Array(seenItemIDs)
            UserDefaults.standard.set(array, forKey: Self.seenItemsKey)
        }
    }

    // MARK: - Content Cache

    /// Cached generated content so segment switching doesn't regenerate.
    private var cachedForYouItems: [ContentItem]?

    // MARK: - Pre-load buffer

    /// Number of upcoming cards to pre-generate beyond current view.
    /// Top-up fires whenever `forYouItems.count` drops at or below this value.
    /// Bumped from 3 → 5 so infinite scroll starts pulling well before the
    /// user reaches the bottom of the feed and never hits a visible stall.
    private static let prefetchCount: Int = 5

    /// Hard floor the feed tries to maintain after any top-up. Picked a little
    /// over `prefetchCount` so one swipe doesn't immediately trip another
    /// top-up; feels continuous rather than chatty.
    private static let targetBufferCount: Int = 10

    /// Initial camera-roll batch size pulled synchronously when the feed
    /// first loads. Needs to be > targetBufferCount so the first paint is
    /// saturated even before the background top-up cycle kicks in.
    private static let initialCameraRollBatch: Int = 12

    /// Incremental batch size pulled during background top-ups / infinite
    /// scroll. Keep this modest — each pull is very cheap (metadata only,
    /// no thumbnails loaded yet), but we don't want to pre-build cards
    /// the user may never reach.
    private static let topUpBatchSize: Int = 8

    /// Guard against concurrent top-ups (approve and disapprove can fire in
    /// quick succession; a background Task could also be in flight).
    private var isToppingUp: Bool = false

    /// Debounce handle for an opportunistic background refresh fired on a
    /// short timer after the feed settles.
    private var backgroundRefreshTask: Task<Void, Never>?

    /// Offset into the reverse-chronological camera-roll fetch. Advances
    /// monotonically as batches are pulled; reset on `refresh()` and wrapped
    /// to 0 when the roll is exhausted so the feed can recycle rather than
    /// go cold.
    private var recentCameraRollOffset: Int = 0

    // MARK: - Init

    init(
        approvedStore: ApprovedMediaLibraryStore = .shared,
        matchEngine: TemplateMatchEngine = TemplateMatchEngine(),
        templateRepo: VideoTemplateRepository = VideoTemplateRepositoryProvider.shared,
        embeddingIndex: EmbeddingIndex = .shared,
        identityResolver: ForYouIdentityResolver = ForYouIdentityResolver(),
        assemblyCoordinator: ForYouAssemblyCoordinator = ForYouAssemblyCoordinator()
    ) {
        self.approvedStore = approvedStore
        self.matchEngine = matchEngine
        self.templateRepo = templateRepo
        self.embeddingIndex = embeddingIndex
        self.identityResolver = identityResolver
        self.assemblyCoordinator = assemblyCoordinator

        // Restore seen items
        let saved = UserDefaults.standard.stringArray(forKey: Self.seenItemsKey) ?? []
        self.seenItemIDs = Set(saved)

        // Keep gallery in sync with approved store
        approvedStore.$approvedItems
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.galleryItems = items
            }
            .store(in: &cancellables)

        Task { await loadForYouContent() }
        Task { await loadGallerySuggestions() }
    }

    // MARK: - For You Actions

    func loadForYouContent() async {
        // Return cached content if available (e.g. after segment switch).
        // Still kick off a background top-up so the buffer catches any newly
        // classified assets that came in since the last segment visit.
        if let cached = cachedForYouItems, !cached.isEmpty {
            forYouItems = cached
            loadingPhase = .ready
            scheduleBackgroundTopUp()
            return
        }

        isLoading = true
        loadingPhase = .analyzing
        defer { isLoading = false }

        // Primary source: direct camera-roll assembly. Every card wraps a
        // real PHAsset so the swipe thumbnail is the user's actual content
        // and `approve` flows straight through `ContentPieceAssembler`.
        // Template-engine output and mockFeed are only used as backstops
        // when the roll is empty or the user hasn't granted access yet.
        recentCameraRollOffset = 0
        let cameraRoll = await generateFromRecentCameraRoll(
            offset: 0,
            limit: Self.initialCameraRollBatch
        )
        recentCameraRollOffset += cameraRoll.count

        let generated = cameraRoll.count < Self.targetBufferCount
            ? ((try? await generateFromTemplatePipeline()) ?? [])
            : []

        // Only fall back to mock seed when BOTH live sources came up empty —
        // e.g. the user denied camera-roll access or the app is running on
        // a freshly wiped device.
        let seed = (cameraRoll.isEmpty && generated.isEmpty)
            ? fallbackSeedItems()
            : []

        let initial = mergeCandidates(
            existing: [],
            adding: cameraRoll + generated + seed,
            cap: Self.targetBufferCount
        )

        forYouItems = initial
        cachedForYouItems = initial
        loadingPhase = initial.isEmpty ? .empty : .ready
        // Kick off a background top-up immediately so even if the initial
        // union is slim we keep pulling.
        scheduleBackgroundTopUp()
    }

    // MARK: - Continuous Top-Up

    /// Ensures the feed always has at least `targetBufferCount` unseen cards.
    /// Called after every approve/disapprove, from a background cadence, and
    /// from the SwipeView when the penultimate card appears (infinite scroll).
    /// The For You list should never dead-end — if the camera roll is
    /// exhausted, the offset wraps to 0 and recycles.
    ///
    /// Idempotent: overlapping calls short-circuit via `isToppingUp`.
    /// `internal` (no access modifier) so the SwipeView's `.onAppear` hook
    /// can trigger infinite scroll on the trailing card.
    func topUpIfNeeded() async {
        guard forYouItems.count <= Self.prefetchCount else { return }
        guard !isToppingUp else { return }
        isToppingUp = true
        defer { isToppingUp = false }

        // Pull the NEXT batch of camera-roll assets (moving offset forward).
        // This is the primary infinite-scroll engine — every subsequent
        // card the user sees is assembled from real media they own.
        let cameraRoll = await generateFromRecentCameraRoll(
            offset: recentCameraRollOffset,
            limit: Self.topUpBatchSize
        )
        recentCameraRollOffset += cameraRoll.count

        // Template pipeline runs as a secondary source — useful when the
        // roll has already been exhausted but we still have unused template
        // matches (e.g. the user classified new assets mid-session).
        let generated = (try? await generateFromTemplatePipeline()) ?? []

        let merged = mergeCandidates(
            existing: forYouItems,
            adding: cameraRoll + generated,
            cap: forYouItems.count + Self.topUpBatchSize
        )

        guard merged.count > forYouItems.count else {
            // Nothing new from this pass. Wrap the camera-roll offset and
            // retry once; if the roll is STILL empty, fall back to the
            // curated mock seed so the user never hits an empty feed.
            if recentCameraRollOffset > 0 {
                recentCameraRollOffset = 0
                let wrapped = await generateFromRecentCameraRoll(
                    offset: 0,
                    limit: Self.topUpBatchSize
                )
                recentCameraRollOffset = wrapped.count
                // Clear seen IDs for any asset-backed card so wrap
                // genuinely recycles rather than re-filtering itself out.
                let wrappedIDs = Set(wrapped.map(\.id.uuidString))
                seenItemIDs.subtract(wrappedIDs)
                let recycledMerged = mergeCandidates(
                    existing: forYouItems,
                    adding: wrapped,
                    cap: forYouItems.count + Self.topUpBatchSize
                )
                if recycledMerged.count > forYouItems.count {
                    forYouItems = recycledMerged
                    cachedForYouItems = recycledMerged
                    loadingPhase = .ready
                    return
                }
            }
            // Ultimate fallback: recycle the curated mock seed so an
            // empty-roll device still has content to swipe.
            if forYouItems.count == 0 {
                let seedIDs = Set(ContentItem.mockFeed.map(\.id.uuidString))
                seenItemIDs.subtract(seedIDs)
                let recycled = fallbackSeedItems()
                let recycledMerged = mergeCandidates(
                    existing: [],
                    adding: recycled,
                    cap: Self.targetBufferCount
                )
                forYouItems = recycledMerged
                cachedForYouItems = recycledMerged
                loadingPhase = recycledMerged.isEmpty ? .empty : .ready
            }
            return
        }

        forYouItems = merged
        cachedForYouItems = merged
        loadingPhase = merged.isEmpty ? .empty : .ready
    }

    /// Union two candidate lists with `existing`, dedupe by ID, and drop
    /// anything already in `seenItemIDs`. Preserves `existing` ordering and
    /// appends new items in input order. `cap` lets infinite scroll grow
    /// the list beyond the initial `targetBufferCount` paint.
    private func mergeCandidates(
        existing: [ContentItem],
        adding candidates: [ContentItem],
        cap: Int = Int.max
    ) -> [ContentItem] {
        var out = existing
        var seen = Set(existing.map(\.id))
        for candidate in candidates {
            if seen.contains(candidate.id) { continue }
            if seenItemIDs.contains(candidate.id.uuidString) { continue }
            seen.insert(candidate.id)
            out.append(candidate)
            if out.count >= cap { break }
        }
        return out
    }

    /// Fires a deferred top-up after a short delay so the feed can "breathe"
    /// between swipes. Replaces any pending background refresh.
    private func scheduleBackgroundTopUp() {
        backgroundRefreshTask?.cancel()
        backgroundRefreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)  // 0.4s
            guard !Task.isCancelled else { return }
            await self?.topUpIfNeeded()
        }
    }

    /// Seeded pieces surfaced when the live assembler hasn't produced output
    /// yet. Excludes items that were already swiped; if the user has
    /// exhausted the entire seed set, reset their seen-log for the seed IDs
    /// so the feed stays populated.
    ///
    /// The `mockFeed` ships with hardcoded creator handles like
    /// `@sarahcreates` — those get overwritten with the real resolved
    /// identity so the card always shows the user's actual social-profile
    /// handle next to the platform badge.
    private func fallbackSeedItems() -> [ContentItem] {
        let base = ContentItem.mockFeed.map { stamped(withIdentity: $0) }
        let unseen = base.filter { !seenItemIDs.contains($0.id.uuidString) }
        if unseen.isEmpty {
            let seedIDs = Set(base.map(\.id.uuidString))
            seenItemIDs.subtract(seedIDs)
            return base
        }
        return unseen
    }

    /// Rewrites a mock ContentItem's creator attribution with the current
    /// user's resolved identity for the piece's preferred platform.
    /// `creatorName`/`creatorHandle` are `let` on the model, so we rebuild
    /// the struct; all other fields are copied verbatim.
    private func stamped(withIdentity item: ContentItem) -> ContentItem {
        let identity = identityResolver.resolve(preferredPlatform: item.platform)
        var copy = ContentItem(
            id: item.id,
            type: item.type,
            creatorName: identity.displayName,
            creatorHandle: identity.handle,
            creatorAvatar: item.creatorAvatar,
            platform: item.platform,
            imageName: item.imageName,
            caption: item.caption,
            bodyText: item.bodyText,
            timestamp: item.timestamp,
            confidenceScore: item.confidenceScore,
            bestTime: item.bestTime,
            estimatedReach: item.estimatedReach,
            likes: item.likes,
            comments: item.comments,
            shares: item.shares
        )
        copy.assetLocalIdentifier = item.assetLocalIdentifier
        copy.assemblyPieceID = item.assemblyPieceID
        copy.assembledMediaURL = item.assembledMediaURL
        copy.isBookmarked = item.isBookmarked
        return copy
    }

    /// Force-refresh that clears the cache AND the seen-items log so the
    /// user sees a freshly ordered feed. Resets the camera-roll offset so
    /// pull-to-refresh always lands on the most recent shots first.
    func refresh() async {
        cachedForYouItems = nil
        recentCameraRollOffset = 0
        // Clear the seen log so a deliberate refresh surfaces cards the
        // user previously swiped past. The For You feed is explicitly
        // supposed to re-explore the roll on every pull-to-refresh.
        seenItemIDs.removeAll()
        forYouItems = []
        await loadForYouContent()
    }

    func approve(_ item: ContentItem) {
        seenItemIDs.insert(item.id.uuidString)
        Task {
            var approvedItem = item
            if let assetID = item.assetLocalIdentifier,
               let assembledPieceID = await assemblyCoordinator.assemble(assetLocalIdentifier: assetID) {
                approvedItem.assemblyPieceID = assembledPieceID
                approvedItem.assembledMediaURL = "envi-piece://\(assembledPieceID)"
            }
            approvedStore.approve(approvedItem)
        }
        TelemetryManager.shared.trackContent(
            .contentViewed,
            contentID: item.id.uuidString,
            platform: item.platform.apiSlug
        )
        removeFromForYou(item.id)
        updateCacheAfterRemoval(item.id)
        // Keep the feed topped up so it never bottoms out.
        Task { await topUpIfNeeded() }
    }

    func disapprove(_ itemID: UUID) {
        seenItemIDs.insert(itemID.uuidString)
        TelemetryManager.shared.track(.contentDeleted, parameters: ["content_id": itemID.uuidString])
        removeFromForYou(itemID)
        updateCacheAfterRemoval(itemID)
        // Keep the feed topped up so it never bottoms out.
        Task { await topUpIfNeeded() }
    }

    func bookmarkCard(id: UUID) {
        if let index = forYouItems.firstIndex(where: { $0.id == id }) {
            forYouItems[index].isBookmarked.toggle()
        }
    }

    // MARK: - Gallery

    /// Union of the user's actual approved items + camera-roll suggestions.
    /// Approved items take precedence (dedupe by `assetLocalIdentifier`) so
    /// a piece the user already swiped right on isn't double-listed.
    var displayedGalleryItems: [LibraryItem] {
        let approvedAssetIDs = Set(galleryItems.compactMap { $0.assetLocalIdentifier })
        let dedupedSuggestions = suggestedGalleryItems.filter { suggestion in
            guard let assetID = suggestion.assetLocalIdentifier else { return true }
            return !approvedAssetIDs.contains(assetID)
        }
        return galleryItems + dedupedSuggestions
    }

    var filteredGalleryItems: [LibraryItem] {
        let base = displayedGalleryItems
        guard !searchQuery.isEmpty else { return base }
        let query = searchQuery.lowercased()
        return base.filter { $0.title.lowercased().contains(query) }
    }

    /// Up to 3 items surfaced in the SAVED TEMPLATES rail at the top of the
    /// gallery. Prefers the user's own approved content, then falls back to
    /// the live camera-roll suggestions so the rail is never empty when the
    /// user has media on device.
    var savedTemplatePreviewItems: [LibraryItem] {
        let approvedSlice = Array(galleryItems.prefix(3))
        let remaining = max(0, 3 - approvedSlice.count)
        let approvedAssetIDs = Set(galleryItems.compactMap { $0.assetLocalIdentifier })
        let suggestionSlice = suggestedGalleryItems
            .filter { suggestion in
                guard let assetID = suggestion.assetLocalIdentifier else { return true }
                return !approvedAssetIDs.contains(assetID)
            }
            .prefix(remaining)
        return approvedSlice + Array(suggestionSlice)
    }

    /// Pulls the most recent camera-roll assets (photos + videos) and wraps
    /// them as `LibraryItem`s so the Gallery grid + SAVED TEMPLATES rail
    /// always have real, tangible content to render. Short-circuits when
    /// photo-library access isn't granted yet — the onboarding step owns
    /// the prompt; we just render whatever we can reach.
    func loadGallerySuggestions() async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            suggestedGalleryItems = []
            return
        }

        isLoadingGallery = true
        defer { isLoadingGallery = false }

        // Pull a generous slice — masonry looks thin below ~8 items and we
        // don't want scroll to bottom on a device with thousands of photos.
        let targetCount = 24

        let options = PHFetchOptions()
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]
        options.predicate = NSPredicate(
            format: "mediaType == %d OR mediaType == %d",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaType.video.rawValue
        )
        options.fetchLimit = targetCount

        let fetch = PHAsset.fetchAssets(with: options)
        guard fetch.count > 0 else {
            suggestedGalleryItems = []
            return
        }

        var collected: [LibraryItem] = []
        collected.reserveCapacity(fetch.count)

        // Varied heights so the masonry doesn't render as a perfect grid.
        // Picked to feel organic; cycle across 4 heights weighted to taller
        // tiles (Sketch mocks skew portrait-heavy).
        let heightCycle: [CGFloat] = [240, 310, 210, 280, 260, 340, 220, 290]

        for index in 0..<fetch.count {
            let asset = fetch.object(at: index)
            let type: LibraryItem.ItemType = asset.mediaType == .video ? .videos : .photos
            let title: String = {
                if let created = asset.creationDate {
                    return Self.galleryTitleFormatter.string(from: created)
                }
                return type == .videos ? "Clip" : "Photo"
            }()
            let height = heightCycle[index % heightCycle.count]

            // Deterministic ID so re-suggesting the same asset across launches
            // doesn't duplicate tiles and doesn't collide with approved items.
            let stableID = "suggestion-" + asset.localIdentifier
            let fallbackImage = type == .videos ? "fire-stunt" : "studio-fashion"

            collected.append(
                LibraryItem(
                    id: stableID,
                    title: title,
                    imageName: fallbackImage,
                    assetLocalIdentifier: asset.localIdentifier,
                    assemblyPieceID: nil,
                    assembledMediaURL: nil,
                    type: type,
                    height: height
                )
            )
        }

        suggestedGalleryItems = collected
    }

    /// Force-refresh the Gallery suggestions — bound to pull-to-refresh on
    /// the grid so the user can pull newly-captured shots in without
    /// restarting the app.
    func refreshGallery() async {
        suggestedGalleryItems = []
        await loadGallerySuggestions()
    }

    /// Compact date formatter for auto-generated gallery tile titles.
    /// Produces strings like "APR 17" / "MAR 3".
    private static let galleryTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    // MARK: - Camera Roll Pipeline (primary)

    /// Pulls the N most-recent camera-roll assets directly (photos + videos)
    /// starting at `offset`, wraps each in a ContentItem whose
    /// `assetLocalIdentifier` is set so the swipe card renders the actual
    /// thumbnail and the approve path hands the asset to
    /// `ContentPieceAssembler`. Bypasses the template engine so the feed
    /// continues to produce cards even on lean or freshly-imported rolls.
    ///
    /// Platform is rotated across instagram / tiktok / threads / youtube / x
    /// so the feed mixes visual-first and text-first surfaces. Threads and X
    /// still get an image attached — the caption + body preview render on
    /// top of the media, which is what the swipe UI already expects for
    /// text-first surfaces.
    private func generateFromRecentCameraRoll(
        offset: Int,
        limit: Int
    ) async -> [ContentItem] {
        // Photo-library auth is a hard prerequisite. Without it,
        // `PHAsset.fetchAssets` returns an empty result set. We don't
        // request here — that's owned by the camera-roll onboarding step —
        // we just short-circuit so callers can union mock seed instead.
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            return []
        }

        let options = PHFetchOptions()
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]
        options.predicate = NSPredicate(
            format: "mediaType == %d OR mediaType == %d",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaType.video.rawValue
        )
        // fetchLimit applies to the whole fetch, not just what we slice.
        // Over-fetch by `offset + limit` so the slice actually exists.
        options.fetchLimit = offset + limit
        let fetch = PHAsset.fetchAssets(with: options)

        guard fetch.count > offset else { return [] }

        var assets: [PHAsset] = []
        let end = min(offset + limit, fetch.count)
        for i in offset..<end {
            assets.append(fetch.object(at: i))
        }

        // Platform rotation: mix visual + text-first surfaces. Threads / X
        // without a photo would still show a text card (task #39 will wire
        // up cloud text-gen), but for now they piggyback on an image from
        // the roll so the feed always has a tangible preview.
        let rotation: [SocialPlatform] = [
            .instagram, .tiktok, .threads, .youtube, .x, .instagram
        ]

        return assets.enumerated().map { (idx, asset) -> ContentItem in
            let platform = rotation[idx % rotation.count]
            let identity = identityResolver.resolve(preferredPlatform: platform)

            // Visual surfaces use the asset's native media type. Text-first
            // surfaces are always `.textPost` so the swipe card renders the
            // caption preview overlay on top of the hero image.
            let contentType: ContentItem.ContentType
            switch platform {
            case .threads, .x:
                contentType = .textPost
            default:
                contentType = asset.mediaType == .video ? .video : .photo
            }

            let caption: String
            let bodyText: String?
            switch platform {
            case .instagram:
                caption = "Frame from this week"
                bodyText = nil
            case .tiktok:
                caption = "Raw edit — straight from the roll"
                bodyText = nil
            case .youtube:
                caption = "Full walkthrough in the next upload"
                bodyText = nil
            case .threads:
                caption = "Capturing the quiet moments between the big ones."
                bodyText = "Thread: the story behind this — what I was shooting for, what didn't work, what I'd frame differently next time."
            case .x:
                caption = "Screenshots from the week ↓"
                bodyText = "Drop your favorite — reply with the one you'd print."
            case .facebook, .linkedin:
                caption = "From the library"
                bodyText = nil
            }

            // Deterministic ID from asset.localIdentifier + platform so the
            // same asset+platform combo always yields the same card. Keeps
            // the seenItemIDs dedupe stable across top-ups.
            let stableID = Self.deterministicUUID(
                for: asset.localIdentifier + "|" + platform.rawValue
            )

            var item = ContentItem(
                id: stableID,
                type: contentType,
                creatorName: identity.displayName,
                creatorHandle: identity.handle,
                creatorAvatar: nil,
                platform: platform,
                imageName: nil,
                caption: caption,
                bodyText: bodyText,
                timestamp: asset.creationDate ?? Date(),
                confidenceScore: Self.heuristicConfidence(for: asset),
                bestTime: Self.preferredTime(for: platform),
                estimatedReach: "Based on your audience",
                likes: 0,
                comments: 0,
                shares: 0
            )
            item.assetLocalIdentifier = asset.localIdentifier
            return item
        }
    }

    /// Deterministic UUID from a seed string. Same seed always → same UUID.
    /// Uses two independent FNV-1a 64-bit hashes (forward + reverse) packed
    /// into the UUID's 128 bits — good enough for an identity token; we
    /// don't need cryptographic uniqueness here.
    private static func deterministicUUID(for seed: String) -> UUID {
        let bytes = Array(seed.utf8)
        let low = fnv1a64(bytes, salt: 0xcbf29ce484222325)
        let high = fnv1a64(bytes.reversed(), salt: 0x84222325cbf29ce4)
        var out = [UInt8](repeating: 0, count: 16)
        for i in 0..<8 { out[i] = UInt8(truncatingIfNeeded: low >> (i * 8)) }
        for i in 0..<8 { out[i + 8] = UInt8(truncatingIfNeeded: high >> (i * 8)) }
        return UUID(uuid: (
            out[0], out[1], out[2], out[3],
            out[4], out[5], out[6], out[7],
            out[8], out[9], out[10], out[11],
            out[12], out[13], out[14], out[15]
        ))
    }

    private static func fnv1a64<S: Sequence>(_ bytes: S, salt: UInt64) -> UInt64 where S.Element == UInt8 {
        let prime: UInt64 = 0x100000001b3
        var state = salt
        for byte in bytes {
            state ^= UInt64(byte)
            state = state &* prime
        }
        return state
    }

    /// Heuristic confidence score for a camera-roll asset in the absence of
    /// a template match. Favors newer, higher-resolution assets slightly so
    /// the visible AI-score pills feel like they track something real.
    private static func heuristicConfidence(for asset: PHAsset) -> Double {
        let megapixels = (Double(asset.pixelWidth) * Double(asset.pixelHeight)) / 1_000_000.0
        let resolutionScore = min(1.0, megapixels / 12.0) * 0.15
        let recencyScore: Double = {
            guard let created = asset.creationDate else { return 0.05 }
            let daysAgo = -created.timeIntervalSinceNow / 86_400.0
            if daysAgo < 7 { return 0.18 }
            if daysAgo < 30 { return 0.12 }
            if daysAgo < 180 { return 0.08 }
            return 0.04
        }()
        let base = 0.70
        return min(0.98, base + resolutionScore + recencyScore)
    }

    /// Rough per-platform "best time" copy so the score pill always reads
    /// plausibly. Actual optimization is task #39+ — this just avoids the
    /// placeholder feeling.
    private static func preferredTime(for platform: SocialPlatform) -> String {
        switch platform {
        case .instagram: return "6:00 PM"
        case .tiktok:    return "8:00 PM"
        case .youtube:   return "3:00 PM"
        case .threads:   return "11:00 AM"
        case .x:         return "9:00 AM"
        case .facebook:  return "12:00 PM"
        case .linkedin:  return "10:00 AM"
        }
    }

    // MARK: - Template Pipeline

    /// Generates ContentItem cards from the real camera roll via
    /// ClassificationCache + TemplateMatchEngine + EmbeddingIndex.
    ///
    /// NOTE: intentionally does NOT mutate `loadingPhase` — callers decide
    /// whether a pipeline run should surface UI state (initial load) or
    /// stay silent (background top-up during an active swipe session).
    private func generateFromTemplatePipeline() async throws -> [ContentItem] {
        // 1. Get the classification cache from the shared MediaClassifier
        let classifier = MediaClassifier.shared
        let cache = classifier.cache

        // 2. Check if we have any classified assets
        let allAssets = try await cache.fetchAll()
        guard !allAssets.isEmpty else {
            return []
        }

        // 3. Fetch template catalog
        let templates = try await templateRepo.fetchCatalog()
        guard !templates.isEmpty else { return [] }

        // 4. Run match engine against each template
        let populated = await matchEngine.populateAll(
            templates: templates,
            from: cache,
            using: embeddingIndex
        )

        // 5. Convert PopulatedTemplates to ContentItems, filtering out seen
        let items = populated
            .filter { pop in
                pop.fillRate > 0 &&
                pop.filledSlots.contains(where: { $0.matchedAsset != nil })
            }
            .sorted { $0.overallScore > $1.overallScore }
            .enumerated()
            .compactMap { (_, pop) -> ContentItem? in
                let stableID = contentItemID(for: pop)
                guard !seenItemIDs.contains(stableID.uuidString) else { return nil }
                return contentItem(from: pop, stableID: stableID)
            }

        TelemetryManager.shared.track(.contentImportCompleted, parameters: [
            "tab": "for_you",
            "generated_count": items.count,
            "placeholder_bundle_image_count": items.filter { $0.imageName != nil }.count,
            "non_user_handle_count": items.filter { $0.creatorHandle == "@envi" }.count
        ])

        return items
    }

    /// Creates a deterministic UUID for a PopulatedTemplate so the same
    /// template + asset combination always yields the same card ID.
    private func contentItemID(for populated: PopulatedTemplate) -> UUID {
        let seed = populated.template.id.uuidString
            + (populated.filledSlots.first?.matchedAsset?.localIdentifier ?? "empty")
        // Deterministic UUID from a hash
        let hash = seed.utf8.reduce(into: Data()) { $0.append($1) }
        return UUID(uuidString:
            UUID(uuid: hash.withUnsafeBytes { ptr in
                var uuid = uuid_t(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
                let count = min(MemoryLayout<uuid_t>.size, ptr.count)
                withUnsafeMutableBytes(of: &uuid) { dest in
                    dest.copyBytes(from: UnsafeRawBufferPointer(rebasing: ptr.prefix(count)))
                }
                return uuid
            }).uuidString
        ) ?? UUID()
    }

    /// Maps a PopulatedTemplate to a ContentItem for the swipe UI.
    private func contentItem(
        from populated: PopulatedTemplate,
        stableID: UUID
    ) -> ContentItem {
        let template = populated.template

        let platform = template.suggestedPlatforms.first ?? .instagram
        let caption = "\(template.name) · \(template.category.displayName)"
        let previewAssetID = populated.filledSlots.first(where: { $0.matchedAsset != nil })?.matchedAsset?.localIdentifier
        let identity = identityResolver.resolve(preferredPlatform: platform)
        let qualitySummary = "Match score \(Int(populated.overallScore * 100))%"

        var item = ContentItem(
            id: stableID,
            type: template.aspectRatio == .portrait9x16 ? .video : .photo,
            creatorName: identity.displayName,
            creatorHandle: identity.handle,
            creatorAvatar: nil,
            platform: platform,
            imageName: nil,
            caption: caption,
            bodyText: qualitySummary,
            timestamp: Date(),
            confidenceScore: populated.overallScore,
            bestTime: "Your peak window",
            estimatedReach: "Based on your audience",
            likes: 0,
            comments: 0,
            shares: 0
        )
        item.assetLocalIdentifier = previewAssetID
        return item
    }

    // MARK: - Helpers

    private func removeFromForYou(_ id: UUID) {
        forYouItems.removeAll { $0.id == id }
        // Don't flip to `.empty` on the last swipe — topUpIfNeeded() fires
        // right after and will re-populate the feed (union of live pipeline
        // + seed, with seed-seen IDs recycled if both are exhausted). The
        // top-up sets its own phase; flashing `.empty` between frames would
        // swap the cards out for the empty-state copy.
    }

    private func updateCacheAfterRemoval(_ id: UUID) {
        cachedForYouItems?.removeAll { $0.id == id }
    }
}
