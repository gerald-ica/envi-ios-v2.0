import Foundation

/// Phase 15-03 — Deferred deep-link dispatcher.
///
/// When a deep link arrives while the app is on Splash or SignIn (i.e.,
/// `MainTabBarController` hasn't been presented yet), presenting a
/// `router.sheet` would target a view that isn't on screen — the sheet
/// silently fails or lands under an invisible root. This store captures
/// the destination and replays it once `AppCoordinator.showMainApp()`
/// has finished wiring the tab bar.
///
/// ## Usage
/// - `dispatchOrStore(_:)` — call from the URL handler. Non-isolated
///   entry point; hops to main actor internally. If the main app is
///   ready, routes immediately; otherwise stashes.
/// - `markMainAppReady()` — call from `AppCoordinator` right after
///   `showMainApp()` pushes the `MainTabBarController`. Flushes any
///   pending destination.
final class PendingDeepLinkStore: @unchecked Sendable {

    static let shared = PendingDeepLinkStore()

    private var pending: AppDestination?
    private var isMainAppReady = false
    private let queue = DispatchQueue(label: "com.envi.pendingDeepLinkStore")

    private init() {}

    /// Dispatch a destination immediately if the router is ready,
    /// otherwise stash for replay. Non-isolated so AppDelegate's
    /// `application(_:open:)` can call it without hopping first.
    func dispatchOrStore(_ destination: AppDestination) {
        Task { @MainActor in
            if self.readyFlag {
                AppRouter.shared.present(destination)
            } else {
                self.pendingValue = destination
            }
        }
    }

    /// Called by `AppCoordinator` once the main tab bar is on screen.
    /// Replays any pending destination exactly once.
    @MainActor
    func markMainAppReady() {
        readyFlag = true
        if let destination = pendingValue {
            pendingValue = nil
            AppRouter.shared.present(destination)
        }
    }

    /// Reset the store — useful on sign-out so a stale pending link
    /// doesn't fire after a subsequent sign-in. Tests also use this.
    @MainActor
    func reset() {
        pendingValue = nil
        readyFlag = false
    }

    /// Test-only inspection.
    @MainActor
    var hasPendingDeepLink: Bool { pendingValue != nil }

    // MARK: - Serialized storage

    private var pendingValue: AppDestination? {
        get { queue.sync { pending } }
        set { queue.sync { pending = newValue } }
    }

    private var readyFlag: Bool {
        get { queue.sync { isMainAppReady } }
        set { queue.sync { isMainAppReady = newValue } }
    }
}
