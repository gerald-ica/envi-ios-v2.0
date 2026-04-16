//
//  BackgroundTaskBudget.swift
//  ENVI
//
//  Phase 6, Task 3 — background task budget + checkpoint manager.
//
//  iOS grants a `BGProcessingTask` roughly ~30 minutes of wall-clock
//  runtime before the system reclaims it. This actor tracks the budget
//  we've been handed and persists a lightweight "last processed
//  localIdentifier" checkpoint so the next task invocation can resume
//  from where the previous one left off instead of rescanning from
//  scratch.
//
//  Persistence is deliberately UserDefaults-backed — two keys, a String
//  and a Date, that survive app kills and don't need the SwiftData
//  container booted to read. This keeps the resume path hot: on the
//  next BGTask firing we can peek at the checkpoint in microseconds
//  before spinning up the classifier.
//
//  Design notes:
//    - `remaining()` returns a non-negative TimeInterval; a completed
//      or never-started budget reports 0.
//    - `shouldCheckpoint()` flips true when we have < 30 s of budget
//      left. Callers (the sweep loop) observe this between chunks and
//      both persist their position and submit a follow-up
//      `BGProcessingTaskRequest` so iOS knows we want to continue.
//    - No PII: the checkpoint is just a PHAsset.localIdentifier string,
//      which Apple considers opaque per-device. No filenames, no
//      location, no user data.
//

import Foundation

/// Actor that owns the runtime budget for the currently-executing
/// `BGProcessingTask` and the on-disk checkpoint that survives across
/// app kills.
public actor BackgroundTaskBudget {

    // MARK: - Tunables

    /// iOS default-ish runtime ceiling for a `BGProcessingTask`. The
    /// system can reclaim earlier; this is an upper-bound estimate.
    public static let defaultRuntime: TimeInterval = 30 * 60

    /// When fewer than this many seconds remain, the sweep should
    /// checkpoint + yield so iOS can cleanly transition us out.
    public static let checkpointThreshold: TimeInterval = 30

    /// UserDefaults key for the last-processed `PHAsset.localIdentifier`.
    public static let lastProcessedIDKey = "MediaScanCoordinator.lastProcessedID"

    /// UserDefaults key for the timestamp we last wrote a checkpoint.
    public static let checkpointAtKey = "MediaScanCoordinator.checkpointAt"

    // MARK: - State

    /// Absolute Date at which iOS is expected to kill the current task.
    /// `nil` when no task is being tracked.
    private var taskExpirationTime: Date?

    /// Underlying persistence — swappable for tests.
    private let defaults: UserDefaults

    /// Clock — swappable for tests so `remaining()` is deterministic.
    private let now: @Sendable () -> Date

    // MARK: - Init

    public init(
        defaults: UserDefaults = .standard,
        now: @Sendable @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.now = now
    }

    // MARK: - Budget tracking

    /// Begin tracking a `BGProcessingTask`'s expiration. Call when iOS
    /// hands you a BGTask. Subsequent calls reset the clock.
    public func begin(estimatedRuntime: TimeInterval = BackgroundTaskBudget.defaultRuntime) {
        let runtime = max(0, estimatedRuntime)
        taskExpirationTime = now().addingTimeInterval(runtime)
    }

    /// Time remaining before iOS will kill the task. Returns 0 if
    /// `begin` has not been called or the budget has elapsed.
    public func remaining() -> TimeInterval {
        guard let expiry = taskExpirationTime else { return 0 }
        return max(0, expiry.timeIntervalSince(now()))
    }

    /// True when less than ~30 seconds of budget remain. Callers should
    /// checkpoint and gracefully yield when this flips.
    public func shouldCheckpoint() -> Bool {
        guard taskExpirationTime != nil else { return false }
        return remaining() < Self.checkpointThreshold
    }

    /// Forget the current task's budget. Call from the task's
    /// expiration handler once the checkpoint has been recorded.
    public func endTracking() {
        taskExpirationTime = nil
    }

    // MARK: - Checkpoint persistence

    /// Save progress after the current chunk so the next BGTask
    /// invocation can resume from `lastProcessedID`.
    public func checkpoint(lastProcessedID: String) async {
        defaults.set(lastProcessedID, forKey: Self.lastProcessedIDKey)
        defaults.set(now(), forKey: Self.checkpointAtKey)
    }

    /// On the next BGTask invocation, fetch the resume point. Returns
    /// `nil` when there is no outstanding checkpoint.
    public func resumeFromCheckpoint() async -> String? {
        let id = defaults.string(forKey: Self.lastProcessedIDKey)
        guard let id, !id.isEmpty else { return nil }
        return id
    }

    /// Returns the `Date` we last wrote a checkpoint, if any.
    public func checkpointTimestamp() async -> Date? {
        defaults.object(forKey: Self.checkpointAtKey) as? Date
    }

    /// Clear the checkpoint when the scan completes naturally.
    public func clearCheckpoint() async {
        defaults.removeObject(forKey: Self.lastProcessedIDKey)
        defaults.removeObject(forKey: Self.checkpointAtKey)
    }
}
