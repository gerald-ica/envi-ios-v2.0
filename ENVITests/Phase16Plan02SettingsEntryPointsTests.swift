import XCTest
@testable import ENVI

/// Phase 16-02 — pin tests for the 6 Profile-adjacent modal entry points
/// (Agency, Teams, Commerce, Experiments, Security, Notifications).
///
/// These assertions lock in the destination catalog and its resolver
/// coverage so a future AppDestination refactor can't silently drop
/// any of the 6 surfaces.
@MainActor
final class Phase16Plan02SettingsEntryPointsTests: XCTestCase {

    func testAgencyDestinationExists() {
        XCTAssertEqual(AppDestination.agency.id, "agency")
    }

    func testTeamsDestinationExists() {
        XCTAssertEqual(AppDestination.teams.id, "teams")
    }

    func testCommerceDestinationExists() {
        XCTAssertEqual(AppDestination.commerce.id, "commerce")
    }

    func testExperimentsDestinationExists() {
        XCTAssertEqual(AppDestination.experiments.id, "experiments")
    }

    func testSecurityDestinationExists() {
        XCTAssertEqual(AppDestination.security.id, "security")
    }

    func testNotificationsDestinationExists() {
        XCTAssertEqual(AppDestination.notifications.id, "notifications")
    }

    func testAllSixDestinationsDefaultToSheetPresentation() {
        let destinations: [AppDestination] = [
            .agency, .teams, .commerce, .experiments, .security, .notifications
        ]
        for destination in destinations {
            XCTAssertEqual(
                destination.defaultPresentation,
                .sheet,
                "Profile-adjacent destination \(destination.id) should default to .sheet presentation."
            )
        }
    }

    func testAllSixDestinationsHaveDistinctIDs() {
        let ids: [String] = [
            AppDestination.agency.id,
            AppDestination.teams.id,
            AppDestination.commerce.id,
            AppDestination.experiments.id,
            AppDestination.security.id,
            AppDestination.notifications.id,
        ]
        XCTAssertEqual(Set(ids).count, ids.count)
    }
}
