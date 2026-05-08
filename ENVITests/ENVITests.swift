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

    @MainActor
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

    func testContentPieceAssemblerRetriesAndCompletes() async {
        let transport = FlakyAssemblyTransport(failuresBeforeSuccess: 1)
        let assembler = ContentPieceAssembler(transport: transport)
        let completionExpectation = expectation(description: "Assembly completion called")
        var assembledID: String?

        assembler.enqueueForAssembly(mediaIDs: ["media-1"]) { result in
            if case let .success(id) = result {
                assembledID = id
                completionExpectation.fulfill()
            }
        }

        await fulfillment(of: [completionExpectation], timeout: 2.0)
        XCTAssertEqual(assembledID, "piece-media-1")
        XCTAssertEqual(assembler.assembledCount, 1)
        XCTAssertEqual(assembler.failedCount, 0)
    }
}

private final class FlakyAssemblyTransport: ContentAssemblyTransport {
    private let failuresBeforeSuccess: Int
    private var uploadAttemptCount = 0

    init(failuresBeforeSuccess: Int) {
        self.failuresBeforeSuccess = failuresBeforeSuccess
    }

    func uploadMediaAsset(mediaID: String) async throws -> UploadMediaResponse {
        uploadAttemptCount += 1
        if uploadAttemptCount <= failuresBeforeSuccess {
            throw TestTransportError.transientFailure
        }
        return UploadMediaResponse(id: "asset-\(mediaID)")
    }

    func createContentPiece(mediaAssetID: String) async throws -> CreatePieceResponse {
        CreatePieceResponse(id: "piece-\(mediaAssetID.replacingOccurrences(of: "asset-", with: ""))")
    }
}

private enum TestTransportError: Error {
    case transientFailure
}
