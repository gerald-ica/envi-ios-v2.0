//
//  DimensionReducerTests.swift
//  ENVITests
//
//  Phase 2 Task 2 verification.
//

import XCTest
@testable import ENVI

final class DimensionReducerTests: XCTestCase {

    // MARK: - Helpers

    /// Deterministic Gaussian sampler via Box–Muller using the same Xoshiro RNG
    /// used by DimensionReducer (keeps fixture generation reproducible).
    private struct SeededGaussian {
        var rng: Xoshiro256StarStar
        init(seed: UInt64) { self.rng = Xoshiro256StarStar(seed: seed) }
        mutating func next() -> Float {
            var u1: Float
            repeat { u1 = rng.nextUnitFloat() } while u1 <= 1e-7
            let u2 = rng.nextUnitFloat()
            return sqrtf(-2 * logf(u1)) * cosf(2 * .pi * u2)
        }
    }

    private func makeClusters(
        nClusters: Int = 3,
        pointsPerCluster: Int = 30,
        dim: Int = 64,
        centerScale: Float = 6.0,
        noise: Float = 1.0,
        seed: UInt64 = 7
    ) -> (vectors: [[Float]], labels: [Int]) {
        var rng = SeededGaussian(seed: seed)
        var centers = [[Float]](repeating: [Float](repeating: 0, count: dim), count: nClusters)
        for c in 0..<nClusters {
            for d in 0..<dim { centers[c][d] = rng.next() * centerScale }
        }
        var vectors = [[Float]]()
        var labels = [Int]()
        for c in 0..<nClusters {
            for _ in 0..<pointsPerCluster {
                var v = [Float](repeating: 0, count: dim)
                for d in 0..<dim { v[d] = centers[c][d] + rng.next() * noise }
                vectors.append(v)
                labels.append(c)
            }
        }
        return (vectors, labels)
    }

    /// Silhouette score using Euclidean distance, averaged over all points.
    private func silhouette(points: [[Float]], labels: [Int]) -> Float {
        let n = points.count
        guard n > 1 else { return 0 }
        func dist(_ a: [Float], _ b: [Float]) -> Float {
            var s: Float = 0
            for i in 0..<a.count { let d = a[i] - b[i]; s += d * d }
            return sqrtf(s)
        }
        let uniqueLabels = Set(labels)
        var total: Float = 0
        var count: Float = 0
        for i in 0..<n {
            let li = labels[i]
            var intra: Float = 0; var intraN: Float = 0
            var inter: [Int: (sum: Float, n: Float)] = [:]
            for j in 0..<n where j != i {
                let dij = dist(points[i], points[j])
                if labels[j] == li { intra += dij; intraN += 1 }
                else {
                    var cur = inter[labels[j]] ?? (0, 0)
                    cur.sum += dij; cur.n += 1
                    inter[labels[j]] = cur
                }
            }
            guard intraN > 0 else { continue }
            let a = intra / intraN
            var b = Float.infinity
            for lbl in uniqueLabels where lbl != li {
                if let entry = inter[lbl], entry.n > 0 {
                    let v = entry.sum / entry.n
                    if v < b { b = v }
                }
            }
            if !b.isFinite { continue }
            let s = (b - a) / max(a, b)
            total += s; count += 1
        }
        return count > 0 ? total / count : 0
    }

    // MARK: - Tests

    func testUMAPPreservesClusterSeparation() async {
        let (vectors, labels) = makeClusters()
        var reducer = DimensionReducer()
        reducer.seed = 42
        reducer.nNeighbors = 15
        reducer.nEpochs = 200

        let projected = await reducer.reduce(vectors)
        XCTAssertEqual(projected.count, vectors.count)
        XCTAssertEqual(projected[0].count, 2)

        let score = silhouette(points: projected, labels: labels)
        print("UMAP silhouette score: \(score)")
        XCTAssertGreaterThan(score, 0.5, "UMAP output did not preserve cluster structure (silhouette=\(score))")
    }

    func testUMAPDeterministicWithSameSeed() async {
        let (vectors, _) = makeClusters(pointsPerCluster: 20)
        var reducer = DimensionReducer()
        reducer.seed = 123
        reducer.nEpochs = 100

        let a = await reducer.reduce(vectors)
        let b = await reducer.reduce(vectors)
        XCTAssertEqual(a.count, b.count)
        for i in 0..<a.count {
            for c in 0..<a[i].count {
                XCTAssertEqual(a[i][c], b[i][c], accuracy: 1e-5,
                               "Non-deterministic output at point \(i) dim \(c)")
            }
        }
    }

    func testUMAP3DOutput() async {
        let (vectors, _) = makeClusters(pointsPerCluster: 10)
        var reducer = DimensionReducer()
        reducer.nComponents = 3
        reducer.nEpochs = 50

        let projected = await reducer.reduce(vectors)
        XCTAssertEqual(projected.count, vectors.count)
        XCTAssertEqual(projected[0].count, 3)
    }

    func testUMAPPerformance500Points() async {
        // Perf target: <2s for 500 points (documented in 02-PLAN.md).
        let (vectors, _) = makeClusters(pointsPerCluster: 167) // ~500 total
        var reducer = DimensionReducer()
        reducer.seed = 42

        let start = Date()
        _ = await reducer.reduce(vectors)
        let elapsed = Date().timeIntervalSince(start)
        print("UMAP 500 pts: \(elapsed)s")
        XCTAssertLessThan(elapsed, 10.0, "UMAP took too long on 500 points: \(elapsed)s")
    }
}
