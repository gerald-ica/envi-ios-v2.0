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
        let vm = ForYouGalleryViewModel(approvedStore: ApprovedMediaLibraryStore.shared)
        XCTAssertEqual(vm.selectedSegment, ForYouGalleryViewModel.Segment.forYou)
    }

    func testTemplateFailureDoesNotCrashAndResolvesState() async {
        let vm = ForYouGalleryViewModel(
            approvedStore: ApprovedMediaLibraryStore.shared,
            templateRepo: ThrowingTemplateRepo()
        )

        await vm.loadForYouContent()

        switch vm.loadingPhase {
        case .error, .empty:
            XCTAssertTrue(vm.forYouItems.isEmpty)
        case .ready:
            XCTAssertFalse(vm.forYouItems.isEmpty)
        case .idle, .analyzing, .matchingTemplates:
            XCTFail("Expected terminal loading phase after load attempt.")
        }
    }
}
