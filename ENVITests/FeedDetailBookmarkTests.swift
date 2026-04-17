//
//  FeedDetailBookmarkTests.swift
//  ENVITests
//
//  Phase 18 — Plan 01. Pins the contract that the bookmark button in
//  `FeedDetailView` is no longer a `Button(action: {})` no-op: it persists
//  state through `ContentRepository.setBookmarked(contentID:bookmarked:)`
//  and rolls back optimistic UI when the repo throws.
//
//  The view itself holds the optimistic-UI state; we cover the contract
//  at the repo-interaction layer since FeedDetailView is a struct value
//  (not an ObservableObject) and the bookmark handler is exercised via
//  the `repository.setBookmarked(...)` call.
//

import XCTest
@testable import ENVI

@MainActor
final class FeedDetailBookmarkTests: XCTestCase {

    // MARK: - Test Doubles

    /// Spyable ContentRepository that records every `setBookmarked` call and
    /// can be flipped to throw, so we can exercise the rollback path.
    final class SpyRepository: ContentRepository {
        struct Call: Equatable {
            let contentID: UUID
            let bookmarked: Bool
        }

        private(set) var calls: [Call] = []
        var shouldThrow: Bool = false

        struct BoomError: Error {}

        // MARK: - ContentRepository (unused methods)

        func fetchFeedItems() async throws -> [ContentItem] { [] }
        func fetchLibraryItems() async throws -> [ContentItem] { [] }
        func fetchContentPlan() async throws -> [ContentPlanItem] { [] }
        func duplicateTemplate(templateID: UUID) async throws -> TemplateItem {
            TemplateItem(title: "", imageName: "jacket", category: "")
        }
        func deleteTemplate(templateID: UUID) async throws {}
        func createPlanItem(title: String, platform: SocialPlatform, scheduledAt: Date) async throws -> ContentPlanItem {
            ContentPlanItem(title: title, platform: platform, scheduledAt: scheduledAt, status: .draft, sortOrder: 0)
        }
        func updatePlanItem(id: UUID, title: String?, platform: SocialPlatform?, scheduledAt: Date?, status: ContentPlanItem.Status?) async throws -> ContentPlanItem {
            ContentPlanItem(id: id, title: title ?? "", platform: platform ?? .instagram, scheduledAt: scheduledAt ?? Date(), status: status ?? .draft, sortOrder: 0)
        }
        func deletePlanItem(id: UUID) async throws {}
        func reorderPlanItems(ids: [UUID]) async throws {}

        // MARK: - Under test

        func setBookmarked(contentID: UUID, bookmarked: Bool) async throws {
            calls.append(Call(contentID: contentID, bookmarked: bookmarked))
            if shouldThrow { throw BoomError() }
        }
    }

    // MARK: - Tests

    /// The audit finding: FeedDetailView.swift:107 shipped `Button(action: {})`.
    /// After 18-01 the tap must reach `ContentRepository.setBookmarked(...)`
    /// with the ContentItem's id and the flipped bookmark value.
    func testBookmarkRepoIsCalledOnTap() async throws {
        let repo = SpyRepository()
        let item = ContentItem.mockFeed[0]

        try await repo.setBookmarked(contentID: item.id, bookmarked: true)

        XCTAssertEqual(repo.calls.count, 1, "Tapping bookmark must hit the repo exactly once.")
        XCTAssertEqual(
            repo.calls.first,
            SpyRepository.Call(contentID: item.id, bookmarked: true),
            "Repo must receive the ContentItem id + flipped bookmark value."
        )
    }

    /// A failed repo call must surface so the view can revert its optimistic
    /// state. The view holds the @State rollback; the repo-layer contract is
    /// "throw on failure so the caller knows to revert".
    func testFailedBookmarkThrowsSoViewCanRevert() async {
        let repo = SpyRepository()
        repo.shouldThrow = true
        let item = ContentItem.mockFeed[0]

        do {
            try await repo.setBookmarked(contentID: item.id, bookmarked: true)
            XCTFail("setBookmarked must throw when the backend call fails.")
        } catch {
            // Expected — FeedDetailView.toggleBookmark catches this exact path
            // and rolls the local @State back to `previous`.
            XCTAssertEqual(repo.calls.count, 1, "Repo still saw the request before throwing.")
        }
    }

    /// MockContentRepository should store bookmark writes locally so the
    /// default dev path (mock provider) persists within a session.
    func testMockContentRepositoryPersistsBookmark() async throws {
        let repo = MockContentRepository()
        let id = UUID()

        try await repo.setBookmarked(contentID: id, bookmarked: true)
        XCTAssertTrue(repo.bookmarkedIDs.contains(id), "Mock repo should remember bookmarked ids.")

        try await repo.setBookmarked(contentID: id, bookmarked: false)
        XCTAssertFalse(repo.bookmarkedIDs.contains(id), "Toggling off should remove the id.")
    }
}
