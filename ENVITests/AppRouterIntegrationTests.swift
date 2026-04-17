import XCTest
import Combine
@testable import ENVI

/// Phase 15-02 — integration tests for router-driven presentation and
/// tab-selection observation. Because visual sheet rendering depends on
/// the SwiftUI host, we assert the published-state contract that
/// consumers (tab roots + Combine observers) rely on. The visual leg of
/// the migration is covered by the simulator-based manual test logged
/// in 15-02-SUMMARY.md.
@MainActor
final class AppRouterIntegrationTests: XCTestCase {

    func testPresentingSearchFromRouterRendersSearchSheet() {
        let router = AppRouter()
        router.present(.search)

        // Contract: `router.sheet` must equal `.search` so the tab root's
        // `.sheet(item: $router.sheet)` modifier surfaces the resolver
        // with that destination. The resolver's switch case for
        // `.search` returns `FeedSearchView()`; that leg is covered by
        // the build-time type system + simulator smoke test — all we
        // need to pin here is the router-state contract.
        XCTAssertEqual(router.sheet, .search)
        XCTAssertNil(router.fullScreen)
    }

    func testSelectTabFromRouterFiresObservation() {
        let router = AppRouter()
        var received: [Int] = []
        var cancellables: Set<AnyCancellable> = []

        router.$selectedTab
            .sink { received.append($0) }
            .store(in: &cancellables)

        router.selectTab(1)

        // Combine emits the current value on subscribe (0), then the new
        // value after `selectTab(1)`. Assert both are present so the
        // MainTabBarController → showViewController sink in the real
        // app is guaranteed to receive tab-switch events.
        XCTAssertTrue(received.contains(0))
        XCTAssertTrue(received.contains(1))
        XCTAssertEqual(router.selectedTab, 1)
    }
}
