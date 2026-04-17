import XCTest
@testable import ENVI

/// Phase 16-04 — pin tests for LibraryToolsMenu's catalog, visibility
/// gating (admin/enterprise), and destination coverage.
@MainActor
final class LibraryToolsMenuTests: XCTestCase {

    func testLibraryToolsMenuDefaultContentCount() {
        // Seven tools visible by default: BrandKit, Metadata, Repurposing
        // (Content) + Campaigns, Collaboration, Community (Campaigns &
        // Teams) + Search (Advanced). Admin + Enterprise are gated.
        let sections = LibraryToolsMenu.visibleSections(showAdminTools: false)
        let total = sections.reduce(0) { $0 + $1.tools.count }
        XCTAssertEqual(total, 7)
    }

    func testAdminToolHiddenByDefault() {
        let sections = LibraryToolsMenu.visibleSections(showAdminTools: false)
        let destinations = sections.flatMap { $0.tools }.map(\.destination)
        XCTAssertFalse(destinations.contains(.admin),
                       "Admin should NOT be visible when showAdminTools == false.")
        XCTAssertFalse(destinations.contains(.enterprise),
                       "Enterprise should NOT be visible when showAdminTools == false.")
    }

    func testAdminToolShownWhenFlagEnabled() {
        let sections = LibraryToolsMenu.visibleSections(showAdminTools: true)
        let destinations = sections.flatMap { $0.tools }.map(\.destination)
        XCTAssertTrue(destinations.contains(.admin),
                      "Admin should be visible when showAdminTools == true.")
        XCTAssertTrue(destinations.contains(.enterprise),
                      "Enterprise should be visible when showAdminTools == true.")
        let total = sections.reduce(0) { $0 + $1.tools.count }
        XCTAssertEqual(total, 9, "All 9 tools are visible with the flag on.")
    }

    func testAllNineLibraryDestinationsHaveDistinctIDs() {
        let allDestinations: [AppDestination] = LibraryToolsMenu.allSections
            .flatMap { $0.tools }
            .map(\.destination)
        XCTAssertEqual(allDestinations.count, 9)
        XCTAssertEqual(Set(allDestinations.map { $0.id }).count, 9,
                       "Every Library tool must route to a distinct destination.")
    }

    func testLibraryToolsDestinationExists() {
        // The menu itself is routable.
        XCTAssertEqual(AppDestination.libraryTools.id, "libraryTools")
        XCTAssertEqual(AppDestination.libraryTools.defaultPresentation, .sheet)
    }

    func testFeatureFlagShowAdminToolsDefaultsFalse() {
        // Critical — admin surfaces must NOT leak to creators by
        // default. Regression guard for anyone flipping the default
        // without a roadmap entry.
        XCTAssertFalse(FeatureFlags.shared.showAdminTools,
                       "showAdminTools must default to false so admin rows never show for creators.")
    }
}
