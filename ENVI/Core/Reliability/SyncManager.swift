import Foundation
import Combine

// MARK: - Sync Manager

/// Manages synchronization state, offline queue, conflict detection, and retry logic.
@MainActor
final class SyncManager: ObservableObject {

    // MARK: - Published State

    @Published private(set) var syncStatus: SyncStatus = SyncStatus()
    @Published private(set) var offlineDrafts: [OfflineDraft] = []
    @Published private(set) var performanceMetrics: [PerformanceMetric] = []
    @Published private(set) var cachePolicy: CachePolicy = CachePolicy()
    @Published private(set) var isSyncing: Bool = false

    // MARK: - Private

    private var retryCount: Int = 0
    private let maxRetries: Int = 3
    private let retryDelay: TimeInterval = 2.0

    // MARK: - Singleton

    static let shared = SyncManager()

    private init() {}

    // MARK: - Sync Operations

    /// Trigger a full synchronization pass.
    func sync() async {
        guard !isSyncing else { return }
        isSyncing = true
        retryCount = 0

        do {
            try await performSync()
            syncStatus = SyncStatus(
                lastSync: Date(),
                pendingChanges: 0,
                conflicts: syncStatus.conflicts.filter { !$0.isResolved }
            )
        } catch {
            await retryIfNeeded()
        }

        isSyncing = false
    }

    /// Force sync with retry reset.
    func forceSync() async {
        retryCount = 0
        await sync()
    }

    // MARK: - Offline Queue

    /// Enqueue a draft for later sync.
    func enqueueDraft(_ draft: OfflineDraft) {
        offlineDrafts.append(draft)
        syncStatus = SyncStatus(
            lastSync: syncStatus.lastSync,
            pendingChanges: syncStatus.pendingChanges + 1,
            conflicts: syncStatus.conflicts
        )
    }

    /// Remove a draft from the offline queue.
    func removeDraft(id: UUID) {
        offlineDrafts.removeAll { $0.id == id }
    }

    /// Retry syncing a single failed draft.
    func retryDraft(id: UUID) async {
        guard let index = offlineDrafts.firstIndex(where: { $0.id == id }) else { return }
        offlineDrafts[index].syncStatus = .uploading

        // Simulate upload
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        offlineDrafts[index].syncStatus = .synced
    }

    // MARK: - Conflict Detection

    /// Detect conflicts between local and remote data.
    func detectConflicts() async -> [SyncConflict] {
        // In production this would compare local vs remote timestamps.
        // Returns current unresolved conflicts for now.
        syncStatus.conflicts.filter { !$0.isResolved }
    }

    /// Resolve a specific conflict.
    func resolveConflict(id: UUID, resolution: SyncConflict.Resolution) {
        let updatedConflicts = syncStatus.conflicts.map { conflict -> SyncConflict in
            guard conflict.id == id else { return conflict }
            var resolved = conflict
            resolved.resolution = resolution
            return resolved
        }
        syncStatus = SyncStatus(
            lastSync: syncStatus.lastSync,
            pendingChanges: syncStatus.pendingChanges,
            conflicts: updatedConflicts
        )
    }

    // MARK: - Performance

    /// Load current performance metrics.
    func loadPerformanceMetrics() async {
        performanceMetrics = PerformanceMetric.mock
    }

    /// Update cache policy settings.
    func updateCachePolicy(_ policy: CachePolicy) {
        cachePolicy = policy
    }

    // MARK: - Load Mock Data

    /// Load mock data for development.
    func loadMockData() {
        syncStatus = .mock
        offlineDrafts = OfflineDraft.mock
        performanceMetrics = PerformanceMetric.mock
    }

    // MARK: - Private Helpers

    private func performSync() async throws {
        // Simulate network sync
        try await Task.sleep(nanoseconds: 1_500_000_000)

        // Process pending drafts
        for index in offlineDrafts.indices where offlineDrafts[index].syncStatus == .pending {
            offlineDrafts[index].syncStatus = .uploading
            try await Task.sleep(nanoseconds: 500_000_000)
            offlineDrafts[index].syncStatus = .synced
        }
    }

    private func retryIfNeeded() async {
        guard retryCount < maxRetries else {
            syncStatus = SyncStatus(
                lastSync: syncStatus.lastSync,
                pendingChanges: syncStatus.pendingChanges,
                conflicts: syncStatus.conflicts
            )
            return
        }
        retryCount += 1
        try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
        await sync()
    }
}
