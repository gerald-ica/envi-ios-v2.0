//
//  SimilarityEngineTests.swift
//  ENVITests
//
//  Unit tests for Phase 2, Task 1: cosine similarity + top-K search.
//
//  Strategy:
//    The engine's primary input is serialized `VNFeaturePrintObservation`
//    Data, which we generate at test time by running a real
//    `VNGenerateImageFeaturePrintRequest` over synthesized solid-color
//    CGImages. Same-color images produce nearly-identical prints; very
//    different colors produce less similar prints. That gives us a
//    ground-truth ordering without shipping fixture images.
//
//    We also test `buildIndex` + `batchSimilarity` with hand-built
//    vectors (no Vision dependency) to pin down the Accelerate math.
//

import XCTest
import Vision
import CoreImage
import CoreGraphics
@testable import ENVI

final class SimilarityEngineTests: XCTestCase {

    // MARK: - Fixtures

    /// Synthesize a solid-color PNG-ish CGImage at a given size.
    private func makeSolidImage(
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        size: CGSize = CGSize(width: 128, height: 128)
    ) -> CGImage? {
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        ctx.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 1))
        ctx.fill(CGRect(origin: .zero, size: size))
        return ctx.makeImage()
    }

    /// Run Vision's feature-print request on a CGImage and return the
    /// serialized Data blob, the same way Phase 1's VisionAnalysisEngine
    /// would.
    private func featurePrintData(for image: CGImage) throws -> Data {
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        let request = VNGenerateImageFeaturePrintRequest()
        try handler.perform([request])
        guard let obs = request.results?.first as? VNFeaturePrintObservation else {
            throw XCTSkip("Vision produced no feature print (simulator without ML support?)")
        }
        return try NSKeyedArchiver.archivedData(
            withRootObject: obs,
            requiringSecureCoding: true
        )
    }

    /// Minimal ClassifiedAsset for test purposes. We only populate the
    /// fields `SimilarityEngine` actually reads.
    private func makeAsset(id: String, featurePrint: Data?) -> ClassifiedAsset {
        ClassifiedAsset(
            localIdentifier: id,
            metadata: Data(),
            visionAnalysis: Data(),
            featurePrint: featurePrint
        )
    }

    // MARK: - Tests

    /// Same-color images should be much more similar than very-different
    /// colors. The engine's ordering must match that intuition.
    func testTopKOrdering_withRealFeaturePrints() async throws {
        // Two blues + one red. Blues should cluster; red should rank
        // lowest against a blue query.
        guard
            let blueA = makeSolidImage(red: 0.10, green: 0.10, blue: 0.95),
            let blueB = makeSolidImage(red: 0.12, green: 0.12, blue: 0.92),
            let red   = makeSolidImage(red: 0.95, green: 0.10, blue: 0.10)
        else {
            XCTFail("Could not synthesize test CGImages")
            return
        }

        let blobA = try featurePrintData(for: blueA)
        let blobB = try featurePrintData(for: blueB)
        let blobR = try featurePrintData(for: red)

        let assets: [ClassifiedAsset] = [
            makeAsset(id: "blueA", featurePrint: blobA),
            makeAsset(id: "blueB", featurePrint: blobB),
            makeAsset(id: "red",   featurePrint: blobR),
        ]

        let engine = SimilarityEngine()
        let results = await engine.topK(
            queryFeature: blobA,
            candidates: assets,
            k: 2
        )

        XCTAssertEqual(results.count, 2, "Expected top-2 results")
        // The blueA blob is in candidates too — it should be first (self).
        XCTAssertEqual(results[0].0.localIdentifier, "blueA")
        // The other blue should beat the red.
        XCTAssertEqual(results[1].0.localIdentifier, "blueB",
                       "Second-most-similar to blueA should be blueB, not red")
        // Scores should be sorted descending.
        XCTAssertGreaterThanOrEqual(results[0].1, results[1].1)
    }

    /// Pairwise similarity between two copies of the same blob should be
    /// close to 1. Between blue and red it should be noticeably lower.
    func testPairwiseSimilarity_realFeaturePrints() async throws {
        guard
            let blue = makeSolidImage(red: 0.10, green: 0.10, blue: 0.95),
            let red  = makeSolidImage(red: 0.95, green: 0.10, blue: 0.10)
        else {
            XCTFail("Could not synthesize test CGImages")
            return
        }

        let blueBlob = try featurePrintData(for: blue)
        let redBlob  = try featurePrintData(for: red)

        let engine = SimilarityEngine()
        let sameSim  = await engine.similarity(between: blueBlob, and: blueBlob)
        let crossSim = await engine.similarity(between: blueBlob, and: redBlob)

        // Self-similarity should be (essentially) 1.
        XCTAssertEqual(sameSim, 1.0, accuracy: 0.01,
                       "Self-similarity should be ~1")
        // Cross similarity must be strictly lower. We don't pin the exact
        // delta (Vision's distance metric is not scale-normalized the
        // same way on every OS version) — just assert ordering.
        XCTAssertLessThan(crossSim, sameSim,
                          "Different-color sim should be lower than self-sim")
    }

    /// Exercise the `batchSimilarity` + `buildIndex` path with hand-built
    /// vectors. This pins down the Accelerate math independent of Vision.
    ///
    /// Vectors: a=[1,0,0], b=[0.9,0.1,0] (close to a), c=[0,1,0] (far).
    /// Query = a. Expected ordering: a > b > c.
    func testBatchSimilarity_withSyntheticVectors() async {
        let engine = SimilarityEngine()

        let snapshot = EmbeddingIndexSnapshot(
            assetIDs: ["a", "b", "c"],
            vectors: [
                SimilarityEngine.l2Normalize([1, 0, 0]),
                SimilarityEngine.l2Normalize([0.9, 0.1, 0]),
                SimilarityEngine.l2Normalize([0, 1, 0]),
            ],
            dimension: 3
        )

        let sims = await engine.batchSimilarity(
            query: [1, 0, 0],
            snapshot: snapshot
        )

        XCTAssertEqual(sims.count, 3)
        XCTAssertEqual(sims[0], 1.0, accuracy: 1e-5)
        // b is close to a but not identical — cos sim ~ 0.9 / sqrt(0.82)
        XCTAssertGreaterThan(sims[1], 0.9)
        XCTAssertLessThan(sims[1], 1.0)
        // c is orthogonal.
        XCTAssertEqual(sims[2], 0.0, accuracy: 1e-5)

        // Ordering check: a > b > c.
        XCTAssertGreaterThan(sims[0], sims[1])
        XCTAssertGreaterThan(sims[1], sims[2])
    }

    /// Empty / degenerate inputs must not crash.
    func testEdgeCases() async {
        let engine = SimilarityEngine()

        let emptyTopK = await engine.topK(
            queryFeature: Data(),
            candidates: [],
            k: 5
        )
        XCTAssertTrue(emptyTopK.isEmpty)

        let zeroK = await engine.topK(
            queryFeature: Data([0, 1, 2]),
            candidates: [makeAsset(id: "x", featurePrint: nil)],
            k: 0
        )
        XCTAssertTrue(zeroK.isEmpty)

        let badSim = await engine.similarity(
            between: Data([0, 1, 2]),
            and: Data([3, 4, 5])
        )
        XCTAssertEqual(badSim, 0, "Undecodable blobs should score 0")
    }
}
