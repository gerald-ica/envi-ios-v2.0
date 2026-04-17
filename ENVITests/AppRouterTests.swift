import XCTest
@testable import ENVI

/// Phase 15-01 — pins AppRouter's presentation + dismissal behavior
/// and AppDestination identity semantics. These tests are pure value-
/// logic checks; they do not spin up SwiftUI.
@MainActor
final class AppRouterTests: XCTestCase {

    // MARK: - present(_:)

    func testPresentSheetSetsPublishedSheet() {
        let router = AppRouter()
        router.present(.search)

        XCTAssertEqual(router.sheet, .search)
        XCTAssertNil(router.fullScreen)
    }

    func testPresentFullScreenSetsPublishedFullScreen() {
        let router = AppRouter()
        // `.contentEditor` defaults to `.fullScreenCover` per
        // AppDestination.defaultPresentation.
        let dest = AppDestination.contentEditor(contentID: "x")
        router.present(dest)

        XCTAssertEqual(router.fullScreen, dest)
        XCTAssertNil(router.sheet)
    }

    // MARK: - dismiss()

    func testDismissClearsBoth() {
        let router = AppRouter()
        router.present(.search)
        router.dismiss()
        XCTAssertNil(router.sheet)
        XCTAssertNil(router.fullScreen)

        router.present(.contentEditor(contentID: "x"))
        router.dismiss()
        XCTAssertNil(router.sheet)
        XCTAssertNil(router.fullScreen)
    }

    // MARK: - replace(_:)

    func testReplaceSwapsDestinations() async {
        let router = AppRouter()
        router.present(.search)
        XCTAssertEqual(router.sheet, .search)

        router.replace(.contentCalendar)

        // `replace` dismisses first (sheet → nil), then enqueues a
        // re-present on the main actor. Yield twice so both tasks
        // (the one from `replace` itself, and the one inside
        // `present(_:)` that re-presents after clearing) drain.
        await Task.yield()
        await Task.yield()
        XCTAssertEqual(router.sheet, .contentCalendar)
    }

    // MARK: - selectTab(_:)

    func testSelectTabClearsPresentations() {
        let router = AppRouter()
        router.present(.search)
        router.selectTab(1)

        XCTAssertEqual(router.selectedTab, 1)
        XCTAssertNil(router.sheet)
        XCTAssertNil(router.fullScreen)
    }

    // MARK: - AppDestination identity

    func testAppDestinationIdIsStableForSameCase() {
        let a1 = AppDestination.campaignDetail(id: "abc")
        let a2 = AppDestination.campaignDetail(id: "abc")
        let b = AppDestination.campaignDetail(id: "xyz")

        XCTAssertEqual(a1.id, a2.id)
        XCTAssertEqual(a1, a2)
        XCTAssertNotEqual(a1.id, b.id)
        XCTAssertNotEqual(a1, b)
    }
}
