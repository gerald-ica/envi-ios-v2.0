//
//  TemplateTabPerformanceTests.swift
//  ENVITests
//
//  Phase 6, Task 3 — regression suite for the Template Tab v1 pipeline.
//
//  Each test enforces an absolute wall-clock baseline (asserted with
//  XCTAssertLessThan on a measured elapsed time) so CI fails the moment
//  a future change regresses classification, embedding rebuild, or
//  template population. Measurements are taken with Date() rather than
//  XCTest's `measure { }` block because we need hard numeric thresholds,
//  not just averages-with-warnings.
//
//  Baselines (target device: iPhone 14-class, iOS 26 simulator):
//    - classifyBatch(500 synthetic photos)                 <= 120 s
//    - EmbeddingIndex.rebuild(500 classified assets)       <=   8 s
//    - TemplateMatchEngine.populateAll(20 templates, 500 assets) <= 1 s
//    - Peak RSS during 500-asset classification            <= 250 MB
//
//  Photos-auth gate: if the test host doesn't grant Photos access, tests
//  that need real PHAssets `XCTSkip` gracefully. In-memory paths
//  (embedding rebuild, match engine) use `ClassifiedAsset` fixtures and
//  run unconditionally.
//

import XCTest
import Photos
import UIKit
import SwiftData
@testable import ENVI

final class TemplateTabPerformanceTests: XCTestCase {

    // MARK: - Photos auth gate

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

    // MARK: - Synthetic fixtures

    /// Produces a tiny JPEG on disk. 32×32 solid-color is enough for Vision
    /// to produce feature prints while keeping per-asset classification
    /// extremely cheap — any meaningful performance regression in the
    /// pipeline itself will still dominate the measurement.
    private func makeTempJPEG(hue: CGFloat) throws -> URL {
        let size = CGSize(width: 32, height: 32)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor(hue: hue, saturation: 0.8, brightness: 0.8, alpha: 1).setFill()
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

    /// Seeds `count` photos into the Photos library via
    /// PHAssetCreationRequest. Returns the PHAssets that were actually
    /// created (may be fewer than `count` if ingest is rate-limited).
    private func ingestPhotos(count: Int) async throws -> [PHAsset] {
        try ensureAuthorizedOrSkip()
        var localIDs: [String] = []
        localIDs.reserveCapacity(count)

        // Write assets in batches of 25 to avoid overwhelming the Photos
        // transaction log on the simulator.
        let batchSize = 25
        var batchIndex = 0
        while batchIndex < count {
            let end = min(batchIndex + batchSize, count)
            var batchIDs: [String] = []
            try await PHPhotoLibrary.shared().performChanges {
                for i in batchIndex..<end {
                    guard let url = try? self.makeTempJPEG(
                        hue: CGFloat(i % 20) / 20.0
                    ) else { continue }
                    let req = PHAssetCreationRequest.forAsset()
                    req.addResource(
                        with: .photo,
                        fileURL: url,
                        options: PHAssetResourceCreationOptions()
                    )
                    if let id = req.placeholderForCreatedAsset?.localIdentifier {
                        batchIDs.append(id)
                    }
                }
            }
            localIDs.append(contentsOf: batchIDs)
            batchIndex = end
        }

        guard !localIDs.isEmpty else {
            throw XCTSkip("Photo library refused fixture ingest")
        }

        let fetched = PHAsset.fetchAssets(
            withLocalIdentifiers: localIDs,
            options: nil
        )
        var out: [PHAsset] = []
        out.reserveCapacity(fetched.count)
        fetched.enumerateObjects { asset, _, _ in out.append(asset) }
        return out
    }

    /// Build a `ClassifiedAsset` fixture suitable for the embedding index
    /// and match engine — includes a random 2048-dim feature print so
    /// SimilarityEngine has real vectors to normalize.
    private func makeClassifiedFixture(
        id: String,
        labels: [String],
        aesthetics: Double,
        daysAgo: Double
    ) -> ClassifiedAsset {
        // 2048-dim is the Vision feature print shape on current iOS.
        let dim = 2048
        var floats = [Float](repeating: 0, count: dim)
        for i in 0..<dim { floats[i] = Float.random(in: -1...1) }
        let fp = floats.withUnsafeBufferPointer { Data(buffer: $0) }

        let surface = AssetSurface(
            localIdentifier: id,
            mediaType: .image,
            mediaSubtypeRawValue: 0,
            mediaSubtypeFlags: MediaSubtypeFlags(phSubtypes: []),
            pixelWidth: 1080,
            pixelHeight: 1920,
            creationDate: Date().addingTimeInterval(-daysAgo * 86_400),
            modificationDate: nil,
            location: nil,
            duration: nil,
            isFavorite: false,
            burstIdentifier: nil,
            burstSelectionTypesRawValue: 0,
            hasAdjustments: false,
            playbackStyleRawValue: 0
        )
        let meta = ExtractedMetadata(
            surface: surface,
            exif: nil, gps: nil, tiff: nil, makerApple: nil, video: nil
        )
        let metaData = (try? JSONEncoder().encode(meta)) ?? Data()

        return ClassifiedAsset(
            localIdentifier: id,
            classifiedAt: Date(),
            classifierVersion: kCurrentClassifierVersion,
            metadata: metaData,
            visionAnalysis: Data(),
            featurePrint: fp,
            aestheticsScore: aesthetics,
            isUtility: false,
            faceCount: 0,
            personCount: 0,
            topLabels: labels,
            mediaType: PHAssetMediaType.image.rawValue,
            mediaSubtypeRaw: 0,
            creationDate: surface.creationDate,
            latitude: nil,
            longitude: nil
        )
    }

    /// Seed `count` `ClassifiedAsset` rows into a fresh on-disk
    /// ClassificationCache and return it alongside the URL (for cleanup).
    private func seededCache(count: Int) async throws -> (ClassificationCache, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PerformanceTests-\(UUID().uuidString).sqlite")
        let cache = try ClassificationCache(storeURL: url)
        let themes = ["food", "outfit", "travel", "indoor", "outdoor"]
        var assets: [ClassifiedAsset] = []
        assets.reserveCapacity(count)
        for i in 0..<count {
            assets.append(makeClassifiedFixture(
                id: "perf-\(i)",
                labels: [themes[i % themes.count]],
                aesthetics: Double(i % 10) / 10.0,
                daysAgo: Double(i % 90)
            ))
        }
        try await cache.batchUpsert(assets)
        return (cache, url)
    }

    private func cleanup(_ url: URL) {
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(atPath: url.path + suffix)
        }
    }

    // MARK: - RSS probe

    /// Approximate resident-set-size in MB for the current process. Used
    /// for the memory-footprint assertion. Returns nil when mach queries
    /// fail (we then skip the assertion rather than false-fail).
    private func currentResidentMB() -> Double? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size
        )
        let kr = withUnsafeMutablePointer(to: &info) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reb in
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    reb,
                    &count
                )
            }
        }
        guard kr == KERN_SUCCESS else { return nil }
        return Double(info.resident_size) / (1024 * 1024)
    }

    // MARK: - Templates for the populate test

    private func perfSlot(order: Int, label: String) -> TemplateSlot {
        TemplateSlot(
            id: UUID(),
            order: order,
            duration: 2.0,
            requirements: MediaRequirements(
                acceptedMediaTypes: [.photo],
                preferredLabels: [label],
                excludedLabels: [],
                preferredOrientation: nil,
                minimumAestheticsScore: -1.0,
                requireNonUtility: false,
                preferredFaceCount: nil,
                preferredPersonCount: nil,
                durationRange: nil,
                requireSubtypes: [],
                excludeSubtypes: [],
                recencyPreference: .any
            ),
            textOverlay: nil
        )
    }

    private func perfTemplate(name: String, labels: [String]) -> VideoTemplate {
        let slots = labels.enumerated().map { perfSlot(order: $0.offset, label: $0.element) }
        return VideoTemplate(
            id: UUID(),
            remoteID: nil,
            name: name,
            category: .lifestyle,
            aspectRatio: .portrait9x16,
            duration: Double(slots.count) * 2.0,
            slots: slots,
            textOverlays: [],
            transitions: [],
            audioTrack: nil,
            suggestedPlatforms: [],
            thumbnailURL: nil,
            popularity: 0
        )
    }

    // MARK: - Baselines

    /// Classify 500 synthetic photos in a single `classifyBatch` call.
    /// Target: completes in under 120 s on an iPhone 14-class simulator.
    func test_classifyBatch_500_completes_under_120s() async throws {
        try ensureAuthorizedOrSkip()
        let count = 500
        let assets = try await ingestPhotos(count: count)
        guard assets.count >= count / 2 else {
            throw XCTSkip("Photos ingest produced too few assets: \(assets.count)")
        }

        let cache = try ClassificationCache(inMemory: true)
        let classifier = MediaClassifier(cache: cache)

        let started = Date()
        let results = await classifier.classifyBatch(assets, progress: nil)
        let elapsed = Date().timeIntervalSince(started)

        XCTAssertGreaterThan(results.count, 0, "Classifier returned no results")
        XCTAssertLessThan(
            elapsed, 120,
            "classifyBatch(500) took \(elapsed) s — regression vs 120 s budget"
        )
    }

    /// Rebuild the embedding index against a cache of 500 classified
    /// assets (seeded directly — no Photos roundtrip).
    /// Target: under 8 s end-to-end (includes L2 norm + 2D projection +
    /// density clustering).
    func test_embeddingIndexRebuild_500_completes_under_8s() async throws {
        let (cache, url) = try await seededCache(count: 500)
        defer { cleanup(url) }

        let index = EmbeddingIndex()

        let started = Date()
        await index.rebuild(from: cache)
        let elapsed = Date().timeIntervalSince(started)

        XCTAssertLessThan(
            elapsed, 8,
            "EmbeddingIndex.rebuild(500) took \(elapsed) s — regression vs 8 s budget"
        )
    }

    /// Populate 20 templates (3 slots each) against a cache of 500
    /// classified assets. Target: under 1 s for the full populateAll pass.
    func test_templateMatchEnginePopulateAll_20templates_500assets_under_1s() async throws {
        let (cache, url) = try await seededCache(count: 500)
        defer { cleanup(url) }

        let index = EmbeddingIndex()
        await index.rebuild(from: cache)

        // 20 templates, each with 3 slots pulling from the themes pool.
        let themes = ["food", "outfit", "travel", "indoor", "outdoor"]
        var templates: [VideoTemplate] = []
        for i in 0..<20 {
            templates.append(perfTemplate(
                name: "Perf-\(i)",
                labels: [
                    themes[i % themes.count],
                    themes[(i + 1) % themes.count],
                    themes[(i + 2) % themes.count]
                ]
            ))
        }

        let engine = TemplateMatchEngine()

        let started = Date()
        let populated = await engine.populateAll(
            templates: templates,
            from: cache,
            using: index
        )
        let elapsed = Date().timeIntervalSince(started)

        XCTAssertEqual(populated.count, templates.count)
        XCTAssertLessThan(
            elapsed, 1.0,
            "populateAll(20 × 500) took \(elapsed) s — regression vs 1 s budget"
        )
    }

    /// Approximate peak memory during classification. We classify 500
    /// synthetic photos and sample RSS after the batch completes. The
    /// 250 MB ceiling is a soft-ish guard — if this ever trips, something
    /// has regressed in image decode caching.
    func test_memoryFootprint_classification_peak_under_250MB() async throws {
        try ensureAuthorizedOrSkip()

        guard let baseline = currentResidentMB() else {
            throw XCTSkip("task_info unavailable — skipping RSS assertion")
        }

        let assets = try await ingestPhotos(count: 500)
        guard assets.count >= 250 else {
            throw XCTSkip("Photos ingest produced too few assets: \(assets.count)")
        }

        let cache = try ClassificationCache(inMemory: true)
        let classifier = MediaClassifier(cache: cache)
        _ = await classifier.classifyBatch(assets, progress: nil)

        guard let peak = currentResidentMB() else {
            throw XCTSkip("task_info unavailable mid-test — skipping RSS assertion")
        }
        let delta = peak - baseline
        XCTAssertLessThan(
            delta, 250,
            "Classification RSS delta \(delta) MB > 250 MB budget (baseline \(baseline), peak \(peak))"
        )
    }
}
