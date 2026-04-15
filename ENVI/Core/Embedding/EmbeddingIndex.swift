//
//  EmbeddingIndex.swift
//  ENVI
//
//  Phase 2, Task 4 — public facade over the Phase 2 embedding pipeline.
//
//  Orchestrates Tasks 1-3:
//    - SimilarityEngine   (Task 1) → cosine k-NN on feature prints
//    - DimensionReducer   (Task 2) → UMAP 2D projection
//    - DensityClusterer   (Task 3) → HDBSCAN cluster labels
//
//  and exposes a single actor-isolated API for Phase 3 (template matching):
//
//    - rebuild(from:)          : full re-index from ClassificationCache
//    - findSimilar(to:k:)      : cosine top-K by assetID
//    - clusters()              : asset ID → cluster label (-1 = noise)
//    - projection2D()          : asset ID → 2D coord
//    - similarityMatrix(for:)  : NxN cosine for a slice of assets
//    - saveCheckpoint()        : persist to Application Support
//    - loadCheckpoint() -> Bool: fast-path on app launch
//    - isStale(for:)           : content-hash invalidation check
//
//  Bounded memory: the index is capped at the most-recent 5 000 assets by
//  `creationDate` (then `classifiedAt` as a fallback) on every rebuild.
//
//  Checkpoint format: JSON (Codable) written to
//     <App Support>/EmbeddingIndex.cache
//  with a schema-version integer so old caches are rejected cleanly.
//  JSON was chosen over plist so the file is human-diffable on device
//  and so we stay on Foundation's zero-dep path (no PropertyListEncoder
//  oddities with mixed Float arrays).
//
//  All public methods are `async` — the single-actor isolation serializes
//  rebuilds and checkpoint reads automatically.
//

import Foundation
import CryptoKit

// MARK: - Checkpoint schema

/// Current on-disk schema version for the EmbeddingIndex checkpoint file.
/// Bump when any of the `EmbeddingIndexCheckpoint` shapes change.
fileprivate let kEmbeddingIndexSchemaVersion: Int = 1

/// Disk-serialisable snapshot mirror (EmbeddingIndexSnapshot is Sendable
/// but not Codable; we keep the Codable shadow here so we don't force
/// changes on Task 1's public type).
fileprivate struct CodableSnapshot: Codable {
    let assetIDs: [String]
    let vectors: [[Float]]
    let dimension: Int
}

/// A single encodable 2D coordinate. Tuples are not Codable so we shadow
/// `(Float, Float)` with a tiny struct here.
fileprivate struct CodablePoint2D: Codable {
    let x: Float
    let y: Float
}

/// Full checkpoint payload written to disk.
fileprivate struct EmbeddingIndexCheckpoint: Codable {
    let schemaVersion: Int
    let snapshot: CodableSnapshot
    let clusterLabels: [String: Int]
    let projection: [String: CodablePoint2D]
    let contentHash: String
}

// MARK: - EmbeddingIndex

/// Top-level actor exposing the embedding pipeline to Phase 3 consumers.
///
/// Thread-safety: all state is actor-isolated. Callers await public
/// methods; concurrent rebuild attempts serialize naturally.
public actor EmbeddingIndex {

    // MARK: Singleton

    /// Process-wide shared index. Safe to construct — no I/O happens until
    /// `rebuild` or `loadCheckpoint` is called.
    public static let shared = EmbeddingIndex()

    // MARK: Dependencies

    private let similarityEngine: SimilarityEngine
    private let dimensionReducer: DimensionReducer
    private let densityClusterer: DensityClusterer

    // MARK: State

    private var snapshot: EmbeddingIndexSnapshot?
    private var clusterLabels: [String: Int]?
    private var projection: [String: (Float, Float)]?
    private var contentHash: String?

    // MARK: Config

    /// Maximum assets considered per rebuild (plan: cap at 5 000 most recent).
    public static let maxAssets: Int = 5_000

    /// Checkpoint location override (tests).
    private let checkpointURLOverride: URL?

    // MARK: Init

    /// Designated init. Prefer `shared` in production; use this directly
    /// in tests to get an isolated in-process instance or a custom
    /// checkpoint URL.
    public init(
        similarityEngine: SimilarityEngine = SimilarityEngine(),
        dimensionReducer: DimensionReducer = DimensionReducer(nComponents: 2),
        densityClusterer: DensityClusterer = DensityClusterer(),
        checkpointURL: URL? = nil
    ) {
        self.similarityEngine = similarityEngine
        self.dimensionReducer = dimensionReducer
        self.densityClusterer = densityClusterer
        self.checkpointURLOverride = checkpointURL
    }

    // MARK: - Public API

    /// Full re-index from a `ClassificationCache`. Fetches every asset with
    /// a feature-print, caps to the 5 000 most recent by `creationDate`,
    /// runs Tasks 1-3, and persists a checkpoint.
    public func rebuild(from cache: ClassificationCache) async {
        // 1. Load + filter + cap.
        let all: [ClassifiedAsset]
        do {
            all = try await cache.fetchAll()
        } catch {
            return
        }
        let bounded = Self.boundAssets(all, max: Self.maxAssets)

        // 2. Build similarity snapshot (parallel rows of L2-normalized vectors).
        let snap = await similarityEngine.buildIndex(for: bounded)
        self.snapshot = snap

        // 3. Derive clusters + 2D projection from the snapshot's vectors.
        if !snap.vectors.isEmpty {
            let labels = await densityClusterer.cluster(snap.vectors)
            var labelMap: [String: Int] = [:]
            labelMap.reserveCapacity(snap.assetIDs.count)
            for (i, id) in snap.assetIDs.enumerated() {
                labelMap[id] = i < labels.count ? labels[i] : -1
            }
            self.clusterLabels = labelMap

            let coords = await dimensionReducer.reduce(snap.vectors)
            var projMap: [String: (Float, Float)] = [:]
            projMap.reserveCapacity(snap.assetIDs.count)
            for (i, id) in snap.assetIDs.enumerated() {
                if i < coords.count, coords[i].count >= 2 {
                    projMap[id] = (coords[i][0], coords[i][1])
                } else {
                    projMap[id] = (0, 0)
                }
            }
            self.projection = projMap
        } else {
            self.clusterLabels = [:]
            self.projection = [:]
        }

        // 4. Content hash (for invalidation) + persist.
        self.contentHash = Self.hash(for: bounded)
        await saveCheckpoint()
    }

    /// Cosine top-K similar asset IDs for a given seed `assetID`.
    /// Returns empty if the seed is not in the current snapshot.
    public func findSimilar(to assetID: String, k: Int) async -> [String] {
        guard k > 0, let snap = snapshot else { return [] }
        guard let seedIdx = snap.assetIDs.firstIndex(of: assetID) else { return [] }
        let query = snap.vectors[seedIdx]

        // Single matmul against pre-normalized snapshot.
        let sims = await similarityEngine.batchSimilarity(query: query, snapshot: snap)
        guard !sims.isEmpty else { return [] }

        // Score every row, drop the seed itself, sort descending, take k.
        var scored: [(String, Float)] = []
        scored.reserveCapacity(sims.count)
        for i in 0..<sims.count where i != seedIdx {
            scored.append((snap.assetIDs[i], sims[i]))
        }
        scored.sort { $0.1 > $1.1 }
        if scored.count > k { scored.removeLast(scored.count - k) }
        return scored.map { $0.0 }
    }

    /// Asset ID → HDBSCAN cluster label. `-1` indicates noise.
    public func clusters() async -> [String: Int] {
        clusterLabels ?? [:]
    }

    /// Asset ID → UMAP 2D projection.
    public func projection2D() async -> [String: (Float, Float)] {
        projection ?? [:]
    }

    /// Pairwise cosine similarity sub-matrix for an arbitrary slice of
    /// asset IDs. Missing IDs get a zero row/column. The resulting matrix
    /// is symmetric with 1.0 on the diagonal (for present IDs).
    public func similarityMatrix(for assetIDs: [String]) async -> [[Float]] {
        let n = assetIDs.count
        guard n > 0, let snap = snapshot else {
            return Array(repeating: Array(repeating: 0, count: n), count: n)
        }

        // Lookup once.
        var indices: [Int?] = []
        indices.reserveCapacity(n)
        let idToRow: [String: Int] = Dictionary(uniqueKeysWithValues:
            snap.assetIDs.enumerated().map { ($1, $0) }
        )
        for id in assetIDs { indices.append(idToRow[id]) }

        var out = Array(repeating: Array(repeating: Float(0), count: n), count: n)
        let d = snap.dimension
        for i in 0..<n {
            guard let ri = indices[i] else { continue }
            let vi = snap.vectors[ri]
            out[i][i] = 1
            for j in (i + 1)..<n {
                guard let rj = indices[j] else { continue }
                let vj = snap.vectors[rj]
                var dot: Float = 0
                for c in 0..<d { dot += vi[c] * vj[c] }
                out[i][j] = dot
                out[j][i] = dot
            }
        }
        return out
    }

    /// Persist the current state to `EmbeddingIndex.cache`. No-op if the
    /// state is empty (nothing to save yet).
    public func saveCheckpoint() async {
        guard let snap = snapshot,
              let labels = clusterLabels,
              let proj = projection,
              let hash = contentHash else { return }

        let codableProj = proj.mapValues { CodablePoint2D(x: $0.0, y: $0.1) }
        let payload = EmbeddingIndexCheckpoint(
            schemaVersion: kEmbeddingIndexSchemaVersion,
            snapshot: CodableSnapshot(
                assetIDs: snap.assetIDs,
                vectors: snap.vectors,
                dimension: snap.dimension
            ),
            clusterLabels: labels,
            projection: codableProj,
            contentHash: hash
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(payload)
            let url = try Self.checkpointURL(override: checkpointURLOverride)
            try data.write(to: url, options: [.atomic])
        } catch {
            // Checkpointing is a best-effort optimization; never fatal.
            return
        }
    }

    /// Attempt to rehydrate state from the on-disk checkpoint. Returns
    /// `true` on a valid load; `false` if the file is missing, corrupt,
    /// or written under a different schema version (caller should
    /// `rebuild` in that case).
    @discardableResult
    public func loadCheckpoint() async -> Bool {
        do {
            let url = try Self.checkpointURL(override: checkpointURLOverride)
            guard FileManager.default.fileExists(atPath: url.path) else { return false }
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let payload = try decoder.decode(EmbeddingIndexCheckpoint.self, from: data)
            guard payload.schemaVersion == kEmbeddingIndexSchemaVersion else {
                return false
            }

            self.snapshot = EmbeddingIndexSnapshot(
                assetIDs: payload.snapshot.assetIDs,
                vectors: payload.snapshot.vectors,
                dimension: payload.snapshot.dimension
            )
            self.clusterLabels = payload.clusterLabels
            self.projection = payload.projection.mapValues { ($0.x, $0.y) }
            self.contentHash = payload.contentHash
            return true
        } catch {
            return false
        }
    }

    /// Returns `true` if the saved checkpoint's content hash does not
    /// match the live cache (assets added/removed/reclassified). Callers
    /// decide whether to schedule a rebuild.
    public func isStale(for cache: ClassificationCache) async -> Bool {
        guard let saved = contentHash else { return true }
        let all: [ClassifiedAsset]
        do {
            all = try await cache.fetchAll()
        } catch {
            return true
        }
        let bounded = Self.boundAssets(all, max: Self.maxAssets)
        return Self.hash(for: bounded) != saved
    }

    // MARK: - Internal helpers

    /// Cap `assets` to the most-recent `max` entries (prefers `creationDate`,
    /// falls back to `classifiedAt` when creationDate is nil). Drops assets
    /// without a feature print.
    static func boundAssets(_ assets: [ClassifiedAsset], max: Int) -> [ClassifiedAsset] {
        let withPrint = assets.filter { $0.featurePrint != nil }
        guard withPrint.count > max else {
            // Still deterministic-order this for hashing stability.
            return withPrint.sorted { lhs, rhs in
                let l = lhs.creationDate ?? lhs.classifiedAt
                let r = rhs.creationDate ?? rhs.classifiedAt
                return l > r
            }
        }
        let sorted = withPrint.sorted { lhs, rhs in
            let l = lhs.creationDate ?? lhs.classifiedAt
            let r = rhs.creationDate ?? rhs.classifiedAt
            return l > r
        }
        return Array(sorted.prefix(max))
    }

    /// Deterministic content hash: SHA-256 over (localIdentifier | classifiedAt)
    /// pairs, sorted by localIdentifier so input order cannot perturb the hash.
    static func hash(for assets: [ClassifiedAsset]) -> String {
        var pairs: [(String, Double)] = assets.map {
            ($0.localIdentifier, $0.classifiedAt.timeIntervalSinceReferenceDate)
        }
        pairs.sort { $0.0 < $1.0 }

        var hasher = SHA256()
        for (id, ts) in pairs {
            hasher.update(data: Data(id.utf8))
            hasher.update(data: Data("|".utf8))
            var tsLE = ts.bitPattern.littleEndian
            withUnsafeBytes(of: &tsLE) { hasher.update(data: Data($0)) }
            hasher.update(data: Data("\n".utf8))
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Resolve checkpoint URL, creating the Application Support directory
    /// on demand.
    static func checkpointURL(override: URL?) throws -> URL {
        if let override { return override }
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return appSupport.appendingPathComponent("EmbeddingIndex.cache")
    }
}
