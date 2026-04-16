//
//  ClassificationCacheTests.swift
//  ENVITests
//
//  Unit tests for the Phase 1 SwiftData persistence layer.
//

import XCTest
import SwiftData
@testable import ENVI

final class ClassificationCacheTests: XCTestCase {

    // MARK: - Helpers

    /// Returns a cache backed by a unique on-disk SQLite store in the
    /// test temp dir. Uses disk (not in-memory) so performance numbers
    /// reflect the real production path.
    private func makeCache(file: StaticString = #file, line: UInt = #line) throws -> (ClassificationCache, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClassificationCacheTests-\(UUID().uuidString).sqlite")
        let cache = try ClassificationCache(storeURL: url)
        return (cache, url)
    }

    private func cleanup(_ url: URL) {
        // SwiftData writes sidecar files (-shm, -wal). Nuke them all.
        let base = url.path
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(atPath: base + suffix)
        }
    }

    private func sampleAsset(
        id: String,
        aesthetics: Double = 0.5,
        utility: Bool = false,
        faces: Int = 0,
        labels: [String] = ["generic"]
    ) -> ClassifiedAsset {
        ClassifiedAsset(
            localIdentifier: id,
            classifiedAt: Date(),
            classifierVersion: kCurrentClassifierVersion,
            metadata: Data([0x01]),
            visionAnalysis: Data([0x02]),
            featurePrint: nil,
            aestheticsScore: aesthetics,
            isUtility: utility,
            faceCount: faces,
            personCount: faces,
            topLabels: labels,
            mediaType: 1,
            mediaSubtypeRaw: 0,
            creationDate: Date(),
            latitude: 36.1699,
            longitude: -115.1398
        )
    }

    // MARK: - CRUD

    func testUpsertAndFetch() async throws {
        let (cache, url) = try makeCache()
        defer { cleanup(url) }

        let asset = sampleAsset(id: "ASSET-1")
        try await cache.upsert(asset)

        let fetched = try await cache.fetch(localIdentifier: "ASSET-1")
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.localIdentifier, "ASSET-1")
        XCTAssertEqual(fetched?.aestheticsScore, 0.5, accuracy: 0.0001)
    }

    func testUpsertUpdatesExisting() async throws {
        let (cache, url) = try makeCache()
        defer { cleanup(url) }

        try await cache.upsert(sampleAsset(id: "ASSET-1", aesthetics: 0.2))
        try await cache.upsert(sampleAsset(id: "ASSET-1", aesthetics: 0.9))

        let all = try await cache.fetchAll()
        XCTAssertEqual(all.count, 1, "upsert must not duplicate on unique localIdentifier")
        XCTAssertEqual(all.first?.aestheticsScore ?? 0, 0.9, accuracy: 0.0001)
    }

    func testBatchUpsert() async throws {
        let (cache, url) = try makeCache()
        defer { cleanup(url) }

        let batch = (0..<50).map { sampleAsset(id: "BATCH-\($0)") }
        try await cache.batchUpsert(batch)

        let all = try await cache.fetchAll()
        XCTAssertEqual(all.count, 50)
    }

    func testDelete() async throws {
        let (cache, url) = try makeCache()
        defer { cleanup(url) }

        try await cache.upsert(sampleAsset(id: "ASSET-1"))
        try await cache.delete(localIdentifier: "ASSET-1")

        let fetched = try await cache.fetch(localIdentifier: "ASSET-1")
        XCTAssertNil(fetched)
    }

    func testInvalidateOlderThan() async throws {
        let (cache, url) = try makeCache()
        defer { cleanup(url) }

        let stale = ClassifiedAsset(
            localIdentifier: "OLD-1",
            classifierVersion: 0,
            metadata: Data(),
            visionAnalysis: Data()
        )
        let fresh = sampleAsset(id: "NEW-1")
        try await cache.batchUpsert([stale, fresh])

        try await cache.invalidate(olderThan: kCurrentClassifierVersion)

        let all = try await cache.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.localIdentifier, "NEW-1")
    }

    // MARK: - Query performance

    /// Spec target: 100 assets, `isUtility == false AND aestheticsScore > 0.3`,
    /// returns in <50ms.
    func testQueryPerformanceUnder50ms() async throws {
        let (cache, url) = try makeCache()
        defer { cleanup(url) }

        // Seed 100 assets; half are utility, aesthetics varies 0.0 .. 1.0.
        var seed: [ClassifiedAsset] = []
        for i in 0..<100 {
            seed.append(
                sampleAsset(
                    id: "PERF-\(i)",
                    aesthetics: Double(i) / 100.0,
                    utility: i % 2 == 0
                )
            )
        }
        try await cache.batchUpsert(seed)

        let predicate = #Predicate<ClassifiedAsset> {
            $0.isUtility == false && $0.aestheticsScore > 0.3
        }

        // Warm up so we measure steady-state, not first-query compile.
        _ = try await cache.query(predicate: predicate)

        let start = DispatchTime.now()
        let results = try await cache.query(predicate: predicate)
        let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000.0

        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.allSatisfy { $0.isUtility == false && $0.aestheticsScore > 0.3 })
        XCTAssertLessThan(elapsedMs, 50.0, "predicate query on 100 assets should complete under 50ms (got \(elapsedMs)ms)")
    }
}
