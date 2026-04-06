import Foundation

protocol ContentRepository {
    func fetchFeedItems() async throws -> [ContentItem]
    func fetchLibraryItems() async throws -> [ContentItem]
    func fetchContentPlan() async throws -> [ContentPlanItem]
    func duplicateTemplate(templateID: UUID) async throws -> TemplateItem
    func deleteTemplate(templateID: UUID) async throws
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

    func duplicateTemplate(templateID: UUID) async throws -> TemplateItem {
        let source = TemplateItem.mockTemplates.first ?? TemplateItem(
            title: "Untitled Template",
            imageName: "jacket",
            category: "General"
        )
        return TemplateItem(
            title: "\(source.title) Copy",
            imageName: source.imageName,
            category: source.category
        )
    }

    func deleteTemplate(templateID: UUID) async throws {
        // Local mock path intentionally no-op.
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

    func duplicateTemplate(templateID: UUID) async throws -> TemplateItem {
        let response: TemplateItemResponse = try await apiClient.request(
            endpoint: "templates/\(templateID.uuidString)/duplicate",
            method: .post,
            body: EmptyBody(),
            requiresAuth: true
        )
        return response.toDomain()
    }

    func deleteTemplate(templateID: UUID) async throws {
        try await apiClient.requestVoid(
            endpoint: "templates/\(templateID.uuidString)",
            method: .delete,
            requiresAuth: true
        )
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

private struct TemplateItemResponse: Decodable {
    let id: String?
    let title: String
    let imageName: String?
    let category: String

    func toDomain() -> TemplateItem {
        TemplateItem(
            id: UUID(uuidString: id ?? "") ?? UUID(),
            title: title,
            imageName: imageName ?? "jacket",
            category: category
        )
    }
}

private struct EmptyBody: Encodable {}

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
