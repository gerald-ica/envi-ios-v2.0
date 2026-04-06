import Foundation

// MARK: - Protocol

protocol IdeationRepository {
    func generateIdeas(prompt: String, platform: SocialPlatform, count: Int) async throws -> [ContentIdea]
    func fetchTrends(platform: SocialPlatform?) async throws -> [TrendTopic]
    func fetchCompetitorInsights(handle: String) async throws -> [CompetitorInsight]
    func exploreNicheKeywords(niche: String) async throws -> [NicheKeyword]
    func fetchIdeaBoards() async throws -> [IdeaBoard]
    func saveIdeaToBoard(ideaID: UUID, boardID: UUID) async throws
    func updateIdeaColumn(ideaID: UUID, boardID: UUID, column: IdeaBoardColumn) async throws
}

// MARK: - Mock Implementation

final class MockIdeationRepository: IdeationRepository {
    private var boards: [IdeaBoard] = IdeaBoard.mockList

    func generateIdeas(prompt: String, platform: SocialPlatform, count: Int) async throws -> [ContentIdea] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 800_000_000)
        return Array(ContentIdea.mockList.prefix(count)).map { idea in
            ContentIdea(
                title: idea.title,
                description: idea.description,
                platform: platform,
                format: idea.format,
                hookStyle: idea.hookStyle,
                estimatedEngagement: idea.estimatedEngagement,
                trendScore: idea.trendScore,
                source: .ai
            )
        }
    }

    func fetchTrends(platform: SocialPlatform?) async throws -> [TrendTopic] {
        guard let platform else { return TrendTopic.mockList }
        return TrendTopic.mockList.filter { $0.platforms.contains(platform) }
    }

    func fetchCompetitorInsights(handle: String) async throws -> [CompetitorInsight] {
        CompetitorInsight.mockList
    }

    func exploreNicheKeywords(niche: String) async throws -> [NicheKeyword] {
        NicheKeyword.mockList
    }

    func fetchIdeaBoards() async throws -> [IdeaBoard] {
        boards
    }

    func saveIdeaToBoard(ideaID: UUID, boardID: UUID) async throws {
        // In mock, no-op since ideas are already in boards
    }

    func updateIdeaColumn(ideaID: UUID, boardID: UUID, column: IdeaBoardColumn) async throws {
        guard let boardIndex = boards.firstIndex(where: { $0.id == boardID }),
              let ideaIndex = boards[boardIndex].ideas.firstIndex(where: { $0.id == ideaID }) else {
            throw IdeationError.notFound
        }
        boards[boardIndex].ideas[ideaIndex].boardColumn = column
    }
}

// MARK: - API Implementation

final class APIIdeationRepository: IdeationRepository {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func generateIdeas(prompt: String, platform: SocialPlatform, count: Int) async throws -> [ContentIdea] {
        let body = IdeaGenerationRequest(prompt: prompt, platform: platform, count: count)
        return try await apiClient.request(
            endpoint: "ai/ideation/generate",
            method: .post,
            body: body,
            requiresAuth: true
        )
    }

    func fetchTrends(platform: SocialPlatform?) async throws -> [TrendTopic] {
        var endpoint = "ai/trends"
        if let platform {
            endpoint += "?platform=\(platform.apiSlug)"
        }
        return try await apiClient.request(
            endpoint: endpoint,
            method: .get,
            requiresAuth: true
        )
    }

    func fetchCompetitorInsights(handle: String) async throws -> [CompetitorInsight] {
        try await apiClient.request(
            endpoint: "ai/competitors?handle=\(handle)",
            method: .get,
            requiresAuth: true
        )
    }

    func exploreNicheKeywords(niche: String) async throws -> [NicheKeyword] {
        let encoded = niche.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? niche
        return try await apiClient.request(
            endpoint: "ai/keywords?niche=\(encoded)",
            method: .get,
            requiresAuth: true
        )
    }

    func fetchIdeaBoards() async throws -> [IdeaBoard] {
        try await apiClient.request(
            endpoint: "ai/boards",
            method: .get,
            requiresAuth: true
        )
    }

    func saveIdeaToBoard(ideaID: UUID, boardID: UUID) async throws {
        try await apiClient.requestVoid(
            endpoint: "ai/boards/\(boardID.uuidString)/ideas/\(ideaID.uuidString)",
            method: .post,
            body: EmptyIdeationBody(),
            requiresAuth: true
        )
    }

    func updateIdeaColumn(ideaID: UUID, boardID: UUID, column: IdeaBoardColumn) async throws {
        try await apiClient.requestVoid(
            endpoint: "ai/boards/\(boardID.uuidString)/ideas/\(ideaID.uuidString)/column",
            method: .put,
            body: IdeaColumnUpdate(column: column),
            requiresAuth: true
        )
    }
}

private struct EmptyIdeationBody: Encodable {}

private struct IdeaColumnUpdate: Encodable {
    let column: IdeaBoardColumn
}

// MARK: - Error

enum IdeationError: LocalizedError {
    case notFound
    case generationFailed

    var errorDescription: String? {
        switch self {
        case .notFound: return "The requested item was not found."
        case .generationFailed: return "Failed to generate ideas. Please try again."
        }
    }
}

// MARK: - Provider

enum IdeationRepositoryProvider {
    static var shared = Shared(repository: defaultRepository())

    struct Shared {
        var repository: IdeationRepository
    }

    private static func defaultRepository() -> IdeationRepository {
        switch AppEnvironment.current {
        case .dev:
            return MockIdeationRepository()
        case .staging, .prod:
            return APIIdeationRepository()
        }
    }
}
