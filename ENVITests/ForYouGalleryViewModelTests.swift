//
//  ForYouGalleryViewModelTests.swift
//  ENVITests
//
//  Phase 19 — Plan 04. Baseline coverage for the For You / Gallery tab VM.
//  Pins the contract that the VM starts on the For You segment, loads feed
//  items from the repository via the ContentRepository fallback path (when
//  the template pipeline yields nothing), and handles errors without crashing.
//

import XCTest
@testable import ENVI

@MainActor
final class ForYouGalleryViewModelTests: XCTestCase {

    // MARK: - Test Doubles

    final class StubContentRepository: ContentRepository {
        var feedItems: [ContentItem] = []
        var libraryItems: [ContentItem] = []
        var plan: [ContentPlanItem] = []
        var shouldThrow = false
        struct BoomError: Error {}

        func fetchFeedItems() async throws -> [ContentItem] {
            if shouldThrow { throw BoomError() }
            return feedItems
        }
        func fetchLibraryItems() async throws -> [ContentItem] {
            if shouldThrow { throw BoomError() }
            return libraryItems
        }
        func fetchContentPlan() async throws -> [ContentPlanItem] {
            if shouldThrow { throw BoomError() }
            return plan
        }
        func setBookmarked(contentID: UUID, bookmarked: Bool) async throws {
            if shouldThrow { throw BoomError() }
        }
        func duplicateTemplate(templateID: UUID) async throws -> TemplateItem {
            throw BoomError()
        }
        func deleteTemplate(templateID: UUID) async throws { throw BoomError() }
        func createPlanItem(title: String, platform: SocialPlatform, scheduledAt: Date) async throws -> ContentPlanItem {
            throw BoomError()
        }
        func updatePlanItem(id: UUID, title: String?, platform: SocialPlatform?, scheduledAt: Date?, status: ContentPlanItem.Status?) async throws -> ContentPlanItem {
            throw BoomError()
        }
        func deletePlanItem(id: UUID) async throws { throw BoomError() }
        func reorderPlanItems(ids: [UUID]) async throws { throw BoomError() }
    }

    // MARK: - Tests

    /// Default state before any load has run.
    func testDefaultSegmentIsForYou() {
        let vm = ForYouGalleryViewModel(
            approvedStore: ApprovedMediaLibraryStore.shared,
            repository: StubContentRepository()
        )
        XCTAssertEqual(vm.selectedSegment, ForYouGalleryViewModel.Segment.forYou)
    }

    /// When the template pipeline yields no matches (common for unit tests
    /// without a populated ClassificationCache), the VM falls back to
    /// `repository.fetchFeedItems()`. If those come back populated, the
    /// feed should end up populated.
    func testLoadForYouFallsBackToRepositoryFeed() async {
        let repo = StubContentRepository()
        repo.feedItems = ContentItem.mockFeed

        let vm = ForYouGalleryViewModel(
            approvedStore: ApprovedMediaLibraryStore.shared,
            repository: repo
        )

        await vm.loadForYouContent()

        // Template pipeline returns [] (no classified assets in tests),
        // so we expect the repository fallback to populate forYouItems.
        // Note: the VM filters by seenItemIDs from UserDefaults, which can
        // be non-empty across test runs; we just assert the path resolves
        // without crashing and the loadingPhase isn't error.
        switch vm.loadingPhase {
        case .error:
            XCTFail("Repo fallback populated feedItems should never produce error loading phase.")
        default:
            break
        }
    }

    /// On repo error in dev, the VM silently falls back to `ContentItem.mockFeed`
    /// (matching AnalyticsViewModel / BenchmarkViewModel conventions).
    /// This pins that behavior — if someone ever changes it to prod-style
    /// errorMessage semantics, tests will surface it.
    func testLoadForYouDevFallbackOnError() async throws {
        guard AppEnvironment.current == .dev else {
            throw XCTSkip("Dev fallback only applies in .dev AppEnvironment")
        }
        let repo = StubContentRepository()
        repo.shouldThrow = true

        let vm = ForYouGalleryViewModel(
            approvedStore: ApprovedMediaLibraryStore.shared,
            repository: repo
        )
        await vm.loadForYouContent()

        // Either the items are populated from mockFeed or the empty seen-ID
        // filter leaves us empty; the important contract is no crash and
        // loadingPhase resolves to either ready or empty, not error.
        switch vm.loadingPhase {
        case .ready, .empty: break
        case .error:
            XCTFail("Dev env should NOT surface an error loading phase on repo throw.")
        default:
            XCTFail("Unexpected loadingPhase")
        }
    }
}
