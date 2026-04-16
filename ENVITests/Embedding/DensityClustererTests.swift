//
//  DensityClustererTests.swift
//  ENVITests
//
//  Phase 2, Task 3 of Template Tab v1 — tests the native HDBSCAN port.
//  Uses a deterministic synthetic dataset so runs are reproducible on CI.
//

import XCTest
@testable import ENVI

final class DensityClustererTests: XCTestCase {

    // MARK: - Deterministic RNG (linear congruential, seeded)

    private struct SeededRNG {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
        mutating func nextFloat() -> Float {
            // Uniform in [0, 1).
            let u = next() >> 11 // 53 significant bits
            return Float(Double(u) / Double(1 << 53))
        }
        /// Box-Muller Gaussian.
        mutating func nextGaussian() -> Float {
            var u1 = nextFloat()
            if u1 < 1e-7 { u1 = 1e-7 }
            let u2 = nextFloat()
            let mag = sqrt(-2 * log(u1))
            return mag * cos(2 * .pi * u2)
        }
    }

    // MARK: - Fixtures

    /// 2 tight Gaussian clusters (each 12 pts) + 5 scattered noise points.
    private func makeTwoClustersPlusNoise() -> [[Float]] {
        var rng = SeededRNG(state: 0xC0FFEE)
        var pts: [[Float]] = []

        // Cluster A centered at (0, 0), σ = 0.05.
        for _ in 0..<12 {
            pts.append([rng.nextGaussian() * 0.05,
                        rng.nextGaussian() * 0.05])
        }
        // Cluster B centered at (5, 5), σ = 0.05.
        for _ in 0..<12 {
            pts.append([5 + rng.nextGaussian() * 0.05,
                        5 + rng.nextGaussian() * 0.05])
        }
        // 5 noise points scattered in [-4, 9]² but away from both cores.
        let noise: [[Float]] = [
            [-3.0, 8.0],
            [8.5, -2.0],
            [2.5, -3.5],
            [-2.5, 2.5],
            [7.5, 8.5],
        ]
        pts.append(contentsOf: noise)
        return pts
    }

    // MARK: - Tests

    func testTwoGaussianClustersPlusNoise() async {
        let pts = makeTwoClustersPlusNoise()
        let clusterer = DensityClusterer(minClusterSize: 5,
                                         minSamples: 3,
                                         metric: .euclidean)
        let labels = await clusterer.cluster(pts)

        XCTAssertEqual(labels.count, pts.count)

        let clusterALabels = Set(labels[0..<12])
        let clusterBLabels = Set(labels[12..<24])
        let noiseLabels = labels[24..<29]

        // Each cluster should be internally consistent (one label).
        XCTAssertEqual(clusterALabels.count, 1,
                       "Cluster A should share a single label, got \(clusterALabels)")
        XCTAssertEqual(clusterBLabels.count, 1,
                       "Cluster B should share a single label, got \(clusterBLabels)")

        // Neither cluster should be labeled as noise.
        XCTAssertNotEqual(clusterALabels.first, -1,
                          "Cluster A was labeled as noise")
        XCTAssertNotEqual(clusterBLabels.first, -1,
                          "Cluster B was labeled as noise")

        // The two clusters must have different labels.
        XCTAssertNotEqual(clusterALabels.first, clusterBLabels.first,
                          "Clusters A and B collapsed into the same label")

        // Noise points should be labeled -1.
        for (i, lbl) in noiseLabels.enumerated() {
            XCTAssertEqual(lbl, -1,
                           "Noise point \(i) got cluster label \(lbl)")
        }
    }

    func testStabilityAcrossRuns() async {
        let pts = makeTwoClustersPlusNoise()
        let clusterer = DensityClusterer(minClusterSize: 5,
                                         minSamples: 3,
                                         metric: .euclidean)
        let first = await clusterer.cluster(pts)
        let second = await clusterer.cluster(pts)
        XCTAssertEqual(first, second,
                       "HDBSCAN is non-deterministic across repeated calls")
    }

    func testEmptyInput() async {
        let clusterer = DensityClusterer()
        let labels = await clusterer.cluster([])
        XCTAssertEqual(labels, [])
    }

    func testBelowMinClusterSizeReturnsAllNoise() async {
        let clusterer = DensityClusterer(minClusterSize: 5, minSamples: 3)
        let pts: [[Float]] = [[0, 0], [0.01, 0.0], [0.0, 0.01]]
        let labels = await clusterer.cluster(pts)
        XCTAssertEqual(labels, [-1, -1, -1])
    }

    func testCosineMetricClustersNormalizedVectors() async {
        // Two directions on the unit sphere in 8-D with small angular jitter.
        var rng = SeededRNG(state: 0xBADF00D)
        func jittered(_ dir: [Float]) -> [Float] {
            var v = dir.map { $0 + rng.nextGaussian() * 0.01 }
            // No need to normalize here — DensityClusterer does it internally
            // for cosine metric, but normalizing makes the test intent clear.
            var norm: Float = 0
            for x in v { norm += x * x }
            norm = sqrt(norm)
            if norm > 0 { v = v.map { $0 / norm } }
            return v
        }
        var pts: [[Float]] = []
        let dirA: [Float] = [1, 0, 0, 0, 0, 0, 0, 0]
        let dirB: [Float] = [0, 0, 0, 0, 0, 0, 0, 1]
        for _ in 0..<10 { pts.append(jittered(dirA)) }
        for _ in 0..<10 { pts.append(jittered(dirB)) }

        let clusterer = DensityClusterer(minClusterSize: 5,
                                         minSamples: 3,
                                         metric: .cosine)
        let labels = await clusterer.cluster(pts)
        let setA = Set(labels[0..<10])
        let setB = Set(labels[10..<20])
        XCTAssertEqual(setA.count, 1)
        XCTAssertEqual(setB.count, 1)
        XCTAssertNotEqual(setA.first, -1)
        XCTAssertNotEqual(setB.first, -1)
        XCTAssertNotEqual(setA.first, setB.first)
    }
}
