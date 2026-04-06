import Foundation

// MARK: - Protocol

protocol BrandKitRepository {
    func fetchBrandKits() async throws -> [BrandKit]
    func createBrandKit(_ kit: BrandKit) async throws -> BrandKit
    func updateBrandKit(_ kit: BrandKit) async throws
    func deleteBrandKit(id: UUID) async throws

    func fetchTemplates(brandKitID: UUID?) async throws -> [ContentTemplate]
    func createTemplate(_ template: ContentTemplate) async throws -> ContentTemplate
    func duplicateTemplate(id: UUID) async throws -> ContentTemplate
    func deleteTemplate(id: UUID) async throws

    func fetchCaptionStyleGuide(brandKitID: UUID) async throws -> CaptionStyleGuide
}

// MARK: - Mock Implementation

final class MockBrandKitRepository: BrandKitRepository {
    private var brandKits: [BrandKit] = BrandKit.mockList
    private var templates: [ContentTemplate] = ContentTemplate.mockList

    func fetchBrandKits() async throws -> [BrandKit] {
        brandKits
    }

    func createBrandKit(_ kit: BrandKit) async throws -> BrandKit {
        brandKits.insert(kit, at: 0)
        return kit
    }

    func updateBrandKit(_ kit: BrandKit) async throws {
        guard let index = brandKits.firstIndex(where: { $0.id == kit.id }) else {
            throw BrandKitError.notFound
        }
        brandKits[index] = kit
    }

    func deleteBrandKit(id: UUID) async throws {
        brandKits.removeAll { $0.id == id }
    }

    func fetchTemplates(brandKitID: UUID?) async throws -> [ContentTemplate] {
        guard let brandKitID else { return templates }
        return templates.filter { $0.brandKitID == brandKitID }
    }

    func createTemplate(_ template: ContentTemplate) async throws -> ContentTemplate {
        templates.insert(template, at: 0)
        return template
    }

    func duplicateTemplate(id: UUID) async throws -> ContentTemplate {
        guard let source = templates.first(where: { $0.id == id }) else {
            throw BrandKitError.notFound
        }
        let duplicate = ContentTemplate(
            name: "\(source.name) Copy",
            category: source.category,
            captionTemplate: source.captionTemplate,
            hashtagSets: source.hashtagSets,
            suggestedPlatforms: source.suggestedPlatforms,
            contentKind: source.contentKind,
            brandKitID: source.brandKitID,
            aspectRatio: source.aspectRatio,
            hookStyle: source.hookStyle,
            ctaStyle: source.ctaStyle
        )
        templates.insert(duplicate, at: 0)
        return duplicate
    }

    func deleteTemplate(id: UUID) async throws {
        templates.removeAll { $0.id == id }
    }

    func fetchCaptionStyleGuide(brandKitID: UUID) async throws -> CaptionStyleGuide {
        .mock
    }
}

// MARK: - API Implementation

final class APIBrandKitRepository: BrandKitRepository {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchBrandKits() async throws -> [BrandKit] {
        try await apiClient.request(
            endpoint: "brand-kits",
            method: .get,
            requiresAuth: true
        )
    }

    func createBrandKit(_ kit: BrandKit) async throws -> BrandKit {
        try await apiClient.request(
            endpoint: "brand-kits",
            method: .post,
            body: kit,
            requiresAuth: true
        )
    }

    func updateBrandKit(_ kit: BrandKit) async throws {
        try await apiClient.requestVoid(
            endpoint: "brand-kits/\(kit.id.uuidString)",
            method: .put,
            body: kit,
            requiresAuth: true
        )
    }

    func deleteBrandKit(id: UUID) async throws {
        try await apiClient.requestVoid(
            endpoint: "brand-kits/\(id.uuidString)",
            method: .delete,
            requiresAuth: true
        )
    }

    func fetchTemplates(brandKitID: UUID?) async throws -> [ContentTemplate] {
        var endpoint = "content-templates"
        if let brandKitID {
            endpoint += "?brandKitID=\(brandKitID.uuidString)"
        }
        return try await apiClient.request(
            endpoint: endpoint,
            method: .get,
            requiresAuth: true
        )
    }

    func createTemplate(_ template: ContentTemplate) async throws -> ContentTemplate {
        try await apiClient.request(
            endpoint: "content-templates",
            method: .post,
            body: template,
            requiresAuth: true
        )
    }

    func duplicateTemplate(id: UUID) async throws -> ContentTemplate {
        try await apiClient.request(
            endpoint: "content-templates/\(id.uuidString)/duplicate",
            method: .post,
            body: EmptyBrandKitBody(),
            requiresAuth: true
        )
    }

    func deleteTemplate(id: UUID) async throws {
        try await apiClient.requestVoid(
            endpoint: "content-templates/\(id.uuidString)",
            method: .delete,
            requiresAuth: true
        )
    }

    func fetchCaptionStyleGuide(brandKitID: UUID) async throws -> CaptionStyleGuide {
        try await apiClient.request(
            endpoint: "brand-kits/\(brandKitID.uuidString)/caption-style-guide",
            method: .get,
            requiresAuth: true
        )
    }
}

private struct EmptyBrandKitBody: Encodable {}

// MARK: - Error

enum BrandKitError: LocalizedError {
    case notFound

    var errorDescription: String? {
        switch self {
        case .notFound: return "The requested item was not found."
        }
    }
}

// MARK: - Provider

enum BrandKitRepositoryProvider {
    static var shared = Shared(repository: defaultRepository())

    struct Shared {
        var repository: BrandKitRepository
    }

    private static func defaultRepository() -> BrandKitRepository {
        switch AppEnvironment.current {
        case .dev:
            return MockBrandKitRepository()
        case .staging, .prod:
            return APIBrandKitRepository()
        }
    }
}
