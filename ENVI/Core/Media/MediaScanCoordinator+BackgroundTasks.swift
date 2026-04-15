//
//  MediaScanCoordinator+BackgroundTasks.swift
//  ENVI
//
//  BGProcessingTask registration + handler for the Phase 1 background
//  sweep. Runs when iOS decides the device is idle/charging and pushes
//  through the remaining library in chunks of 100 PHAssets, checkpointing
//  the last-scanned `localIdentifier` so subsequent firings resume.
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
            scheduleBackgroundScan() // try again later
            task.setTaskCompleted(success: true)
            return
        }

        let work = Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            await self.runBackgroundSweep()
        }

        task.expirationHandler = {
            // iOS is reclaiming the task — cancel in-flight work and
            // re-schedule so we pick up at the next checkpoint.
            work.cancel()
        }

        Task.detached(priority: .background) { [weak self] in
            _ = await work.value
            guard let self = self else {
                task.setTaskCompleted(success: false)
                return
            }
            // Re-schedule if anything is left to do, then signal done.
            self.scheduleBackgroundScan()
            task.setTaskCompleted(success: !Task.isCancelled)
        }
    }

    // MARK: - Sweep loop

    /// Walks the photo library in chunks, starting after the last
    /// checkpointed `localIdentifier`. Honors cooperative cancellation
    /// (task expiration) and the thermal guard between chunks.
    func runBackgroundSweep() async {
        let allAssets = library.fetchRecentMedia(
            limit: .max,
            mediaTypes: [.image, .video]
        )
        guard !allAssets.isEmpty else { return }

        // Resume from the checkpoint, if any.
        var startIndex = 0
        if let lastID = lastScannedIdentifier(),
           let idx = allAssets.firstIndex(where: { $0.localIdentifier == lastID }) {
            startIndex = idx + 1
        }
        guard startIndex < allAssets.count else { return }

        let remaining = Array(allAssets[startIndex...])
        let chunkSize = Self.backgroundChunkSize

        await updateBackgroundProgress(completed: 0, total: remaining.count)

        for chunkStart in stride(from: 0, to: remaining.count, by: chunkSize) {
            if Task.isCancelled {
                await updateBackgroundProgress(
                    completed: chunkStart,
                    total: remaining.count,
                    paused: .expired
                )
                return
            }
            guard isThermallySafe() else {
                await updateBackgroundProgress(
                    completed: chunkStart,
                    total: remaining.count,
                    paused: .thermal
                )
                return
            }

            let end = min(chunkStart + chunkSize, remaining.count)
            let chunk = Array(remaining[chunkStart..<end])
            let results = await classifier.classifyBatch(chunk, progress: nil)
            await persist(results)

            if let last = chunk.last {
                recordCheckpoint(last.localIdentifier)
            }

            await updateBackgroundProgress(completed: end, total: remaining.count)
        }
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
