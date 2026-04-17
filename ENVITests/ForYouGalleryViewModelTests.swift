import XCTest
@testable import ENVI

@MainActor
final class ForYouGalleryViewModelTests: XCTestCase {

    // MARK: - Test Doubles

    final class ThrowingTemplateRepo: VideoTemplateRepository {
        struct Boom: Error {}

        func fetchCatalog() async throws -> [VideoTemplate] { throw Boom() }
        func fetchTrending() async throws -> [VideoTemplate] { throw Boom() }
        func fetchByCategory(_ category: VideoTemplateCategory) async throws -> [VideoTemplate] { throw Boom() }
        func duplicate(templateID: UUID) async throws -> VideoTemplate { throw Boom() }
    }

    // MARK: - Tests

    func testDefaultSegmentIsForYou() {
        let vm = HomeFeedViewModel(approvedStore: ApprovedMediaLibraryStore.shared)
        XCTAssertEqual(vm.selectedSegment, HomeFeedViewModel.Segment.forYou)
    }

    func testTemplateFailureDoesNotCrashAndResolvesState() async {
        let vm = HomeFeedViewModel(
            approvedStore: ApprovedMediaLibraryStore.shared,
            templateRepo: ThrowingTemplateRepo()
        )

        await vm.loadForYouContent()

        switch vm.loadingPhase {
        case .error, .empty, .analyzing:
            XCTAssertTrue(vm.forYouItems.isEmpty)
        case .ready:
            XCTFail("Expected no ready state when template repo throws.")
        case .idle, .matchingTemplates:
            XCTFail("Expected terminal loading phase after load attempt.")
        }
    }
}
