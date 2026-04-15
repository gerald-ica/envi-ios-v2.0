//
//  SimilarityEngine.swift
//  ENVI
//
//  Actor-based cosine similarity engine over VNFeaturePrintObservation
//  Data blobs stored on `ClassifiedAsset.featurePrint`. Provides pairwise
//  similarity, brute-force top-K search, and a pre-normalized snapshot
//  index for fast batch cosine via Accelerate's `vDSP_mmul`.
//
//  Part of Phase 2 — Embedding Pipeline (Template Tab v1), Task 1.
//
//  Similarity convention:
//    VNFeaturePrintObservation.computeDistance(to:) returns a non-negative
//    distance (lower = more similar). We convert with `1 - distance` so
//    downstream code can sort descending and treat higher = more similar.
//    The raw distance from Vision is already bounded into [0, 1] for
//    matching feature-print versions, so this keeps similarity in the same
//    bounded range.
//
//  Actor isolation:
//    The engine is an actor — decoding VNFeaturePrintObservation is not
//    cheap, so concurrent callers queue through a single isolation domain.
//    This also lets us cache decoded observations safely if we choose to
//    later (not needed for the API surface below).
//
//  Dependencies:
//    - Vision (VNFeaturePrintObservation)
//    - Accelerate (vDSP_normalize, vDSP_mmul, vDSP_dotpr)
//    - No new SPM deps — all Apple-native.
//

import Foundation
import Vision
import Accelerate

// MARK: - Snapshot

/// Pre-normalized embedding matrix for fast batch cosine similarity.
///
/// Each row of `vectors` is an L2-normalized `Float` array of length
/// `dimension`. Since rows are unit vectors, the cosine similarity between
/// any two rows collapses to a single dot product, and whole-matrix
/// similarity becomes a single `vDSP_mmul` call (see
/// `SimilarityEngine.batchSimilarity(query:snapshot:)`).
///
/// The `assetIDs` array is parallel to the rows of `vectors`: row `i`
/// corresponds to `assetIDs[i]`.
public struct EmbeddingIndexSnapshot: Sendable {
    /// PHAsset local identifiers, parallel to `vectors`.
    public let assetIDs: [String]
    /// L2-normalized feature vectors. Each inner array has `dimension`
    /// elements.
    public let vectors: [[Float]]
    /// Dimensionality of each feature vector (typically 2048 for Apple's
    /// current VNFeaturePrintObservation).
    public let dimension: Int

    public init(assetIDs: [String], vectors: [[Float]], dimension: Int) {
        self.assetIDs = assetIDs
        self.vectors = vectors
        self.dimension = dimension
    }
}

// MARK: - Engine

/// Actor wrapping VNFeaturePrintObservation operations + custom top-K.
///
/// All methods are `async` to respect actor isolation. Safe to call from
/// any task; callers serialize through the actor automatically.
public actor SimilarityEngine {

    // MARK: Init

    public init() {}

    // MARK: Pairwise

    /// Cosine-style similarity between two serialized feature-print blobs.
    ///
    /// Returns `1 - distance` where `distance` is computed by
    /// `VNFeaturePrintObservation.computeDistance(to:)`. Returns `0` if
    /// either blob fails to decode — callers that need to distinguish
    /// failure from "dissimilar" should decode via
    /// `decodeFeaturePrint(_:)` themselves.
    public func similarity(between a: Data, and b: Data) -> Float {
        guard let obsA = Self.decodeFeaturePrint(a),
              let obsB = Self.decodeFeaturePrint(b) else {
            return 0
        }
        var distance: Float = 0
        do {
            try obsA.computeDistance(&distance, to: obsB)
        } catch {
            return 0
        }
        return 1 - distance
    }

    // MARK: Top-K

    /// Brute-force top-K cosine search over `candidates`.
    ///
    /// - Parameters:
    ///   - queryFeature: Serialized VNFeaturePrintObservation Data.
    ///   - candidates: ClassifiedAssets to score. Entries whose
    ///     `featurePrint` is nil or fails to decode are skipped.
    ///   - k: Maximum number of results to return.
    /// - Returns: Up to `k` `(asset, similarity)` pairs, sorted
    ///   descending by similarity.
    ///
    /// Performance: decodes the query once, then decodes each candidate
    /// and calls `computeDistance(to:)`. Brute force is fine for the
    /// Phase 2 target (<5000 assets). For tighter inner loops, build an
    /// `EmbeddingIndexSnapshot` and use `batchSimilarity(...)`.
    public func topK(
        queryFeature: Data,
        candidates: [ClassifiedAsset],
        k: Int
    ) -> [(ClassifiedAsset, Float)] {
        guard k > 0, !candidates.isEmpty else { return [] }
        guard let query = Self.decodeFeaturePrint(queryFeature) else {
            return []
        }

        var scored: [(ClassifiedAsset, Float)] = []
        scored.reserveCapacity(candidates.count)

        for asset in candidates {
            guard let blob = asset.featurePrint,
                  let obs = Self.decodeFeaturePrint(blob) else {
                continue
            }
            var distance: Float = 0
            do {
                try query.computeDistance(&distance, to: obs)
            } catch {
                continue
            }
            scored.append((asset, 1 - distance))
        }

        scored.sort { $0.1 > $1.1 }
        if scored.count > k {
            scored.removeLast(scored.count - k)
        }
        return scored
    }

    /// Convenience: find `k` visually-similar assets to a given assetID
    /// stored in the provided `ClassificationCache`.
    ///
    /// Fetches the seed asset, reads all candidates from the cache, runs
    /// `topK`, filters the seed itself out of the results, and returns
    /// the top-K `ClassifiedAsset`s (dropping similarity scores).
    ///
    /// Returns an empty array on any fetch or decode failure.
    public func findSimilar(
        to assetID: String,
        in cache: ClassificationCache,
        k: Int
    ) async -> [ClassifiedAsset] {
        guard k > 0 else { return [] }

        let seed: ClassifiedAsset?
        do {
            seed = try await cache.fetch(localIdentifier: assetID)
        } catch {
            return []
        }
        guard let seed, let query = seed.featurePrint else { return [] }

        let all: [ClassifiedAsset]
        do {
            all = try await cache.fetchAll()
        } catch {
            return []
        }

        // Exclude the seed itself; request one extra in case it sneaks in.
        let candidates = all.filter { $0.localIdentifier != assetID }
        let scored = topK(queryFeature: query, candidates: candidates, k: k)
        return scored.map { $0.0 }
    }

    // MARK: Index / Batch

    /// Builds a pre-normalized snapshot suitable for `vDSP_mmul` batch
    /// similarity. Assets with no decoded feature-print are skipped.
    ///
    /// Every row of the resulting snapshot is L2-normalized via
    /// `vDSP_normalize`, so cosine similarity between any two rows is a
    /// single dot product (`vDSP_dotpr`) or, for a whole query-against-
    /// all-candidates pass, a single matrix multiply (`vDSP_mmul`).
    ///
    /// If input feature-prints disagree on dimension (shouldn't happen
    /// in production but could during a schema migration), vectors whose
    /// dimension doesn't match the first decoded vector are dropped.
    public func buildIndex(for assets: [ClassifiedAsset]) -> EmbeddingIndexSnapshot {
        var ids: [String] = []
        var rows: [[Float]] = []
        var dim: Int = 0

        ids.reserveCapacity(assets.count)
        rows.reserveCapacity(assets.count)

        for asset in assets {
            guard let blob = asset.featurePrint,
                  let obs = Self.decodeFeaturePrint(blob),
                  let vector = Self.extractVector(from: obs) else {
                continue
            }
            if dim == 0 {
                dim = vector.count
            } else if vector.count != dim {
                continue
            }
            rows.append(Self.l2Normalize(vector))
            ids.append(asset.localIdentifier)
        }

        return EmbeddingIndexSnapshot(assetIDs: ids, vectors: rows, dimension: dim)
    }

    /// Batch cosine similarity of a single query vector against every row
    /// of `snapshot`, via `vDSP_mmul`. Returns one similarity per snapshot
    /// row, in row order (parallel to `snapshot.assetIDs`).
    ///
    /// The query is normalized internally. If the snapshot is empty or
    /// the query dimension doesn't match, returns an empty array.
    public func batchSimilarity(
        query: [Float],
        snapshot: EmbeddingIndexSnapshot
    ) -> [Float] {
        let n = snapshot.vectors.count
        let d = snapshot.dimension
        guard n > 0, d > 0, query.count == d else { return [] }

        // Flatten snapshot into row-major [n x d] matrix.
        var matrix = [Float](repeating: 0, count: n * d)
        for (i, row) in snapshot.vectors.enumerated() {
            matrix.withUnsafeMutableBufferPointer { buf in
                row.withUnsafeBufferPointer { src in
                    buf.baseAddress!.advanced(by: i * d)
                        .update(from: src.baseAddress!, count: d)
                }
            }
        }

        let normalizedQuery = Self.l2Normalize(query)
        var out = [Float](repeating: 0, count: n)

        // matrix [n x d] * query [d x 1] = out [n x 1]
        matrix.withUnsafeBufferPointer { mBuf in
            normalizedQuery.withUnsafeBufferPointer { qBuf in
                out.withUnsafeMutableBufferPointer { oBuf in
                    vDSP_mmul(
                        mBuf.baseAddress!, 1,
                        qBuf.baseAddress!, 1,
                        oBuf.baseAddress!, 1,
                        vDSP_Length(n),
                        vDSP_Length(1),
                        vDSP_Length(d)
                    )
                }
            }
        }
        return out
    }

    // MARK: - Static helpers

    /// Decode a serialized `VNFeaturePrintObservation` from Data.
    ///
    /// The Vision pipeline (Task 2 in Phase 1) serializes observations
    /// via `NSKeyedArchiver.archivedData(withRootObject:requiringSecureCoding: true)`.
    /// We unarchive with the matching secure-coding API.
    static func decodeFeaturePrint(_ data: Data) -> VNFeaturePrintObservation? {
        // VNFeaturePrintObservation conforms to NSSecureCoding. Use the
        // secure unarchiver path to stay consistent with how blobs are
        // written upstream.
        do {
            return try NSKeyedUnarchiver.unarchivedObject(
                ofClass: VNFeaturePrintObservation.self,
                from: data
            )
        } catch {
            return nil
        }
    }

    /// Extract the underlying Float vector from a VNFeaturePrintObservation.
    ///
    /// `VNFeaturePrintObservation.data` is an `NSData` whose element type
    /// is described by `elementType` + `elementCount`. In practice Apple
    /// produces `.float` (32-bit) prints; we handle both `.float` and
    /// `.double` defensively (doubles down-cast to Float).
    static func extractVector(from obs: VNFeaturePrintObservation) -> [Float]? {
        let count = obs.elementCount
        guard count > 0 else { return nil }
        let raw = obs.data

        switch obs.elementType {
        case .float:
            return raw.withUnsafeBytes { buf -> [Float]? in
                guard let base = buf.baseAddress else { return nil }
                let typed = base.assumingMemoryBound(to: Float.self)
                return Array(UnsafeBufferPointer(start: typed, count: count))
            }
        case .double:
            return raw.withUnsafeBytes { buf -> [Float]? in
                guard let base = buf.baseAddress else { return nil }
                let typed = base.assumingMemoryBound(to: Double.self)
                var out = [Float](repeating: 0, count: count)
                for i in 0..<count {
                    out[i] = Float(typed[i])
                }
                return out
            }
        default:
            return nil
        }
    }

    /// L2-normalize a vector via Accelerate. Zero vectors pass through
    /// unchanged to avoid NaN.
    static func l2Normalize(_ v: [Float]) -> [Float] {
        let n = vDSP_Length(v.count)
        var out = [Float](repeating: 0, count: v.count)
        var mean: Float = 0
        var stddev: Float = 0

        // vDSP_normalize normalizes to zero-mean unit-variance — not what
        // we want. Compute the L2 norm directly, then scale.
        var sumSq: Float = 0
        v.withUnsafeBufferPointer { buf in
            vDSP_svesq(buf.baseAddress!, 1, &sumSq, n)
        }
        let norm = sqrtf(sumSq)
        guard norm > 0 else { return v }

        var inv = 1 / norm
        v.withUnsafeBufferPointer { vbuf in
            out.withUnsafeMutableBufferPointer { obuf in
                vDSP_vsmul(vbuf.baseAddress!, 1, &inv, obuf.baseAddress!, 1, n)
            }
        }

        // Silence unused-warnings for mean/stddev placeholders — we may
        // swap in vDSP_normalize later if the stats are useful.
        _ = mean
        _ = stddev
        return out
    }
}
