import Foundation

// MARK: - Protocol

protocol MetadataRepository {
    func fetchTags() async throws -> [Tag]
    func createTag(_ tag: Tag) async throws -> Tag
    func updateTag(_ tag: Tag) async throws
    func deleteTag(id: UUID) async throws
    func autoGenerateTags(assetID: UUID) async throws -> [TagSuggestion]
    func fetchSuggestions(query: String) async throws -> [TagSuggestion]
    func fetchCompleteness(assetID: UUID) async throws -> ContentMetadata
    func fetchTopicClusters() async throws -> [TopicCluster]
    func batchUpdateTags(assetID: UUID, tags: [Tag]) async throws -> ContentMetadata
}

// MARK: - Mock Implementation

final class MockMetadataRepository: MetadataRepository {
    private var tags: [Tag] = Tag.mockList

    func fetchTags() async throws -> [Tag] {
        tags.sorted { $0.usageCount > $1.usageCount }
    }

    func createTag(_ tag: Tag) async throws -> Tag {
        tags.insert(tag, at: 0)
        return tag
    }

    func updateTag(_ tag: Tag) async throws {
        guard let index = tags.firstIndex(where: { $0.id == tag.id }) else {
            throw MetadataError.notFound
        }
        tags[index] = tag
    }

    func deleteTag(id: UUID) async throws {
        tags.removeAll { $0.id == id }
    }

    func autoGenerateTags(assetID: UUID) async throws -> [TagSuggestion] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 800_000_000)
        return TagSuggestion.mockList
    }

    func fetchSuggestions(query: String) async throws -> [TagSuggestion] {
        let filtered = tags.filter { $0.name.localizedCaseInsensitiveContains(query) }
        return filtered.map { TagSuggestion(tag: $0, confidence: 0.8, source: .history) }
    }

    func fetchCompleteness(assetID: UUID) async throws -> ContentMetadata {
        .mock
    }

    func fetchTopicClusters() async throws -> [TopicCluster] {
        TopicCluster.mockList
    }

    func batchUpdateTags(assetID: UUID, tags: [Tag]) async throws -> ContentMetadata {
        ContentMetadata(assetID: assetID, tags: tags, completenessScore: Double(tags.count) / 10.0)
    }
}

// MARK: - API Implementation

final class APIMetadataRepository: MetadataRepository {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchTags() async throws -> [Tag] {
        try await apiClient.request(
            endpoint: "metadata/tags",
            method: .get,
            requiresAuth: true
        )
    }

    func createTag(_ tag: Tag) async throws -> Tag {
        try await apiClient.request(
            endpoint: "metadata/tags",
            method: .post,
            body: tag,
            requiresAuth: true
        )
    }

    func updateTag(_ tag: Tag) async throws {
        try await apiClient.requestVoid(
            endpoint: "metadata/tags/\(tag.id.uuidString)",
            method: .put,
            body: tag,
            requiresAuth: true
        )
    }

    func deleteTag(id: UUID) async throws {
        try await apiClient.requestVoid(
            endpoint: "metadata/tags/\(id.uuidString)",
            method: .delete,
            requiresAuth: true
        )
    }

    func autoGenerateTags(assetID: UUID) async throws -> [TagSuggestion] {
        try await apiClient.request(
            endpoint: "metadata/auto-generate",
            method: .post,
            body: AssetIDBody(assetID: assetID),
            requiresAuth: true
        )
    }

    func fetchSuggestions(query: String) async throws -> [TagSuggestion] {
        try await apiClient.request(
            endpoint: "metadata/suggestions?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)",
            method: .get,
            requiresAuth: true
        )
    }

    func fetchCompleteness(assetID: UUID) async throws -> ContentMetadata {
        try await apiClient.request(
            endpoint: "metadata/completeness/\(assetID.uuidString)",
            method: .get,
            requiresAuth: true
        )
    }

    func fetchTopicClusters() async throws -> [TopicCluster] {
        try await apiClient.request(
            endpoint: "metadata/clusters",
            method: .get,
            requiresAuth: true
        )
    }

    func batchUpdateTags(assetID: UUID, tags: [Tag]) async throws -> ContentMetadata {
        try await apiClient.request(
            endpoint: "metadata/tags/batch",
            method: .put,
            body: BatchTagsBody(assetID: assetID, tags: tags),
            requiresAuth: true
        )
    }
}

// MARK: - Request Bodies

private struct AssetIDBody: Encodable {
    let assetID: UUID
}

private struct BatchTagsBody: Encodable {
    let assetID: UUID
    let tags: [Tag]
}

// MARK: - Error

enum MetadataError: LocalizedError {
    case notFound
    case autoGenerateFailed

    var errorDescription: String? {
        switch self {
        case .notFound:            return "The requested metadata item was not found."
        case .autoGenerateFailed:  return "Auto-tag generation failed. Try again."
        }
    }
}

// MARK: - Provider

enum MetadataRepositoryProvider {
    static var shared = RepositoryProvider<MetadataRepository>(
        dev: MockMetadataRepository(),
        api: APIMetadataRepository()
    )
}
