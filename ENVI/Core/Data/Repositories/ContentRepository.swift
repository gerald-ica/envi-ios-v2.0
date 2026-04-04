import Foundation

protocol ContentRepository {
    func fetchFeedItems() async throws -> [ContentItem]
    func fetchLibraryItems() async throws -> [ContentItem]
}

final class MockContentRepository: ContentRepository {
    func fetchFeedItems() async throws -> [ContentItem] {
        ContentItem.mockFeed
    }

    func fetchLibraryItems() async throws -> [ContentItem] {
        ContentItem.mockFeed
    }
}

final class APIContentRepository: ContentRepository {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchFeedItems() async throws -> [ContentItem] {
        try await apiClient.request(endpoint: "feed", method: .get)
    }

    func fetchLibraryItems() async throws -> [ContentItem] {
        try await apiClient.request(endpoint: "library", method: .get)
    }
}

enum ContentRepositoryProvider {
    static var shared = Shared()

    struct Shared {
        var contentRepository: ContentRepository = MockContentRepository()
    }
}
