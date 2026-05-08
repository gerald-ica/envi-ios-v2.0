//
//  PhotoLibraryManager+MediaScan.swift
//  ENVI
//
//  Additive extension that exposes the Phase 1 MediaScanCoordinator off
//  the existing `PhotoLibraryManager.shared` singleton. We deliberately
//  do NOT modify PhotoLibraryManager.swift — Task 5 owns its own sweep
//  pipeline, so this hook is the only surface we add.
//
//  Wiring note: the coordinator is lazily constructed the first time it
//  is requested. Construction requires Task 5's `MediaClassifier`, so
//  callers must provide a factory via `configureScanCoordinator(_:)`
//  during app launch. Until Task 5 ships, tests build the coordinator
//  themselves and never touch this property.
//
//  TODO(Info.plist): remember to add `com.envi.mediaclassifier.fullscan`
//  to `BGTaskSchedulerPermittedIdentifiers`.
//
//  Part of Phase 1 — Media Intelligence Core (Template Tab v1).
//

import Foundation
import Photos

extension PhotoLibraryManager {

    // MARK: - Shared coordinator storage

    /// Internal box so we can stash a reference on the singleton without
    /// adding a stored property to the original class.
    private final class CoordinatorBox {
        var coordinator: MediaScanCoordinator?
    }

    private nonisolated(unsafe) static let coordinatorBox = CoordinatorBox()

    /// Lazily-built coordinator. Returns `nil` until
    /// `configureScanCoordinator(_:)` has been called, so the call site
    /// stays explicit about when the scan engine is live.
    public static var scanCoordinator: MediaScanCoordinator? {
        coordinatorBox.coordinator
    }

    /// Installs a `MediaScanCoordinator` onto the shared manager and
    /// hooks up the change delegate so library mutations flow through
    /// incremental classification.
    ///
    /// Call from `AppDelegate` once the MediaClassifier (Task 5) has
    /// been built. Safe to call more than once — the last coordinator
    /// wins and becomes the new change delegate.
    @discardableResult
    public static func configureScanCoordinator(
        _ coordinator: MediaScanCoordinator
    ) -> MediaScanCoordinator {
        coordinatorBox.coordinator = coordinator
        coordinator.registerChangeObserver(on: PhotoLibraryManager.shared)
        return coordinator
    }
}
