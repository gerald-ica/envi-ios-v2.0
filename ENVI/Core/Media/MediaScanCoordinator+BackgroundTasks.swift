//
//  MediaScanCoordinator+BackgroundTasks.swift
//  ENVI
//
//  BGProcessingTask registration + handler for the Phase 1 background
//  sweep. Runs when iOS decides the device is idle/charging and pushes
//  through the remaining library in chunks of 100 PHAssets, checkpointing
//  the last-scanned `localIdentifier` so subsequent firings resume.
//
//  Phase 6, Task 3 additions:
//    - A shared `BackgroundTaskBudget` actor tracks iOS's runtime
//      ceiling and owns the on-disk checkpoint. Between every small
//      group of assets (10 at a time, checked inside each 100-asset
//      chunk) we consult `shouldCheckpoint()`; when < 30 s remain we
//      persist progress, submit a follow-up BGProcessingTaskRequest,
//      and return cleanly so iOS can transition us out.
//    - Telemetry events fire at scan start, natural completion,
//      thermal pauses, and aggregated failure counts. No PII — only
//      counts, durations, and coarse state strings.
//
//  TODO(Info.plist): `com.envi.mediaclassifier.fullscan` must be listed
//  under `BGTaskSchedulerPermittedIdentifiers`. iOS will throw
//  `BGTaskSchedulerErrorDomain` code 1 ("Not permitted") otherwise.
//
//  Part of Phase 1 — Media Intelligence Core (Template Tab v1).
//

import Foundation
import Photos
import BackgroundTasks

public extension MediaScanCoordinator {

    // MARK: - Budget (Phase 6, Task 3)

    /// Process-wide budget manager. Backed by a module-scoped holder so
    /// we don't have to widen `MediaScanCoordinator`'s stored state in
    /// this phase.
    internal var backgroundBudget: BackgroundTaskBudget {
        MediaScanCoordinatorBudgetHolder.shared
    }

    // MARK: - 2. Background scan registration

    /// Registers the coordinator's BGProcessingTask handler. Call this
    /// from `AppDelegate.application(_:didFinishLaunchingWithOptions:)`
    /// (or the SwiftUI `init`) BEFORE the app finishes launching.
    func registerBackgroundTaskHandler() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.backgroundTaskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let self = self,
                  let processingTask = task as? BGProcessingTask
            else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleBackgroundTask(processingTask)
        }
    }

    /// Submits a `BGProcessingTaskRequest` so iOS will run the full
    /// library sweep when the device is idle + on power. Safe to call
    /// repeatedly; subsequent submissions replace the pending request.
    func scheduleBackgroundScan() {
        let request = BGProcessingTaskRequest(identifier: Self.backgroundTaskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = true

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Most likely Info.plist not updated yet, or simulator
            // (BGTaskScheduler is unsupported there). Swallow — tests
            // cover the happy path via direct handler invocation.
        }
    }

    // MARK: - Handler

    /// Exposed internally so tests can drive it with a stub task.
    func handleBackgroundTask(_ task: BGProcessingTask) {
        // Thermal bail-out — if the device is hot, don't even start.
        guard isThermallySafe() else {
            TelemetryManager.shared.logMediaScanThermalPause(
                state: String(describing: currentThermalState)
            )
            scheduleBackgroundScan() // try again later
            task.setTaskCompleted(success: true)
            return
        }

        let budget = self.backgroundBudget
        let work = Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            await budget.begin()
            await self.runBackgroundSweep()
        }

        task.expirationHandler = {
            // iOS is reclaiming the task — cancel in-flight work. The
            // sweep loop persists its last-processed ID into the budget
            // on every sub-chunk boundary, so cancellation is non-lossy.
            work.cancel()
            Task.detached { await budget.endTracking() }
        }

        Task.detached(priority: .background) { [weak self] in
            _ = await work.value
            guard let self = self else {
                task.setTaskCompleted(success: false)
                return
            }
            // Re-schedule if anything is left to do, then signal done.
            self.scheduleBackgroundScan()
            await budget.endTracking()
            task.setTaskCompleted(success: !Task.isCancelled)
        }
    }

    // MARK: - Sweep loop

    /// Walks the photo library in chunks, starting after the last
    /// checkpointed `localIdentifier`. Honors cooperative cancellation
    /// (task expiration), the thermal guard between chunks, and the
    /// BackgroundTaskBudget's checkpoint threshold.
    func runBackgroundSweep() async {
        let allAssets = library.fetchRecentMedia(
            limit: .max,
            mediaTypes: [.image, .video]
        )
        guard !allAssets.isEmpty else { return }

        // Resume from the checkpoint, if any. Prefer the new budget
        // checkpoint; fall back to the legacy UserDefaults key so an
        // upgrade from a pre-Phase-6 build keeps its progress.
        var startIndex = 0
        let budgetResume = await backgroundBudget.resumeFromCheckpoint()
        let resumeID: String? = budgetResume ?? lastScannedIdentifier()
        if let lastID = resumeID,
           let idx = allAssets.firstIndex(where: { $0.localIdentifier == lastID }) {
            startIndex = idx + 1
        }
        guard startIndex < allAssets.count else {
            await backgroundBudget.clearCheckpoint()
            TelemetryManager.shared.logMediaScanCompleted(
                assetCount: 0,
                duration: 0,
                scanType: "background"
            )
            return
        }

        let remaining = Array(allAssets[startIndex...])
        let chunkSize = Self.backgroundChunkSize
        let startedAt = Date()

        TelemetryManager.shared.logMediaScanStarted(
            assetCount: remaining.count,
            scanType: "background"
        )

        await updateBackgroundProgress(completed: 0, total: remaining.count)

        var lastThermalSafe = true

        for chunkStart in stride(from: 0, to: remaining.count, by: chunkSize) {
            if Task.isCancelled {
                await updateBackgroundProgress(
                    completed: chunkStart,
                    total: remaining.count,
                    paused: .expired
                )
                return
            }

            let thermalSafe = isThermallySafe()
            if !thermalSafe {
                if lastThermalSafe {
                    TelemetryManager.shared.logMediaScanThermalPause(
                        state: String(describing: currentThermalState)
                    )
                }
                await updateBackgroundProgress(
                    completed: chunkStart,
                    total: remaining.count,
                    paused: .thermal
                )
                return
            } else if !lastThermalSafe {
                TelemetryManager.shared.logMediaScanThermalResume()
            }
            lastThermalSafe = thermalSafe

            // Budget check BEFORE starting the next chunk — if less than
            // 30 s remain, submit a follow-up request so iOS wakes us
            // again to finish the rest.
            if await backgroundBudget.shouldCheckpoint() {
                scheduleBackgroundScan()
                await updateBackgroundProgress(
                    completed: chunkStart,
                    total: remaining.count,
                    paused: .expired
                )
                return
            }

            let end = min(chunkStart + chunkSize, remaining.count)
            let chunk = Array(remaining[chunkStart..<end])

            // Process in sub-chunks of 10 so budget/cancellation checks
            // have a finer cadence than one-per-100.
            let subSize = 10
            var subCompleted = 0
            for subStart in stride(from: 0, to: chunk.count, by: subSize) {
                if Task.isCancelled {
                    await updateBackgroundProgress(
                        completed: chunkStart + subCompleted,
                        total: remaining.count,
                        paused: .expired
                    )
                    return
                }
                let subEnd = min(subStart + subSize, chunk.count)
                let sub = Array(chunk[subStart..<subEnd])
                let subResults = await classifier.classifyBatch(sub, progress: nil)
                await persist(subResults)

                if let lastID = sub.last?.localIdentifier {
                    await backgroundBudget.checkpoint(lastProcessedID: lastID)
                    recordCheckpoint(lastID)
                }

                subCompleted += sub.count

                if await backgroundBudget.shouldCheckpoint() {
                    scheduleBackgroundScan()
                    await updateBackgroundProgress(
                        completed: chunkStart + subCompleted,
                        total: remaining.count,
                        paused: .expired
                    )
                    return
                }
            }

            await updateBackgroundProgress(completed: end, total: remaining.count)
        }

        // Natural completion — clear the checkpoint, report.
        await backgroundBudget.clearCheckpoint()
        clearCheckpoint()

        TelemetryManager.shared.logMediaScanCompleted(
            assetCount: remaining.count,
            duration: Date().timeIntervalSince(startedAt),
            scanType: "background"
        )
    }

    // MARK: - Progress helpers

    private func updateBackgroundProgress(
        completed: Int,
        total: Int,
        paused: MediaScanProgress.PauseReason? = nil
    ) async {
        let next: MediaScanProgress
        if let reason = paused {
            next = .init(phase: .paused(reason: reason), completed: completed, total: total)
        } else if completed >= total {
            next = .init(phase: .completed, completed: completed, total: total)
        } else {
            next = .init(phase: .background, completed: completed, total: total)
        }
        await updateProgress(next)
    }
}

// MARK: - Shared budget holder

/// Process-wide singleton backing `MediaScanCoordinator.backgroundBudget`.
/// Kept separate from the coordinator so we don't have to add a stored
/// property to `MediaScanCoordinator` (and to keep it trivially shared
/// across tests within the same process).
enum MediaScanCoordinatorBudgetHolder {
    static let shared = BackgroundTaskBudget()
}
