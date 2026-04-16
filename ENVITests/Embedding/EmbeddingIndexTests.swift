//
//  EmbeddingIndexTests.swift
//  ENVITests
//
//  Unit tests for Phase 2, Task 4 — EmbeddingIndex facade.
//
//  Strategy:
//    - `testRebuildThenLookup`: seed ~100 synthetic ClassifiedAssets in an
//      in-memory ClassificationCache. Each gets a real VNFeaturePrintObservation
//      produced from a solid-color CGImage (same pattern used by
//      SimilarityEngineTests). Call `rebuild`, then verify that every
//      downstream accessor returns non-empty, reasonable results.
//
//    - `testCheckpointRoundTrip`: rebuild → saveCheckpoint → new instance →
//      loadCheckpoint → verify state equality. Uses a per-test temp file so
//      tests don't touch the real app-support directory.
//
//    - `testBoundedTo5000`: exercises the static `boundAssets` helper with
//      6 000 lightweight assets (no Vision work — we never need to decode
//      them). Verifies ordering is by creationDate descending and the cap
//      is enforced.
//

import XCTest
import Vision
import CoreGraphics
@testable import ENVI

final class EmbeddingIndexTests: XCTestCase {

    // MARK: - Fixtures

    /// Synthesize a solid-color CGImage.
    private func makeSolidImage(red: CGFloat, green: CGFloat, blue: CGFloat,
                                size: CGSize = CGSize(width: 64, height: 64)) -> CGImage? {
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 1))
        ctx.fill(CGRect(origin: .zero, size: size))
        return ctx.makeImage()
    }

    /// Run Vision feature-print request over a CGImage and archive to Data.
    private func featurePrintData(for image: CGImage) throws -> Data {
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        let request = VNGenerateImageFeaturePrintRequest()
        try handler.perform([request])
        guard let obs = request.results?.first as? VNFeaturePrintObservation else {
            throw XCTSkip("Vision produced no feature print (simulator without ML support?)")
        }
        return try NSKeyedArchiver.archivedData(withRootObject: obs, requiringSecureCoding: true)
    }

    /// Build a lightweight ClassifiedAsset with the given feature print.
    private func makeAsset(id: String, featurePrint: Data?,
                           creationDate: Date? = nil) -> ClassifiedAsset {
        ClassifiedAsset(
            localIdentifier: id,
            classifiedAt: Date(),
            metadata: Data(),
            visionAnalysis: Data(),
            featurePrint: featurePrint,
            creationDate: creationDate
        )
    }

    /// Generate `count` assets with feature prints from a small palette of
    /// colors, so clustering has meaningful structure. Returns the list of
    /// seeded assets plus an in-memory ClassificationCache holding them.
    private func seedCache(count: Int) async throws -> (ClassificationCache, [ClassifiedAsset]) {
        let cache = try ClassificationCache(inMemory: true)
        // Three color "themes" so HDBSCAN finds something to cluster.
        let palette: [(CGFloat, CGFloat, CGFloat)] = [
            (1.0, 0.1, 0.1),
            (0.1, 1.0, 0.1),
            (0.1, 0.1, 1.0)
        ]
        // Pre-compute one feature print per palette entry — Vision is slow,
        // so we reuse the same blob for assets in the same theme.
        var blobs: [Data] = []
        for (r, g, b) in palette {
            guard let img = makeSolidImage(red: r, green: g, blue: b) else {
                throw XCTSkip("CGImage synthesis failed")
            }
            blobs.append(try featurePrintData(for: img))
        }

        var assets: [ClassifiedAsset] = []
        assets.reserveCapacity(count)
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        for i in 0..<count {
            let blob = blobs[i % blobs.count]
            let creation = baseDate.addingTimeInterval(Double(i) * 60)
            let asset = makeAsset(
                id: "asset-\(i)",
                featurePrint: blob,
                creationDate: creation
            )
            assets.append(asset)
        }
        try await cache.batchUpsert(assets)
        return (cache, assets)
    }

    /// Temporary checkpoint URL, unique per test invocation.
    private func tempCheckpointURL() -> URL {
        let dir = FileManager.default.temporaryDirectory
        return dir.appendingPathComponent("EmbeddingIndex-\(UUID().uuidString).cache")
    }

    // MARK: - Tests

    func testRebuildThenLookup() async throws {
        let (cache, assets) = try await seedCache(count: 90)
        let url = tempCheckpointURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let index = EmbeddingIndex(checkpointURL: url)
        await index.rebuild(from: cache)

        // findSimilar should return up to k results, none of which is the seed.
        let seedID = assets[0].localIdentifier
        let similar = await index.findSimilar(to: seedID, k: 5)
        XCTAssertFalse(similar.isEmpty, "findSimilar should return non-empty results")
        XCTAssertFalse(similar.contains(seedID), "findSimilar must exclude the seed itself")

        // clusters() should cover every seeded asset, at least as -1.
        let clusters = await index.clusters()
        XCTAssertEqual(clusters.count, assets.count,
                       "clusters() should have one entry per seeded asset")

        // projection2D() should have entries for every seeded asset.
        let proj = await index.projection2D()
        XCTAssertEqual(proj.count, assets.count,
                       "projection2D() should have one coord per seeded asset")

        // similarityMatrix over a slice should be square and have 1.0 on
        // the diagonal for present IDs.
        let slice = Array(assets.prefix(4).map { $0.localIdentifier })
        let mat = await index.similarityMatrix(for: slice)
        XCTAssertEqual(mat.count, 4)
        for i in 0..<4 {
            XCTAssertEqual(mat[i].count, 4)
            XCTAssertEqual(mat[i][i], 1, accuracy: 1e-4,
                           "diagonal of similarity matrix should be 1")
        }
    }

    func testCheckpointRoundTrip() async throws {
        let (cache, assets) = try await seedCache(count: 30)
        let url = tempCheckpointURL()
        defer { try? FileManager.default.removeItem(at: url) }

        // Build + save in instance A.
        let indexA = EmbeddingIndex(checkpointURL: url)
        await indexA.rebuild(from: cache)
        let clustersA = await indexA.clusters()
        let projA = await indexA.projection2D()
        let similarA = await indexA.findSimilar(to: assets[0].localIdentifier, k: 3)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "rebuild should have written a checkpoint to disk")

        // Load into a fresh instance B.
        let indexB = EmbeddingIndex(checkpointURL: url)
        let loaded = await indexB.loadCheckpoint()
        XCTAssertTrue(loaded, "loadCheckpoint should succeed for a fresh checkpoint")

        let clustersB = await indexB.clusters()
        let projB = await indexB.projection2D()
        let similarB = await indexB.findSimilar(to: assets[0].localIdentifier, k: 3)

        XCTAssertEqual(clustersA, clustersB, "cluster labels should round-trip")
        XCTAssertEqual(clustersA.count, projB.count)
        XCTAssertEqual(similarA, similarB, "findSimilar should be deterministic across load")
        // Projection is floating point but was serialized exactly; compare
        // element-wise to guard against JSON-float drift.
        for (id, a) in projA {
            guard let b = projB[id] else {
                XCTFail("projection missing id \(id) after load")
                continue
            }
            XCTAssertEqual(a.0, b.0, accuracy: 1e-4)
            XCTAssertEqual(a.1, b.1, accuracy: 1e-4)
        }

        // Stale check: same cache, same hash → not stale.
        let stale = await indexB.isStale(for: cache)
        XCTAssertFalse(stale, "freshly-loaded checkpoint should not be stale for same cache")
    }

    func testBoundedTo5000() throws {
        // Generate 6 000 assets with strictly increasing creationDate.
        // We use a dummy 1-byte feature-print so boundAssets keeps them —
        // actual decoding never runs here.
        let dummyBlob = Data([0x00])
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        var assets: [ClassifiedAsset] = []
        assets.reserveCapacity(6_000)
        for i in 0..<6_000 {
            assets.append(ClassifiedAsset(
                localIdentifier: "asset-\(i)",
                classifiedAt: base,
                metadata: Data(),
                visionAnalysis: Data(),
                featurePrint: dummyBlob,
                creationDate: base.addingTimeInterval(Double(i) * 60)
            ))
        }
        // Shuffle so ordering isn't accidentally preserved by insertion order.
        assets.shuffle()

        let bounded = EmbeddingIndex.boundAssets(assets, max: EmbeddingIndex.maxAssets)
        XCTAssertEqual(bounded.count, 5_000, "bound should cap to maxAssets")

        // The 5 000 most recent means indices 1000..<6000 from the original
        // creationDate schedule.
        let ids = Set(bounded.map { $0.localIdentifier })
        for i in 1_000..<6_000 {
            XCTAssertTrue(ids.contains("asset-\(i)"),
                          "expected most-recent asset-\(i) to be retained")
        }
        for i in 0..<1_000 {
            XCTAssertFalse(ids.contains("asset-\(i)"),
                           "expected older asset-\(i) to be dropped")
        }

        // And the list should be sorted by creationDate descending.
        var prev: Date = .distantFuture
        for a in bounded {
            let d = a.creationDate ?? a.classifiedAt
            XCTAssertLessThanOrEqual(d, prev, "bounded list should be creationDate-descending")
            prev = d
        }
    }
}
