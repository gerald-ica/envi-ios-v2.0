//
//  MediaClassifier.swift
//  ENVI
//
//  Unified pipeline that orchestrates Tasks 1-4 of the Media Intelligence
//  Core (Phase 1, Template Tab v1) into a single entry point.
//
//  Flow per asset:
//    1. Check ClassificationCache.fetch(localIdentifier:) — return if fresh
//       (classifierVersion matches kCurrentClassifierVersion).
//    2. Run MediaMetadataExtractor.extract(asset) (cheap, always).
//    3. Request image data via PHImageManager → VisionAnalysisEngine.analyze().
//       For videos, write the video URL to a temp path and call analyzeVideo.
//    4. If location present, enqueue ReverseGeocodeCache.shared.place(for:)
//       best-effort and non-blocking (fire-and-forget detached Task).
//    5. Compose a ClassifiedAsset, upsert into the cache, return.
//
//  Batch: TaskGroup with max concurrency = activeProcessorCount, reports
//  progress every 10 items. Per-asset failures are logged to the actor's
//  `failures: [UUID: Error]` side-channel and skipped — the batch never
//  throws.
//
//  Design notes:
//    - Not @MainActor. Actor isolation keeps all Vision/Photos work off
//      the main thread.
//    - Dependencies are injected for testability; `shared` default wires
//      the production cache + engines.
//    - JSON-encodes ExtractedMetadata / VisionAnalysis into the
//      ClassifiedAsset @Model's Data blobs per Task 3's schema.
//

import Foundation
import Photos
import CoreLocation
import ImageIO
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Errors

public enum MediaClassifierError: Error {
    case imageDataUnavailable
    case videoURLUnavailable
    case encodingFailed(Error)
    case cacheFailure(Error)
}

// MARK: - MediaClassifier

actor MediaClassifier {

    // MARK: Dependencies

    /// Exposed so the ForYou pipeline can query classified assets directly.
    let cache: ClassificationCache
    private let visionEngine: VisionAnalysisEngine
    private let geocodeCache: ReverseGeocodeCache
    private let imageManager: PHImageManager
    private let classifierVersion: Int

    /// Per-asset failures surfaced via actor-isolated side channel so that
    /// batch callers can post-inspect what went wrong without the batch
    /// itself throwing.
    public private(set) var failures: [String: Error] = [:]

    // MARK: Init

    init(
        cache: ClassificationCache,
        visionEngine: VisionAnalysisEngine = .shared,
        geocodeCache: ReverseGeocodeCache = .shared,
        imageManager: PHImageManager = .default(),
        classifierVersion: Int = kCurrentClassifierVersion
    ) {
        self.cache = cache
        self.visionEngine = visionEngine
        self.geocodeCache = geocodeCache
        self.imageManager = imageManager
        self.classifierVersion = classifierVersion
    }

    /// Default production instance. Uses the shared on-disk cache.
    public static let shared: MediaClassifier = {
        // Fall back to in-memory if the on-disk cache can't be built —
        // the app should not crash at import time because of a missing
        // Application Support directory.
        if let onDisk = try? ClassificationCache() {
            return MediaClassifier(cache: onDisk)
        }
        // swiftlint:disable:next force_try
        let fallback = try! ClassificationCache(inMemory: true)
        return MediaClassifier(cache: fallback)
    }()

    // MARK: - Public API

    /// Classifies a single PHAsset, returning a cache hit if fresh.
    /// `priority` is advisory — it's applied to the downstream Vision
    /// TaskGroup via `Task.detached(priority:)` when this is called inside
    /// a batch.
    nonisolated func classify(_ asset: PHAsset, priority: TaskPriority = .medium) async throws -> ClassifiedAsset {
        try await withCheckedThrowingContinuation { continuation in
            Task { [self] in
                await self.classifyAndResume(asset, priority: priority, continuation: continuation)
            }
        }
    }

    /// Re-classifies an asset if the cached entry is stale (version mismatch)
    /// or missing. Returns the fresh entry either way.
    nonisolated func rescanIfStale(_ asset: PHAsset) async throws -> ClassifiedAsset {
        try await withCheckedThrowingContinuation { continuation in
            Task { [self] in
                await self.rescanAndResume(asset, continuation: continuation)
            }
        }
    }

    /// Classifies a batch in parallel with a cap on concurrent tasks.
    /// Failures are stashed on `failures` and absent from the returned
    /// array — the batch never throws.
    nonisolated func classifyBatch(
        _ assets: [PHAsset],
        progress: ((Int, Int) -> Void)? = nil
    ) async -> [ClassifiedAsset] {
        guard !assets.isEmpty else { return [] }

        let total = assets.count
        let scheduler = ThermalAwareScheduler.shared
        await scheduler.beginObserving()

        let accumulator = ClassifiedAssetAccumulator(capacity: total)
        var completed = 0

        // Process the batch in thermal-aware chunks. Before each chunk we
        // await the scheduler's work slot (blocks on .none) and then ask
        // for the chunk size that matches the current budget.
        var cursor = 0
        while cursor < total {
            await scheduler.waitForWorkSlot()
            let chunkSize = max(1, await scheduler.batchSize(for: .classifyBatch))
            let end = min(cursor + chunkSize, total)
            let chunk = Array(assets[cursor..<end])
            cursor = end

            let maxConcurrent = max(1, min(chunk.count, ProcessInfo.processInfo.activeProcessorCount))
            await withTaskGroup(of: Void.self) { group in
                var index = 0
                // Seed up to maxConcurrent tasks.
                while index < min(maxConcurrent, chunk.count) {
                    let asset = chunk[index]
                    group.addTask { [weak self] in
                        guard let self else {
                            return
                        }
                        do {
                            let result = try await self.classify(asset, priority: .medium)
                            accumulator.append(result)
                        } catch {
                            await self.recordFailure(localIdentifier: asset.localIdentifier, error: error)
                        }
                    }
                    index += 1
                }

                while await group.next() != nil {
                    completed += 1
                    if progress != nil, (completed % 10 == 0 || completed == total) {
                        progress?(completed, total)
                    }

                    // Schedule next asset from the current chunk.
                    if index < chunk.count {
                        let next = chunk[index]
                        index += 1
                        group.addTask { [weak self] in
                            guard let self else {
                                return
                            }
                            do {
                                let result = try await self.classify(next, priority: .medium)
                                accumulator.append(result)
                            } catch {
                                await self.recordFailure(localIdentifier: next.localIdentifier, error: error)
                            }
                        }
                    }
                }
            }
        }

        return accumulator.snapshot()
    }

    /// Clears the in-memory failure log (test hook / caller-controlled reset).
    func resetFailures() {
        failures.removeAll()
    }

    private func recordFailure(localIdentifier: String, error: Error) {
        failures[localIdentifier] = error
    }

    private func classifyAndResume(
        _ asset: PHAsset,
        priority: TaskPriority,
        continuation: CheckedContinuation<ClassifiedAsset, Error>
    ) async {
        do {
            _ = priority // retained in signature for API stability / future use
            if let fresh = try await fetchFreshIfAny(for: asset.localIdentifier) {
                continuation.resume(returning: fresh)
                return
            }
            continuation.resume(returning: try await classifyUncached(asset))
        } catch {
            continuation.resume(throwing: error)
        }
    }

    private func rescanAndResume(
        _ asset: PHAsset,
        continuation: CheckedContinuation<ClassifiedAsset, Error>
    ) async {
        do {
            if let fresh = try await fetchFreshIfAny(for: asset.localIdentifier) {
                continuation.resume(returning: fresh)
                return
            }
            continuation.resume(returning: try await classifyUncached(asset))
        } catch {
            continuation.resume(throwing: error)
        }
    }

    // MARK: - Core pipeline

    private func fetchFreshIfAny(for localIdentifier: String) async throws -> ClassifiedAsset? {
        do {
            guard let cached = try await cache.fetch(localIdentifier: localIdentifier) else {
                return nil
            }
            return cached.classifierVersion == classifierVersion ? cached : nil
        } catch {
            throw MediaClassifierError.cacheFailure(error)
        }
    }

    private func classifyUncached(_ asset: PHAsset) async throws -> ClassifiedAsset {
        // 1. Metadata — always cheap.
        let metadata = await MediaMetadataExtractor.extract(asset)

        // 2. Vision — image or video path.
        var vision = VisionAnalysis()
        do {
            vision = try await runVision(for: asset)
        } catch {
            // Vision failure is not fatal — we still persist the metadata row
            // so future queries see the asset at all. Record the failure.
            failures[asset.localIdentifier] = error
        }

        // 3. Location — fire-and-forget reverse geocode (best effort).
        if let loc = metadata.surface.location {
            let coordinate = CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude)
            let altitude = loc.altitude ?? 0
            let horizontalAccuracy = loc.horizontalAccuracy ?? -1
            let verticalAccuracy = loc.verticalAccuracy ?? -1
            let timestamp = loc.timestamp ?? Date()
            let geocoder = geocodeCache
            Task.detached(priority: .background) { [coordinate, altitude, horizontalAccuracy, verticalAccuracy, timestamp, geocoder] in
                let clLocation = CLLocation(
                    coordinate: coordinate,
                    altitude: altitude,
                    horizontalAccuracy: horizontalAccuracy,
                    verticalAccuracy: verticalAccuracy,
                    timestamp: timestamp
                )
                _ = await geocoder.place(for: clLocation)
            }
        }

        // 4. Compose ClassifiedAsset.
        let record = try compose(asset: asset, metadata: metadata, vision: vision)

        // 5. Persist.
        do {
            try await cache.upsert(record)
        } catch {
            throw MediaClassifierError.cacheFailure(error)
        }

        return record
    }

    // MARK: - Vision dispatch

    private func runVision(for asset: PHAsset) async throws -> VisionAnalysis {
        switch asset.mediaType {
        case .image:
            let (data, orientation) = try await requestImageData(for: asset)
            return try await visionEngine.analyzeImage(data: data, orientation: orientation)
        case .video:
            let url = try await requestVideoURL(for: asset)
            return try await visionEngine.analyzeVideo(at: url)
        default:
            // Unknown / audio — return an empty analysis so the record still persists.
            return VisionAnalysis()
        }
    }

    private func requestImageData(for asset: PHAsset) async throws -> (Data, CGImagePropertyOrientation) {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Data, CGImagePropertyOrientation), Error>) in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.version = .current
            options.isSynchronous = false

            imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, _, orientation, _ in
                if let data = data {
                    continuation.resume(returning: (data, orientation))
                } else {
                    continuation.resume(throwing: MediaClassifierError.imageDataUnavailable)
                }
            }
        }
    }

    private func requestVideoURL(for asset: PHAsset) async throws -> URL {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.version = .current

            imageManager.requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                if let urlAsset = avAsset as? AVURLAsset {
                    continuation.resume(returning: urlAsset.url)
                } else {
                    continuation.resume(throwing: MediaClassifierError.videoURLUnavailable)
                }
            }
        }
    }

    // MARK: - Composition

    private func compose(
        asset: PHAsset,
        metadata: ExtractedMetadata,
        vision: VisionAnalysis
    ) throws -> ClassifiedAsset {
        let encoder = JSONEncoder()
        let metadataData: Data
        let visionData: Data
        do {
            metadataData = try encoder.encode(metadata)
            visionData = try encoder.encode(vision)
        } catch {
            throw MediaClassifierError.encodingFailed(error)
        }

        let topLabels = vision.classifications.map { $0.identifier }

        let loc = metadata.surface.location
        return ClassifiedAsset(
            localIdentifier: asset.localIdentifier,
            classifiedAt: Date(),
            classifierVersion: classifierVersion,
            metadata: metadataData,
            visionAnalysis: visionData,
            featurePrint: vision.featurePrintData,
            aestheticsScore: Double(vision.aestheticsScore ?? 0),
            isUtility: vision.isUtility ?? false,
            faceCount: vision.faceCount,
            personCount: vision.personCount,
            topLabels: topLabels,
            mediaType: metadata.surface.mediaType.rawValue,
            mediaSubtypeRaw: metadata.surface.mediaSubtypeRawValue,
            creationDate: metadata.surface.creationDate,
            latitude: loc?.latitude,
            longitude: loc?.longitude
        )
    }
}

private final class ClassifiedAssetAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [ClassifiedAsset]

    init(capacity: Int) {
        self.storage = []
        storage.reserveCapacity(capacity)
    }

    func append(_ asset: ClassifiedAsset) {
        lock.lock()
        storage.append(asset)
        lock.unlock()
    }

    func snapshot() -> [ClassifiedAsset] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}


// MARK: - Protocol Conformance
// Bridges Task 5's concrete MediaClassifier to Task 6's MediaScanCoordinator
// protocol dependency. Both signatures already match.
extension MediaClassifier: MediaClassifierProtocol {}
