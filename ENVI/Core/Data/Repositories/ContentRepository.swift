import Foundation

protocol ContentRepository {
    func fetchFeedItems() async throws -> [ContentItem]
    func fetchLibraryItems() async throws -> [ContentItem]
    func fetchContentPlan() async throws -> [ContentPlanItem]
    func duplicateTemplate(templateID: UUID) async throws -> TemplateItem
    func deleteTemplate(templateID: UUID) async throws

    // MARK: - Planning CRUD
    func createPlanItem(title: String, platform: SocialPlatform, scheduledAt: Date) async throws -> ContentPlanItem
    func updatePlanItem(id: UUID, title: String?, platform: SocialPlatform?, scheduledAt: Date?, status: ContentPlanItem.Status?) async throws -> ContentPlanItem
    func deletePlanItem(id: UUID) async throws
    func reorderPlanItems(ids: [UUID]) async throws
}

final class MockContentRepository: ContentRepository {
    private var planItems: [ContentPlanItem] = ContentPlanItem.mockPlan

    func fetchFeedItems() async throws -> [ContentItem] {
        ContentItem.mockFeed
    }

    func fetchLibraryItems() async throws -> [ContentItem] {
        ContentItem.mockFeed
    }

    func fetchContentPlan() async throws -> [ContentPlanItem] {
        planItems
    }

    func duplicateTemplate(templateID: UUID) async throws -> TemplateItem {
        let source = TemplateItem.mockTemplates.first(where: { $0.id == templateID })
            ?? TemplateItem.mockTemplates.first
            ?? TemplateItem(
                title: "Untitled Template",
                imageName: "jacket",
                category: "General"
            )
        return TemplateItem(
            title: "\(source.title) Copy",
            imageName: source.imageName,
            category: source.category,
            captionTemplate: source.captionTemplate,
            suggestedPlatforms: source.suggestedPlatforms,
            contentKind: source.contentKind
        )
    }

    func deleteTemplate(templateID: UUID) async throws {
        // Local mock path intentionally no-op.
    }

    // MARK: - Planning CRUD

    func createPlanItem(title: String, platform: SocialPlatform, scheduledAt: Date) async throws -> ContentPlanItem {
        let item = ContentPlanItem(
            title: title,
            platform: platform,
            scheduledAt: scheduledAt,
            status: .draft,
            sortOrder: 0
        )
        planItems.insert(item, at: 0)
        // Re-index sort orders
        for i in planItems.indices { planItems[i].sortOrder = i }
        return item
    }

    func updatePlanItem(id: UUID, title: String?, platform: SocialPlatform?, scheduledAt: Date?, status: ContentPlanItem.Status?) async throws -> ContentPlanItem {
        guard let index = planItems.firstIndex(where: { $0.id == id }) else {
            throw NSError(domain: "MockContentRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Plan item not found."])
        }
        if let title { planItems[index].title = title }
        if let platform { planItems[index].platform = platform }
        if let scheduledAt { planItems[index].scheduledAt = scheduledAt }
        if let status { planItems[index].status = status }
        return planItems[index]
    }

    func deletePlanItem(id: UUID) async throws {
        planItems.removeAll { $0.id == id }
    }

    func reorderPlanItems(ids: [UUID]) async throws {
        var reordered: [ContentPlanItem] = []
        for (index, id) in ids.enumerated() {
            if var item = planItems.first(where: { $0.id == id }) {
                item.sortOrder = index
                reordered.append(item)
            }
        }
        planItems = reordered
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

    // MARK: - Planning CRUD

    func createPlanItem(title: String, platform: SocialPlatform, scheduledAt: Date) async throws -> ContentPlanItem {
        let body = CreatePlanItemBody(
            title: title,
            platform: platform.rawValue,
            scheduledAt: ISO8601DateFormatter().string(from: scheduledAt)
        )
        let response: ContentPlanItemResponse = try await apiClient.request(
            endpoint: "planning/content-plan",
            method: .post,
            body: body,
            requiresAuth: true
        )
        return response.toDomain()
    }

    func updatePlanItem(id: UUID, title: String?, platform: SocialPlatform?, scheduledAt: Date?, status: ContentPlanItem.Status?) async throws -> ContentPlanItem {
        let body = UpdatePlanItemBody(
            title: title,
            platform: platform?.rawValue,
            scheduledAt: scheduledAt.map { ISO8601DateFormatter().string(from: $0) },
            status: status?.rawValue
        )
        let response: ContentPlanItemResponse = try await apiClient.request(
            endpoint: "planning/content-plan/\(id.uuidString)",
            method: .patch,
            body: body,
            requiresAuth: true
        )
        return response.toDomain()
    }

    func deletePlanItem(id: UUID) async throws {
        try await apiClient.requestVoid(
            endpoint: "planning/content-plan/\(id.uuidString)",
            method: .delete,
            requiresAuth: true
        )
    }

    func reorderPlanItems(ids: [UUID]) async throws {
        let body = ReorderPlanItemsBody(ids: ids.map { $0.uuidString })
        try await apiClient.requestVoid(
            endpoint: "planning/content-plan/reorder",
            method: .put,
            body: body,
            requiresAuth: true
        )
    }
}

enum ContentRepositoryProvider {
    static var shared = RepositoryProvider<ContentRepository>(
        dev: MockContentRepository(),
        api: APIContentRepository()
    )
}

private struct TemplateItemResponse: Decodable {
    let id: String?
    let title: String
    let imageName: String?
    let category: String
    let captionTemplate: String?
    let suggestedPlatforms: [String]?
    let contentKind: String?

    func toDomain() -> TemplateItem {
        let platforms: [SocialPlatform] = (suggestedPlatforms ?? []).compactMap {
            SocialPlatform(rawValue: $0)
        }
        let kind: ExportContentKind
        switch contentKind {
        case "video":
            kind = .video
        case "carousel":
            kind = .carousel
        case "textPost":
            kind = .textPost
        default:
            kind = .photo
        }

        return TemplateItem(
            id: UUID(uuidString: id ?? "") ?? UUID(),
            title: title,
            imageName: imageName ?? "jacket",
            category: category,
            captionTemplate: captionTemplate ?? "",
            suggestedPlatforms: platforms.isEmpty ? [.instagram] : platforms,
            contentKind: kind
        )
    }
}

// Uses shared EmptyBody from RepositoryProvider.swift

// MARK: - Planning Request Bodies

struct CreatePlanItemBody: Encodable {
    let title: String
    let platform: String
    let scheduledAt: String
}

struct UpdatePlanItemBody: Encodable {
    let title: String?
    let platform: String?
    let scheduledAt: String?
    let status: String?
}

struct ReorderPlanItemsBody: Encodable {
    let ids: [String]
}

// MARK: - Planning Response

private struct ContentPlanItemResponse: Decodable {
    let id: String?
    let title: String
    let platform: String
    let scheduledAt: String
    let status: String
    let sortOrder: Int?

    func toDomain() -> ContentPlanItem {
        let parsedDate = ISO8601DateFormatter().date(from: scheduledAt) ?? Date()
        let parsedPlatform = SocialPlatform(rawValue: platform) ?? .instagram
        let parsedStatus = ContentPlanItem.Status(rawValue: status) ?? .draft

        return ContentPlanItem(
            id: UUID(uuidString: id ?? "") ?? UUID(),
            title: title,
            platform: parsedPlatform,
            scheduledAt: parsedDate,
            status: parsedStatus,
            sortOrder: sortOrder ?? 0
        )
    }
}
