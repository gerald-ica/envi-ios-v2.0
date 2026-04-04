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
    static var shared = Shared(contentRepository: defaultRepository())

    struct Shared {
        var contentRepository: ContentRepository
    }

    private static func defaultRepository() -> ContentRepository {
        switch AppEnvironment.current {
        case .dev:
            return MockContentRepository()
        case .staging, .prod:
            return APIContentRepository()
        }
    }
}
