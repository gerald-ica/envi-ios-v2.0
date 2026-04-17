import Foundation
import Combine

/// Phase 15-01 — Central presentation router for ENVI's SwiftUI surface.
///
/// ## Ownership pattern
///
/// `AppRouter` is `@MainActor` and conforms to `ObservableObject`. The
/// v1.2 hybrid UIKit/SwiftUI architecture threads a single router through
/// `MainTabBarController` (UIKit) into each tab's `UIHostingController`
/// rootView via `.environmentObject(router)`. Each tab root then attaches
///
///     .sheet(item: $router.sheet) { destination in
///         AppDestinationSheetResolver(destination: destination)
///     }
///     .fullScreenCover(item: $router.fullScreen) { destination in
///         AppDestinationFullScreenResolver(destination: destination)
///     }
///
/// For call-sites that need fire-and-forget access (e.g., SceneDelegate
/// deep-link hook, where no SwiftUI environment exists), `AppRouter.shared`
/// is available. Prefer `@EnvironmentObject` inside SwiftUI views.
///
/// ## Sheet-over-sheet quirk
///
/// SwiftUI's presentation machinery deadlocks if you replace a live sheet
/// with another one synchronously. `present(_:)` handles this by
/// dismissing first and presenting in a follow-up `Task { @MainActor … }`.
@MainActor
final class AppRouter: ObservableObject {

    // MARK: - Shared instance

    /// Process-wide singleton for call-sites that cannot reach an
    /// `@EnvironmentObject` (e.g., `SceneDelegate` URL handling).
    /// In-SwiftUI code should prefer the environment-injected instance
    /// threaded by `MainTabBarController`.
    static let shared = AppRouter()

    // MARK: - Published state

    /// Currently-presented sheet. Setting this to non-nil presents;
    /// setting to nil dismisses.
    @Published var sheet: AppDestination?

    /// Currently-presented full-screen cover. Same semantics as `sheet`.
    @Published var fullScreen: AppDestination?

    /// Reserved for Phase 16's NavigationStack migration. Declared now so
    /// downstream consumers can observe it as soon as push-style
    /// navigation lands.
    @Published var pushStack: [AppDestination] = []

    /// Mirrors `MainTabBarController.currentIndex`. A Combine sink in
    /// `MainTabBarController` observes this and calls `showViewController`;
    /// tab taps write back via `selectTab(_:)` so both directions stay in
    /// sync.
    @Published var selectedTab: Int = 0

    // MARK: - Lifecycle

    init() {}

    // MARK: - Presentation API

    /// Present a destination. Routes to sheet / fullScreen / push / tab
    /// based on `preferring ?? destination.defaultPresentation`.
    /// If a sheet is already up and the new destination is also `.sheet`,
    /// the live sheet is dismissed first and the new one is presented on
    /// the next run-loop tick to avoid SwiftUI's sheet-over-sheet deadlock.
    func present(_ destination: AppDestination, preferring: AppDestination.Presentation? = nil) {
        let style = preferring ?? destination.defaultPresentation

        switch style {
        case .sheet:
            if sheet != nil {
                // Live sheet — dismiss first, then present on next tick.
                sheet = nil
                Task { @MainActor in
                    self.sheet = destination
                }
            } else {
                sheet = destination
            }

        case .fullScreenCover:
            if fullScreen != nil {
                fullScreen = nil
                Task { @MainActor in
                    self.fullScreen = destination
                }
            } else {
                fullScreen = destination
            }

        case .push:
            pushStack.append(destination)

        case .tab(let index):
            selectTab(index)
        }
    }

    /// Dismiss whichever presentation is currently active.
    func dismiss() {
        if sheet != nil { sheet = nil }
        if fullScreen != nil { fullScreen = nil }
    }

    /// Dismiss the current presentation, then present the given
    /// destination on the next run-loop tick.
    func replace(_ destination: AppDestination) {
        dismiss()
        Task { @MainActor in
            self.present(destination)
        }
    }

    /// Switch to a tab index. Clears any sheet / full-screen cover so the
    /// user lands on the new tab without stale modal state.
    func selectTab(_ index: Int) {
        if sheet != nil { sheet = nil }
        if fullScreen != nil { fullScreen = nil }
        selectedTab = index
    }
}
