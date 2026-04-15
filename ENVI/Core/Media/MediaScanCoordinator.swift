//
//  MediaScanCoordinator.swift
//  ENVI
//
//  Orchestrates the hybrid (B+C) media scan strategy for Phase 1 of the
//  Template Tab v1 feature:
//    1. Onboarding batch  — classify most recent 500 PHAssets
//    2. Background sweep  — finish the rest via BGProcessingTask
//    3. Lazy rescan       — on Template tab open, classify the delta
//    4. Incremental sync  — via PhotoLibraryManager.changeDelegate
//
//  Thermal awareness (Phase 6 Task 1 will replace this with a proper
//  ThermalAwareScheduler): before each chunk we check
//  `ProcessInfo.processInfo.thermalState`. If `.serious` or `.critical`
//  we bail cleanly so the device can cool down.
//
//  TODO(Info.plist): Add `com.envi.mediaclassifier.fullscan` to
//  `BGTaskSchedulerPermittedIdentifiers` in the app's Info.plist before
//  shipping. Without that entry iOS will refuse to register the task.
//
//  Part of Phase 1 — Media Intelligence Core (Template Tab v1).
//

import Foundation
import Photos
import Combine

// MARK: - Forward declaration bridge
//
// Task 5 (MediaClassifier) is being written in parallel. To keep this
// file parseable in isolation we depend on a protocol that the real
// `MediaClassifier` is expected to conform to. If Task 5 ships a
// concrete type with the same signatures, we adopt it by adding:
//   extension MediaClassifier: MediaClassifierProtocol {}
// in that file (or this one) — no code change here required.
public protocol MediaClassifierProtocol: AnyObject {
    func classifyBatch(
        _ assets: [PHAsset],
        progress: ((Int, Int) -> Void)?
    ) async -> [ClassifiedAsset]

    func classify(
        _ asset: PHAsset,
        priority: TaskPriority
    ) async throws -> ClassifiedAsset
}

// MARK: - PHAsset provider (testability seam)

/// Abstracts `PhotoLibraryManager.fetchRecentMedia` so tests can inject
/// a mock library without touching the Photos framework.
public protocol PHAssetProviding: AnyObject {
    func fetchRecentMedia(limit: Int, mediaTypes: [PHAssetMediaType]) -> [PHAsset]
    func totalMediaCount() -> Int
}

extension PhotoLibraryManager: PHAssetProviding {}

// MARK: - Scan progress

/// Snapshot of the coordinator's current scanning state — published for
/// the onboarding UI (Phase 5) and the Template tab loading spinner.
public struct MediaScanProgress: Equatable {
    public enum Phase: Equatable {
        case idle
        case onboarding
        case background
        case lazy
        case incremental
        case paused(reason: PauseReason)
        case completed
    }

    public enum PauseReason: Equatable {
        case thermal
        case expired
    }

    public var phase: Phase
    public var completed: Int
    public var total: Int

    public static let idle = MediaScanProgress(phase: .idle, completed: 0, total: 0)
}

// MARK: - MediaScanCoordinator

public final class MediaScanCoordinator: ObservableObject {

    // MARK: Published state

    @Published public internal(set) var progress: MediaScanProgress = .idle

    // MARK: Dependencies

    private let classifier: MediaClassifierProtocol
    private let cache: ClassificationCache
    private let library: PHAssetProviding
    private let defaults: UserDefaults

    // MARK: Tunables

    /// Size of the onboarding "quick wins" batch.
    public static let onboardingBatchSize: Int = 500

    /// Size of each background sweep chunk.
    public static let backgroundChunkSize: Int = 100

    /// BGTask identifier — must match Info.plist
    /// `BGTaskSchedulerPermittedIdentifiers`.
    public static let backgroundTaskIdentifier = "com.envi.mediaclassifier.fullscan"

    /// UserDefaults key persisting the last PHAsset.localIdentifier a
    /// background sweep has finished. Allows resuming across launches.
    public static let lastScannedIDKey = "MediaScanCoordinator.lastScannedID"

    // MARK: Init

    public init(
        classifier: MediaClassifierProtocol,
        cache: ClassificationCache,
        library: PHAssetProviding = PhotoLibraryManager.shared,
        defaults: UserDefaults = .standard
    ) {
        self.classifier = classifier
        self.cache = cache
        self.library = library
        self.defaults = defaults
    }

    // MARK: - 1. Onboarding batch

    /// Classifies the most recent `onboardingBatchSize` PHAssets.
    /// Progress is published on the main actor as each chunk completes.
    @discardableResult
    public func scanOnboardingBatch() async -> [ClassifiedAsset] {
        let assets = library.fetchRecentMedia(
            limit: Self.onboardingBatchSize,
            mediaTypes: [.image, .video]
        )
        guard !assets.isEmpty else {
            await updateProgress(.init(phase: .completed, completed: 0, total: 0))
            return []
        }

        await updateProgress(.init(phase: .onboarding, completed: 0, total: assets.count))

        let results = await classifier.classifyBatch(assets) { [weak self] done, total in
            Task { [weak self] in
                await self?.updateProgress(.init(phase: .onboarding, completed: done, total: total))
            }
        }

        await persist(results)
        if let last = results.last { recordCheckpoint(last.localIdentifier) }
        await updateProgress(.init(phase: .completed, completed: results.count, total: assets.count))
        return results
    }

    // MARK: - 3. Lazy rescan

    /// Called when the Template tab opens. Compares the photo library's
    /// live count against the cache and classifies only the new assets.
    @discardableResult
    public func lazyRescan() async -> [ClassifiedAsset] {
        let libraryCount = library.fetchRecentMedia(limit: .max, mediaTypes: [.image, .video]).count
        let cachedCount: Int
        do {
            cachedCount = try await cache.fetchAll().count
        } catch {
            cachedCount = 0
        }

        let delta = max(0, libraryCount - cachedCount)
        guard delta > 0 else {
            await updateProgress(.init(phase: .completed, completed: 0, total: 0))
            return []
        }

        let freshAssets = library
            .fetchRecentMedia(limit: delta, mediaTypes: [.image, .video])
        guard !freshAssets.isEmpty else { return [] }

        await updateProgress(.init(phase: .lazy, completed: 0, total: freshAssets.count))
        let results = await classifier.classifyBatch(freshAssets) { [weak self] done, total in
            Task { [weak self] in
                await self?.updateProgress(.init(phase: .lazy, completed: done, total: total))
            }
        }
        await persist(results)
        await updateProgress(.init(phase: .completed, completed: results.count, total: freshAssets.count))
        return results
    }

    // MARK: - 4. Change observer hook

    /// Wires this coordinator into `PhotoLibraryManager.changeDelegate`.
    /// When the library mutates, `photoLibraryDidChange` is called and
    /// we kick off an incremental classification of the new assets.
    public func registerChangeObserver(on manager: PhotoLibraryManager = .shared) {
        manager.changeDelegate = self
    }

    /// Exposed for tests and for the change observer hop.
    public func handleLibraryChange(insertedCount: Int, removedCount: Int, updatedCount: Int) {
        let affected = insertedCount + updatedCount
        guard affected > 0 else { return }
        Task { [weak self] in
            guard let self = self else { return }
            let fresh = self.library
                .fetchRecentMedia(limit: affected, mediaTypes: [.image, .video])
            guard !fresh.isEmpty else { return }
            await self.updateProgress(.init(phase: .incremental, completed: 0, total: fresh.count))
            let results = await self.classifier.classifyBatch(fresh, progress: nil)
            await self.persist(results)
            await self.updateProgress(.init(phase: .completed, completed: results.count, total: fresh.count))
        }
    }

    // MARK: - Checkpointing (used by background task extension)

    func lastScannedIdentifier() -> String? {
        defaults.string(forKey: Self.lastScannedIDKey)
    }

    func recordCheckpoint(_ identifier: String) {
        defaults.set(identifier, forKey: Self.lastScannedIDKey)
    }

    func clearCheckpoint() {
        defaults.removeObject(forKey: Self.lastScannedIDKey)
    }

    // MARK: - Thermal guard

    /// Cheap wrapper so tests can stub thermal state.
    var currentThermalState: ProcessInfo.ThermalState {
        ProcessInfo.processInfo.thermalState
    }

    /// Returns `true` when it is safe to start another chunk.
    func isThermallySafe() -> Bool {
        switch currentThermalState {
        case .nominal, .fair:
            return true
        case .serious, .critical:
            return false
        @unknown default:
            return true
        }
    }

    // MARK: - Persistence helper

    func persist(_ results: [ClassifiedAsset]) async {
        guard !results.isEmpty else { return }
        do {
            try await cache.batchUpsert(results)
        } catch {
            // Swallow — persistence failures shouldn't crash the scan.
            // Phase 6 will add a proper telemetry hook.
        }
    }

    // MARK: - State plumbing

    @MainActor
    func updateProgress(_ next: MediaScanProgress) {
        self.progress = next
    }
}

// MARK: - PhotoLibraryChangeDelegate

extension MediaScanCoordinator: PhotoLibraryChangeDelegate {
    public func photoLibraryDidChange(
        insertedCount: Int,
        removedCount: Int,
        updatedCount: Int
    ) {
        handleLibraryChange(
            insertedCount: insertedCount,
            removedCount: removedCount,
            updatedCount: updatedCount
        )
    }
}

// Note: `ClassificationCache` is an actor whose methods are already
// accessed with `await` from any external caller. We rely on that
// direct API (e.g. `try await cache.batchUpsert(results)`) rather than
// wrapping it here — overloading async shims on an actor method of the
// same name introduces ambiguous-call errors.
