import Foundation

protocol ContentRepository {
    func fetchFeedItems() async throws -> [ContentItem]
    func fetchLibraryItems() async throws -> [ContentItem]
    func fetchContentPlan() async throws -> [ContentPlanItem]
}

final class MockContentRepository: ContentRepository {
    func fetchFeedItems() async throws -> [ContentItem] {
        ContentItem.mockFeed
    }

    func fetchLibraryItems() async throws -> [ContentItem] {
        ContentItem.mockFeed
    }

    func fetchContentPlan() async throws -> [ContentPlanItem] {
        ContentPlanItem.mockPlan
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

    func fetchContentPlan() async throws -> [ContentPlanItem] {
        let response: [ContentPlanItemResponse] = try await apiClient.request(
            endpoint: "planning/content-plan",
            method: .get,
            requiresAuth: true
        )
        return response.map { $0.toDomain() }
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

private struct ContentPlanItemResponse: Decodable {
    let id: String?
    let title: String
    let platform: String
    let scheduledAt: String
    let status: String

    func toDomain() -> ContentPlanItem {
        let parsedDate = ISO8601DateFormatter().date(from: scheduledAt) ?? Date()
        let parsedPlatform = SocialPlatform(rawValue: platform) ?? .instagram
        let parsedStatus = ContentPlanItem.Status(rawValue: status) ?? .draft

        return ContentPlanItem(
            id: UUID(uuidString: id ?? "") ?? UUID(),
            title: title,
            platform: parsedPlatform,
            scheduledAt: parsedDate,
            status: parsedStatus
        )
    }
}
