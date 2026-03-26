import XCTest
import SwiftUI
@testable import ENVI

final class ENVITests: XCTestCase {
    func testColorHexInit() {
        let color = Color(hex: "#7B68EE")
        XCTAssertNotNil(color)
    }

    func testUserMock() {
        let user = User.mock
        XCTAssertEqual(user.firstName, "Alex")
        XCTAssertEqual(user.initials, "AR")
    }

    func testContentItemMockFeed() {
        let items = ContentItem.mockFeed
        XCTAssertGreaterThan(items.count, 0)
    }

    func testOnboardingViewModel() {
        let vm = OnboardingViewModel()
        vm.firstName = "Test"
        vm.lastName = "User"
        XCTAssertTrue(vm.isNameValid)
        XCTAssertTrue(vm.canContinue)
    }

    func testAnalyticsDataMock() {
        let data = AnalyticsData.mock
        XCTAssertEqual(data.dailyEngagement.count, 7)
    }

    func testThemeManager() {
        let manager = ThemeManager.shared
        XCTAssertNotNil(manager.mode)
    }
}
