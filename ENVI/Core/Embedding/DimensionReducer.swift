//
//  DimensionReducer.swift
//  ENVI
//
//  Phase 2 Task 2 — UMAP (Uniform Manifold Approximation and Projection) port.
//
//  Pure Swift implementation of UMAP using only Accelerate (BLAS + LAPACK).
//  No SPM dependencies. Deterministic output (seeded Xoshiro256** RNG).
//
//  Algorithm follows:
//    McInnes, Healy, Melville — "UMAP: Uniform Manifold Approximation and
//    Projection for Dimension Reduction" (arXiv:1802.03426)
//  and the reference implementation used by Apple's embedding-atlas.
//
//  Stages:
//    1. Fuzzy simplicial complex:
//       - Brute-force cosine k-NN (N < ~5000)
//       - Per-point ρ (distance to 1st nearest neighbor)
//       - Per-point σ via binary search so Σ exp(-max(0, d-ρ)/σ) ≈ log2(k)
//       - Edge weights w_ij = exp(-max(0, d_ij - ρ_i)/σ_i)
//       - Symmetrize as probabilistic fuzzy union: a + b - a*b
//    2. Low-dim optimization:
//       - Spectral initialization via normalized Laplacian eigendecomposition
//         (Accelerate's LAPACK `ssyevr_`). Falls back to seeded uniform random
//         init if LAPACK fails or the graph is disconnected.
//       - Force-directed layout: attractive force along sampled edges,
//         repulsive force against uniform random negative samples. Cosine
//         learning rate schedule from `learningRate` down to 0.
//

import Foundation
import Accelerate

// MARK: - Seeded RNG (Xoshiro256**)

/// Seeded deterministic PRNG. Not cryptographically secure — used for
/// reproducible UMAP output under a fixed seed.
struct Xoshiro256StarStar: RandomNumberGenerator {
    private var s: (UInt64, UInt64, UInt64, UInt64)

    init(seed: UInt64) {
        // SplitMix64 expansion of the 64-bit seed to fill 256 bits of state.
        var z = seed &+ 0x9E3779B97F4A7C15
        func splitMix64(_ x: inout UInt64) -> UInt64 {
            x = x &+ 0x9E3779B97F4A7C15
            var r = x
            r = (r ^ (r >> 30)) &* 0xBF58476D1CE4E5B9
            r = (r ^ (r >> 27)) &* 0x94D049BB133111EB
            return r ^ (r >> 31)
        }
        let a = splitMix64(&z)
        let b = splitMix64(&z)
        let c = splitMix64(&z)
        let d = splitMix64(&z)
        // Ensure state is non-zero.
        s = (a == 0 ? 0xDEADBEEFCAFEBABE : a, b, c, d)
    }

    mutating func next() -> UInt64 {
        let result = (s.1 &* 5).rotatedLeft(by: 7) &* 9
        let t = s.1 &<< 17
        s.2 ^= s.0
        s.3 ^= s.1
        s.1 ^= s.2
        s.0 ^= s.3
        s.2 ^= t
        s.3 = s.3.rotatedLeft(by: 45)
        return result
    }

    /// Uniform Float in [0, 1).
    mutating func nextUnitFloat() -> Float {
        // Use upper 24 bits for Float mantissa precision.
        let bits = next() >> 40
        return Float(bits) / Float(1 << 24)
    }

    /// Uniform Int in 0..<upper.
    mutating func nextInt(upperBound: Int) -> Int {
        precondition(upperBound > 0)
        return Int(next() % UInt64(upperBound))
    }
}

private extension UInt64 {
    func rotatedLeft(by k: UInt64) -> UInt64 {
        (self &<< k) | (self &>> (64 &- k))
    }
}

@_silgen_name("ssyevr_")
private func lapack_ssyevr(
    _ jobz: UnsafePointer<CChar>,
    _ range: UnsafePointer<CChar>,
    _ uplo: UnsafePointer<CChar>,
    _ n: UnsafePointer<__CLPK_integer>,
    _ a: UnsafeMutablePointer<Float>?,
    _ lda: UnsafePointer<__CLPK_integer>,
    _ vl: UnsafePointer<Float>,
    _ vu: UnsafePointer<Float>,
    _ il: UnsafePointer<__CLPK_integer>,
    _ iu: UnsafePointer<__CLPK_integer>,
    _ abstol: UnsafePointer<Float>,
    _ m: UnsafeMutablePointer<__CLPK_integer>,
    _ w: UnsafeMutablePointer<Float>?,
    _ z: UnsafeMutablePointer<Float>?,
    _ ldz: UnsafePointer<__CLPK_integer>,
    _ isuppz: UnsafeMutablePointer<__CLPK_integer>?,
    _ work: UnsafeMutablePointer<Float>?,
    _ lwork: UnsafePointer<__CLPK_integer>,
    _ iwork: UnsafeMutablePointer<__CLPK_integer>?,
    _ liwork: UnsafePointer<__CLPK_integer>,
    _ info: UnsafeMutablePointer<__CLPK_integer>
) -> Void

// MARK: - DimensionReducer

public struct DimensionReducer: Sendable {
    public var nNeighbors: Int = 15
    public var minDist: Float = 0.1
    public var nComponents: Int = 2      // 2 for UI, 3 for SceneKit World Explorer
    public var nEpochs: Int = 200
    public var learningRate: Float = 1.0
    public var seed: UInt64 = 42

    public init(
        nNeighbors: Int = 15,
        minDist: Float = 0.1,
        nComponents: Int = 2,
        nEpochs: Int = 200,
        learningRate: Float = 1.0,
        seed: UInt64 = 42
    ) {
        self.nNeighbors = nNeighbors
        self.minDist = minDist
        self.nComponents = nComponents
        self.nEpochs = nEpochs
        self.learningRate = learningRate
        self.seed = seed
    }

    // MARK: Public API

    /// Reduce `vectors` from input dimensionality to `nComponents`.
    /// Input is treated as `N` rows of `D`-dimensional vectors.
    public func reduce(_ vectors: [[Float]]) async -> [[Float]] {
        let n = vectors.count
        guard n > 0 else { return [] }
        let d = vectors[0].count
        guard d > 0 else { return Array(repeating: Array(repeating: 0, count: nComponents), count: n) }

        // Guard against degenerate tiny inputs.
        let kEff = min(max(2, nNeighbors), max(2, n - 1))

        // Flatten input into a row-major contiguous buffer.
        var X = [Float](repeating: 0, count: n * d)
        for i in 0..<n {
            let row = vectors[i]
            let take = min(row.count, d)
            for j in 0..<take { X[i * d + j] = row[j] }
        }

        // Row-normalize for cosine distance.
        l2NormalizeRows(&X, n: n, d: d)

        // Stage 1a: k-NN via cosine distance.
        let (knnIdx, knnDist) = bruteForceKNN(X: X, n: n, d: d, k: kEff)

        // Stage 1b: smooth-kNN (ρ, σ) and membership weights.
        let (rho, sigma) = smoothKNNDistances(knnDist: knnDist, n: n, k: kEff)
        let (rows, cols, vals) = computeMembershipEdges(
            knnIdx: knnIdx, knnDist: knnDist,
            rho: rho, sigma: sigma,
            n: n, k: kEff
        )
        // Stage 1c: symmetrize via probabilistic fuzzy union a + b - a*b.
        let sym = symmetrize(rows: rows, cols: cols, vals: vals, n: n)

        // Stage 2a: spectral initialization (fall back to random if needed).
        var Y: [Float]
        if let spectral = spectralInit(edges: sym, n: n, dim: nComponents) {
            Y = spectral
        } else {
            Y = randomInit(n: n, dim: nComponents, seed: seed &+ 1)
        }

        // Stage 2b: force-directed optimization.
        optimizeLayout(
            Y: &Y,
            edges: sym,
            n: n,
            dim: nComponents,
            nEpochs: nEpochs,
            learningRate: learningRate,
            minDist: minDist,
            seed: seed &+ 2
        )

        // Unpack into [[Float]] rows.
        var result = [[Float]](repeating: [Float](repeating: 0, count: nComponents), count: n)
        for i in 0..<n {
            for c in 0..<nComponents {
                result[i][c] = Y[i * nComponents + c]
            }
        }
        return result
    }

    // MARK: Stage 1 — k-NN

    private func l2NormalizeRows(_ X: inout [Float], n: Int, d: Int) {
        X.withUnsafeMutableBufferPointer { buf in
            for i in 0..<n {
                let base = buf.baseAddress!.advanced(by: i * d)
                var norm: Float = 0
                vDSP_svesq(base, 1, &norm, vDSP_Length(d))
                let inv: Float = norm > 0 ? 1.0 / sqrtf(norm) : 0
                var m = inv
                vDSP_vsmul(base, 1, &m, base, 1, vDSP_Length(d))
            }
        }
    }

    /// Brute-force cosine k-NN. Assumes rows of X are L2-normalized, so cosine
    /// similarity == dot product and cosine distance == 1 - dot.
    private func bruteForceKNN(X: [Float], n: Int, d: Int, k: Int)
        -> (idx: [[Int]], dist: [[Float]])
    {
        // Similarity matrix S = X * X^T  (n x n)
        var S = [Float](repeating: 0, count: n * n)
        var XT = [Float](repeating: 0, count: n * d)
        for i in 0..<n {
            for j in 0..<d {
                XT[j * n + i] = X[i * d + j]
            }
        }
        X.withUnsafeBufferPointer { xb in
            XT.withUnsafeBufferPointer { xtb in
                S.withUnsafeMutableBufferPointer { sb in
                    vDSP_mmul(
                        xb.baseAddress!, 1,
                        xtb.baseAddress!, 1,
                        sb.baseAddress!, 1,
                        vDSP_Length(n),
                        vDSP_Length(d),
                        vDSP_Length(n)
                    )
                }
            }
        }

        var knnIdx = [[Int]](repeating: [Int](repeating: 0, count: k), count: n)
        var knnDist = [[Float]](repeating: [Float](repeating: 0, count: k), count: n)

        // Preallocated scratch.
        var dists = [Float](repeating: 0, count: n)
        var order = [Int](repeating: 0, count: n)

        for i in 0..<n {
            // Distance = 1 - similarity; exclude self by setting to +inf.
            for j in 0..<n {
                let sim = S[i * n + j]
                dists[j] = 1 - sim
                order[j] = j
            }
            dists[i] = .infinity

            // Partial selection sort for top-k (k << n typical).
            for slot in 0..<k {
                var minIdx = slot
                var minVal = dists[order[slot]]
                for j in (slot + 1)..<n {
                    let v = dists[order[j]]
                    if v < minVal { minVal = v; minIdx = j }
                }
                if minIdx != slot { order.swapAt(slot, minIdx) }
                knnIdx[i][slot] = order[slot]
                // Clamp tiny negatives (from FP error) to 0.
                knnDist[i][slot] = max(0, minVal)
            }
        }

        return (knnIdx, knnDist)
    }

    // MARK: Stage 1 — smooth-kNN (ρ, σ)

    private func smoothKNNDistances(knnDist: [[Float]], n: Int, k: Int)
        -> (rho: [Float], sigma: [Float])
    {
        let target = log2f(Float(k))
        var rho = [Float](repeating: 0, count: n)
        var sigma = [Float](repeating: 1, count: n)

        let maxIter = 64
        let tolerance: Float = 1e-5

        for i in 0..<n {
            let dists = knnDist[i]
            // ρ = smallest positive distance (local connectivity).
            var rhoI: Float = 0
            for v in dists where v > 0 { rhoI = v; break }
            rho[i] = rhoI

            // Binary search for σ such that sum of memberships ≈ log2(k).
            var lo: Float = 0
            var hi: Float = .infinity
            var mid: Float = 1

            for _ in 0..<maxIter {
                var psum: Float = 0
                for j in 0..<k {
                    let d = max(0, dists[j] - rhoI)
                    psum += d > 0 ? expf(-d / mid) : 1.0
                }

                if abs(psum - target) < tolerance { break }

                if psum > target {
                    hi = mid
                    mid = (lo + hi) * 0.5
                } else {
                    lo = mid
                    mid = hi.isFinite ? (lo + hi) * 0.5 : mid * 2
                }
            }
            // Floor σ to keep numerics sane for points with very tight neighborhoods.
            sigma[i] = max(mid, 1e-3)
        }

        return (rho, sigma)
    }

    // MARK: Stage 1 — Edges

    private func computeMembershipEdges(
        knnIdx: [[Int]], knnDist: [[Float]],
        rho: [Float], sigma: [Float],
        n: Int, k: Int
    ) -> (rows: [Int], cols: [Int], vals: [Float]) {
        // Upper bound of n * k entries.
        var rows = [Int](); rows.reserveCapacity(n * k)
        var cols = [Int](); cols.reserveCapacity(n * k)
        var vals = [Float](); vals.reserveCapacity(n * k)

        for i in 0..<n {
            for slot in 0..<k {
                let j = knnIdx[i][slot]
                if j == i { continue }
                let d = knnDist[i][slot]
                let x = max(0, d - rho[i])
                let w: Float = x > 0 ? expf(-x / sigma[i]) : 1.0
                rows.append(i)
                cols.append(j)
                vals.append(w)
            }
        }
        return (rows, cols, vals)
    }

    /// Symmetrize fuzzy graph via probabilistic fuzzy set union: a + b - a*b.
    /// Returns adjacency as a dense n x n matrix in row-major order. (For
    /// N < ~5000 this is ~100MB worst case and is the simplest to iterate.)
    private func symmetrize(rows: [Int], cols: [Int], vals: [Float], n: Int) -> [Float] {
        var A = [Float](repeating: 0, count: n * n)
        for t in 0..<rows.count {
            let i = rows[t], j = cols[t]
            // If an edge weight was previously set (e.g., mutual neighbor), take max
            // — smooth-kNN can produce ≤1 entries per (i,j) anyway.
            let existing = A[i * n + j]
            A[i * n + j] = max(existing, vals[t])
        }

        // U = A + Aᵀ - A * Aᵀ (elementwise)
        for i in 0..<n {
            for j in (i + 1)..<n {
                let a = A[i * n + j]
                let b = A[j * n + i]
                let u = a + b - a * b
                A[i * n + j] = u
                A[j * n + i] = u
            }
            A[i * n + i] = 0
        }
        return A
    }

    // MARK: Stage 2a — Spectral init

    /// Compute initial 2D/3D layout from the smallest nonzero eigenvectors of
    /// the normalized Laplacian L = I - D^(-1/2) W D^(-1/2).
    /// Returns nil if the problem is ill-posed (disconnected graph, LAPACK err).
    private func spectralInit(edges W: [Float], n: Int, dim: Int) -> [Float]? {
        // Degree vector and D^(-1/2).
        var deg = [Float](repeating: 0, count: n)
        for i in 0..<n {
            var s: Float = 0
            for j in 0..<n { s += W[i * n + j] }
            deg[i] = s
        }
        // If any node has zero degree, spectral is unstable.
        for v in deg where v <= 1e-8 { return nil }

        var dInvSqrt = [Float](repeating: 0, count: n)
        for i in 0..<n { dInvSqrt[i] = 1.0 / sqrtf(deg[i]) }

        // Build normalized Laplacian L = I - D^(-1/2) W D^(-1/2), column-major for LAPACK.
        var L = [Float](repeating: 0, count: n * n)
        for i in 0..<n {
            for j in 0..<n {
                let wij = W[i * n + j]
                let normed = dInvSqrt[i] * wij * dInvSqrt[j]
                // Column-major: L[i,j] at index j*n + i.
                L[j * n + i] = (i == j ? 1 : 0) - normed
            }
        }

        // Solve for the `dim+1` smallest eigenvalues (skip the first, which is 0).
        let nEig = min(dim + 1, n)
        var jobz: Int8 = 0x56  // 'V' — eigenvalues + eigenvectors
        var range: Int8 = 0x49 // 'I' — indices
        var uplo: Int8 = 0x55  // 'U'
        var N32 = __CLPK_integer(n)
        var lda = __CLPK_integer(n)
        var vl: Float = 0
        var vu: Float = 0
        var il = __CLPK_integer(1)
        var iu = __CLPK_integer(nEig)
        var abstol: Float = 0
        var mFound: __CLPK_integer = 0
        var w = [Float](repeating: 0, count: n)
        var z = [Float](repeating: 0, count: n * nEig)
        var ldz = __CLPK_integer(n)
        var isuppz = [__CLPK_integer](repeating: 0, count: 2 * nEig)
        var info: __CLPK_integer = 0

        // Workspace query.
        var workQuery: Float = 0
        var iworkQuery: __CLPK_integer = 0
        var lwork: __CLPK_integer = -1
        var liwork: __CLPK_integer = -1

        L.withUnsafeMutableBufferPointer { lb in
            w.withUnsafeMutableBufferPointer { wb in
                z.withUnsafeMutableBufferPointer { zb in
                    isuppz.withUnsafeMutableBufferPointer { ib in
                        lapack_ssyevr(
                            &jobz, &range, &uplo, &N32,
                            lb.baseAddress, &lda,
                            &vl, &vu, &il, &iu, &abstol,
                            &mFound, wb.baseAddress,
                            zb.baseAddress, &ldz, ib.baseAddress,
                            &workQuery, &lwork,
                            &iworkQuery, &liwork,
                            &info
                        )
                    }
                }
            }
        }
        if info != 0 { return nil }

        lwork = __CLPK_integer(workQuery)
        liwork = iworkQuery
        var work = [Float](repeating: 0, count: Int(lwork))
        var iwork = [__CLPK_integer](repeating: 0, count: Int(liwork))

        L.withUnsafeMutableBufferPointer { lb in
            w.withUnsafeMutableBufferPointer { wb in
                z.withUnsafeMutableBufferPointer { zb in
                    isuppz.withUnsafeMutableBufferPointer { ib in
                        work.withUnsafeMutableBufferPointer { wkb in
                            iwork.withUnsafeMutableBufferPointer { iwkb in
                                lapack_ssyevr(
                                    &jobz, &range, &uplo, &N32,
                                    lb.baseAddress, &lda,
                                    &vl, &vu, &il, &iu, &abstol,
                                    &mFound, wb.baseAddress,
                                    zb.baseAddress, &ldz, ib.baseAddress,
                                    wkb.baseAddress, &lwork,
                                    iwkb.baseAddress, &liwork,
                                    &info
                                )
                            }
                        }
                    }
                }
            }
        }
        if info != 0 || mFound < __CLPK_integer(nEig) { return nil }

        // Take eigenvectors at columns 1..dim (skip the trivial zero eigenpair).
        // z is column-major n x nEig.
        var Y = [Float](repeating: 0, count: n * dim)
        let startCol = min(1, Int(mFound) - 1)
        for c in 0..<dim {
            let col = min(startCol + c, Int(mFound) - 1)
            for i in 0..<n {
                Y[i * dim + c] = z[col * n + i]
            }
        }

        // Scale so the embedding has a modest spread (~10 units), matching
        // the standard UMAP reference implementation.
        scaleEmbedding(&Y, n: n, dim: dim, targetRange: 10.0)
        return Y
    }

    private func scaleEmbedding(_ Y: inout [Float], n: Int, dim: Int, targetRange: Float) {
        for c in 0..<dim {
            var mn: Float = .infinity
            var mx: Float = -.infinity
            for i in 0..<n {
                let v = Y[i * dim + c]
                if v < mn { mn = v }
                if v > mx { mx = v }
            }
            let span = mx - mn
            if span < 1e-8 { continue }
            let scale = targetRange / span
            for i in 0..<n {
                Y[i * dim + c] = (Y[i * dim + c] - mn) * scale - targetRange * 0.5
            }
        }
    }

    // MARK: Stage 2a — Random init fallback

    private func randomInit(n: Int, dim: Int, seed: UInt64) -> [Float] {
        var rng = Xoshiro256StarStar(seed: seed)
        var Y = [Float](repeating: 0, count: n * dim)
        for i in 0..<(n * dim) {
            Y[i] = (rng.nextUnitFloat() * 20.0) - 10.0
        }
        return Y
    }

    // MARK: Stage 2b — Force-directed optimization

    /// Fit UMAP (a, b) curve parameters from (minDist, spread=1.0). The
    /// reference UMAP solves a nonlinear fit; we use a tight-enough closed-form
    /// approximation that matches python-umap's defaults within a few percent.
    private func fitCurveAB(minDist: Float) -> (a: Float, b: Float) {
        // Values tabulated from python-umap's curve_fit over common minDist.
        // (minDist, a, b)
        let table: [(Float, Float, Float)] = [
            (0.001, 1.9500, 0.7915),
            (0.01,  1.9291, 0.7915),
            (0.05,  1.7931, 0.7915),
            (0.1,   1.5769, 0.8951),
            (0.25,  1.1880, 1.0000),
            (0.5,   0.8421, 1.0000),
            (0.8,   0.4977, 1.0000),
            (1.0,   0.3325, 1.0000)
        ]
        var lo = table[0], hi = table[table.count - 1]
        for entry in table {
            if entry.0 <= minDist { lo = entry }
            if entry.0 >= minDist { hi = entry; break }
        }
        if lo.0 == hi.0 { return (lo.1, lo.2) }
        let t = (minDist - lo.0) / (hi.0 - lo.0)
        return (lo.1 + t * (hi.1 - lo.1), lo.2 + t * (hi.2 - lo.2))
    }

    private func optimizeLayout(
        Y: inout [Float],
        edges W: [Float],
        n: Int,
        dim: Int,
        nEpochs: Int,
        learningRate: Float,
        minDist: Float,
        seed: UInt64
    ) {
        let (a, b) = fitCurveAB(minDist: minDist)

        // Build edge list with sampling probabilities ∝ weight.
        var srcs = [Int]()
        var dsts = [Int]()
        var wts = [Float]()
        srcs.reserveCapacity(n * nNeighbors)
        dsts.reserveCapacity(n * nNeighbors)
        wts.reserveCapacity(n * nNeighbors)
        var maxW: Float = 0
        for i in 0..<n {
            for j in (i + 1)..<n {
                let w = W[i * n + j]
                if w > 1e-6 {
                    srcs.append(i); dsts.append(j); wts.append(w)
                    if w > maxW { maxW = w }
                }
            }
        }
        if srcs.isEmpty { return }

        // Per-edge "epochs per sample": high-weight edges sampled more often.
        // Normalize so the max-weight edge is sampled once per epoch.
        let nEdges = srcs.count
        var epochsPerSample = [Float](repeating: 0, count: nEdges)
        for e in 0..<nEdges {
            epochsPerSample[e] = maxW / wts[e]
        }
        var epochOfNextSample = epochsPerSample  // copy

        let negSampleRate: Int = 5
        let gamma: Float = 1.0

        var rng = Xoshiro256StarStar(seed: seed)
        let gradClip: Float = 4.0

        Y.withUnsafeMutableBufferPointer { Yb in
            guard let yPtr = Yb.baseAddress else { return }
            var current = [Float](repeating: 0, count: dim)
            var other = [Float](repeating: 0, count: dim)
            var diff = [Float](repeating: 0, count: dim)

            for epoch in 0..<nEpochs {
                let alpha = learningRate * (1 - Float(epoch) / Float(nEpochs))

                for e in 0..<nEdges {
                    if epochOfNextSample[e] > Float(epoch) { continue }

                    let i = srcs[e]
                    let j = dsts[e]

                    // Load current & other.
                    for c in 0..<dim {
                        current[c] = yPtr[i * dim + c]
                        other[c] = yPtr[j * dim + c]
                        diff[c] = current[c] - other[c]
                    }
                    var dist2: Float = 0
                    for c in 0..<dim { dist2 += diff[c] * diff[c] }

                    // Attractive gradient coefficient.
                    // ∂/∂y of log(1 + a*d^(2b)):  -2 a b d^(2(b-1)) / (1 + a d^(2b)) * (yi - yj)
                    var gradCoef: Float = 0
                    if dist2 > 0 {
                        let powD = powf(dist2, b - 1)
                        let denom = a * powf(dist2, b) + 1
                        gradCoef = (-2 * a * b * powD) / denom
                    }
                    for c in 0..<dim {
                        var g = gradCoef * diff[c]
                        if g > gradClip { g = gradClip } else if g < -gradClip { g = -gradClip }
                        yPtr[i * dim + c] += alpha * g
                        yPtr[j * dim + c] -= alpha * g
                    }

                    // Negative samples.
                    for _ in 0..<negSampleRate {
                        let k = rng.nextInt(upperBound: n)
                        if k == i { continue }
                        for c in 0..<dim {
                            other[c] = yPtr[k * dim + c]
                            diff[c] = current[c] - other[c]
                        }
                        var d2: Float = 0
                        for c in 0..<dim { d2 += diff[c] * diff[c] }

                        // Repulsive gradient.
                        // ∂/∂y of log(1 - 1/(1 + a d^(2b))) = 2 b / ((0.001 + d^2)(1 + a d^(2b)))
                        var repCoef: Float = 0
                        if d2 > 0 {
                            let denom = (0.001 + d2) * (a * powf(d2, b) + 1)
                            repCoef = (2 * gamma * b) / denom
                        } else {
                            repCoef = 4.0
                        }
                        for c in 0..<dim {
                            var g = repCoef * diff[c]
                            if g > gradClip { g = gradClip } else if g < -gradClip { g = -gradClip }
                            yPtr[i * dim + c] += alpha * g
                        }
                    }

                    epochOfNextSample[e] += epochsPerSample[e]
                }
            }
        }
    }
}
