//
//  MediaScanCoordinatorTests.swift
//  ENVITests
//
//  Phase 1 Task 6 unit tests. Exercises the coordinator with mock
//  classifier + mock library, avoiding real Photos / BackgroundTasks.
//

import XCTest
import Photos
@testable import ENVI

final class MediaScanCoordinatorTests: XCTestCase {

    // MARK: - Mocks

    /// Captures every call to `classifyBatch` so tests can assert which
    /// PHAssets got pushed through the pipeline.
    private final class MockClassifier: MediaClassifierProtocol {
        private(set) var batchCalls: [[PHAsset]] = []

        func classifyBatch(
            _ assets: [PHAsset],
            progress: ((Int, Int) -> Void)?
        ) async -> [ClassifiedAsset] {
            batchCalls.append(assets)
            progress?(assets.count, assets.count)
            return assets.map { asset in
                ClassifiedAsset(
                    localIdentifier: asset.localIdentifier,
                    metadata: Data(),
                    visionAnalysis: Data()
                )
            }
        }

        func classify(_ asset: PHAsset, priority: TaskPriority) async throws -> ClassifiedAsset {
            ClassifiedAsset(
                localIdentifier: asset.localIdentifier,
                metadata: Data(),
                visionAnalysis: Data()
            )
        }
    }

    /// Fake PHAsset that only needs to answer `localIdentifier`.
    /// PHAsset.localIdentifier is a read-only property, so we
    /// subclass and override it.
    private final class FakePHAsset: PHAsset {
        private let _id: String
        init(id: String) {
            self._id = id
            super.init()
        }
        required init() {
            self._id = UUID().uuidString
            super.init()
        }
        override var localIdentifier: String { _id }
    }

    /// Library stub — returns a preset array capped by `limit`.
    private final class MockLibrary: PHAssetProviding {
        var assets: [PHAsset] = []
        func fetchRecentMedia(limit: Int, mediaTypes: [PHAssetMediaType]) -> [PHAsset] {
            Array(assets.prefix(limit))
        }
        func totalMediaCount() -> Int { assets.count }
    }

    // MARK: - Fixtures

    private func makeCache() throws -> ClassificationCache {
        try ClassificationCache(inMemory: true)
    }

    private func makeAssets(count: Int) -> [PHAsset] {
        (0..<count).map { FakePHAsset(id: "asset-\($0)") }
    }

    // MARK: - Tests

    /// Growing the library by 5 assets should cause only those 5 to
    /// reach the classifier via `lazyRescan`.
    func testLazyRescanDetectsNewAssets() async throws {
        let cache = try makeCache()
        let classifier = MockClassifier()
        let library = MockLibrary()
        let defaults = UserDefaults(suiteName: "lazy-\(UUID().uuidString)")!

        // Seed cache with 10 already-classified assets.
        let existing = makeAssets(count: 10)
        library.assets = existing
        let seeded = existing.map {
            ClassifiedAsset(
                localIdentifier: $0.localIdentifier,
                metadata: Data(),
                visionAnalysis: Data()
            )
        }
        try await cache.batchUpsert(seeded)

        let coordinator = MediaScanCoordinator(
            classifier: classifier,
            cache: cache,
            library: library,
            defaults: defaults
        )

        // Grow the library by 5 fresh assets at the front (most recent).
        let newAssets = makeAssets(count: 5)
        library.assets = newAssets + existing

        let classified = await coordinator.lazyRescan()

        XCTAssertEqual(classified.count, 5)
        XCTAssertEqual(classifier.batchCalls.count, 1)
        XCTAssertEqual(classifier.batchCalls.first?.count, 5)
        XCTAssertEqual(
            classifier.batchCalls.first?.map { $0.localIdentifier },
            newAssets.map { $0.localIdentifier }
        )
    }

    /// Invoking `photoLibraryDidChange` should classify the inserted+updated
    /// assets via the classifier's batch API.
    func testChangeObserverTriggers() async throws {
        let cache = try makeCache()
        let classifier = MockClassifier()
        let library = MockLibrary()
        let defaults = UserDefaults(suiteName: "change-\(UUID().uuidString)")!

        let freshAssets = makeAssets(count: 3)
        library.assets = freshAssets

        let coordinator = MediaScanCoordinator(
            classifier: classifier,
            cache: cache,
            library: library,
            defaults: defaults
        )

        coordinator.photoLibraryDidChange(
            insertedCount: 2,
            removedCount: 0,
            updatedCount: 1
        )

        // Work is dispatched into a Task — wait for it to settle.
        try await waitForClassifierCall(classifier, timeout: 2.0)

        XCTAssertEqual(classifier.batchCalls.count, 1)
        XCTAssertEqual(classifier.batchCalls.first?.count, 3)
    }

    // MARK: - Helpers

    private func waitForClassifierCall(
        _ classifier: MockClassifier,
        timeout: TimeInterval
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while classifier.batchCalls.isEmpty && Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000) // 20ms
        }
        guard !classifier.batchCalls.isEmpty else {
            XCTFail("Classifier was never invoked within \(timeout)s")
            return
        }
    }
}
