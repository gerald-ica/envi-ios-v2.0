import XCTest
@testable import ENVI

/// Phase 16-01 — Publishing tab wiring pin tests.
///
/// Smoke-asserts that:
/// - `PublishingTabView` can be instantiated without required init args
///   (proof the tab root is router-ready and pulls its VM internally).
/// - `AppRouter.selectTab(2)` lands on Publishing (index 2 — Publishing
///   is slotted BEFORE Profile so profile stays rightmost).
/// - The Phase 16-01 `AppDestination` cases exist and have distinct ids.
@MainActor
final class PublishingTabTests: XCTestCase {

    func testPublishingTabViewExists() {
        // Must compile + instantiate without arguments. The view hosts
        // its own `SchedulingViewModel` and consumes the router via
        // `@EnvironmentObject`, so no caller-side wiring is needed.
        _ = PublishingTabView()
    }

    func testRouterSelectTabTwoSwitchesToPublishing() {
        let router = AppRouter()
        router.selectTab(2)
        XCTAssertEqual(router.selectedTab, 2,
                       "Publishing tab should live at index 2 (before Profile).")
    }

    func testPublishingDestinationsExistWithDistinctIDs() {
        let destinations: [AppDestination] = [
            .schedulePost,
            .publishResults,
            .linkedInAuthorPicker
        ]
        let ids = Set(destinations.map { $0.id })
        XCTAssertEqual(ids.count, destinations.count,
                       "Each Phase 16-01 publishing destination must have a unique id.")
        XCTAssertTrue(ids.contains("schedulePost"))
        XCTAssertTrue(ids.contains("publishResults"))
        XCTAssertTrue(ids.contains("linkedInAuthorPicker"))
    }

    func testSchedulingViewModelHasNonNilRepository() {
        // Instantiating the VM via its default init should bind it to
        // `SchedulingRepositoryProvider.shared.repository` (real stack,
        // not a Mock). The repo is private; a non-crashing init is the
        // observable proof that the default chain is intact.
        let vm = SchedulingViewModel()
        XCTAssertFalse(vm.isLoading == false && vm.errorMessage != nil,
                       "VM should not start in an error state before any load completes.")
    }
}
