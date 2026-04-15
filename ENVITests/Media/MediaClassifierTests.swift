//
//  MediaClassifierTests.swift
//  ENVITests
//
//  Integration test for the unified MediaClassifier pipeline (Phase 1,
//  Task 5 of Template Tab v1). Synthesizes 3 PHAssets via
//  PHAssetCreationRequest, classifies all of them, and asserts that a
//  second run returns the same records via the cache (no re-processing).
//

import XCTest
import Photos
import UIKit
import AVFoundation
@testable import ENVI

final class MediaClassifierTests: XCTestCase {

    // MARK: - Authorization

    private func ensureAuthorizedOrSkip() throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            return
        case .notDetermined:
            let granted = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            if granted == .authorized || granted == .limited { return }
            throw XCTSkip("Photos authorization not granted in test environment")
        default:
            throw XCTSkip("Photos authorization denied in test environment")
        }
    }

    // MARK: - Fixture builders

    private func makeTempJPEG(size: CGSize = CGSize(width: 64, height: 64)) throws -> URL {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.systemPink.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw XCTSkip("Unable to render JPEG fixture")
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        try data.write(to: url)
        return url
    }

    private func ingestPhoto() async throws -> PHAsset {
        try ensureAuthorizedOrSkip()
        let url = try makeTempJPEG()
        var placeholder: PHObjectPlaceholder?
        try await PHPhotoLibrary.shared().performChanges {
            let req = PHAssetCreationRequest.forAsset()
            req.addResource(with: .photo, fileURL: url, options: PHAssetResourceCreationOptions())
            placeholder = req.placeholderForCreatedAsset
        }
        guard let id = placeholder?.localIdentifier else {
            throw XCTSkip("Photo library refused fixture ingest")
        }
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else {
            throw XCTSkip("Ingested fixture not found after write")
        }
        return asset
    }

    // MARK: - Helpers

    /// Builds a MediaClassifier backed by an in-memory cache so tests don't
    /// pollute the on-disk Application Support store.
    private func makeClassifier() throws -> MediaClassifier {
        let cache = try ClassificationCache(inMemory: true)
        return MediaClassifier(cache: cache)
    }

    // MARK: - Tests

    /// Ingest 3 synthetic photo assets, classify the batch, and confirm that
    /// a second batch call is a pure cache hit (no duplicates written,
    /// same records returned).
    func testClassifyBatchSucceeds() async throws {
        let classifier = try makeClassifier()

        // Ingest 3 fresh assets.
        var assets: [PHAsset] = []
        for _ in 0..<3 {
            assets.append(try await ingestPhoto())
        }

        // First pass — should classify all three.
        let first = await classifier.classifyBatch(assets, progress: nil)
        XCTAssertEqual(first.count, 3, "expected all three assets to classify on first pass")

        // Verify each asset has the expected shape.
        for record in first {
            XCTAssertEqual(record.classifierVersion, kCurrentClassifierVersion)
            XCTAssertFalse(record.metadata.isEmpty, "metadata blob should be non-empty")
            XCTAssertFalse(record.visionAnalysis.isEmpty, "vision blob should be non-empty")
        }

        // Second pass — should be a cache hit for every asset. Capture the
        // classifiedAt dates and confirm they're unchanged.
        let firstDates = Dictionary(uniqueKeysWithValues: first.map { ($0.localIdentifier, $0.classifiedAt) })
        let second = await classifier.classifyBatch(assets, progress: nil)
        XCTAssertEqual(second.count, 3, "cache-hit pass should also return 3 records")
        for record in second {
            let previous = try XCTUnwrap(firstDates[record.localIdentifier])
            XCTAssertEqual(
                record.classifiedAt.timeIntervalSinceReferenceDate,
                previous.timeIntervalSinceReferenceDate,
                accuracy: 0.001,
                "cache hit should not rewrite classifiedAt"
            )
        }

        // No failures expected on the happy path.
        let failures = await classifier.failures
        XCTAssertTrue(failures.isEmpty, "no per-asset failures expected; got: \(failures)")
    }

    /// Progress callback should fire at final completion even when the batch
    /// is small enough that no intermediate "every 10" tick happens.
    func testClassifyBatchReportsFinalProgress() async throws {
        let classifier = try makeClassifier()

        var assets: [PHAsset] = []
        for _ in 0..<3 {
            assets.append(try await ingestPhoto())
        }

        actor Reporter {
            var last: (Int, Int)?
            func record(_ done: Int, _ total: Int) { last = (done, total) }
        }
        let reporter = Reporter()
        _ = await classifier.classifyBatch(assets) { done, total in
            Task { await reporter.record(done, total) }
        }
        // Give the detached reporter tasks a moment to drain.
        try? await Task.sleep(nanoseconds: 50_000_000)
        let last = await reporter.last
        XCTAssertEqual(last?.1, 3, "progress should report total=3")
    }
}
