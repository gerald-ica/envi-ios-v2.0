import Foundation

// MARK: - Protocol

protocol SearchRepository {
    func search(query: SearchQuery) async throws -> [SearchResult]
    func semanticSearch(text: String) async throws -> [SearchResult]
    func visualSimilaritySearch(assetID: UUID) async throws -> [SearchResult]

    func fetchSavedSearches() async throws -> [SavedSearch]
    func saveSearch(_ search: SavedSearch) async throws -> SavedSearch
    func deleteSavedSearch(id: UUID) async throws
    func toggleAlert(searchID: UUID, enabled: Bool) async throws -> SavedSearch

    func fetchFacets(for query: SearchQuery) async throws -> [SearchFacet]
    func fetchHiddenGems() async throws -> [HiddenGem]
    func fetchSeasonalResurfacing() async throws -> [SeasonalSuggestion]
}

// MARK: - Mock Implementation

final class MockSearchRepository: SearchRepository {
    private var savedSearches: [SavedSearch] = SavedSearch.mockSavedSearches

    func search(query: SearchQuery) async throws -> [SearchResult] {
        try await Task.sleep(nanoseconds: 300_000_000)
        let all = SearchResult.mockResults
        guard !query.text.isEmpty else { return all }
        let term = query.text.lowercased()
        let filtered = all.filter { $0.title.lowercased().contains(term) }
        return filtered.isEmpty ? all : filtered
    }

    func semanticSearch(text: String) async throws -> [SearchResult] {
        try await Task.sleep(nanoseconds: 400_000_000)
        return SearchResult.mockResults.shuffled()
    }

    func visualSimilaritySearch(assetID: UUID) async throws -> [SearchResult] {
        try await Task.sleep(nanoseconds: 400_000_000)
        return Array(SearchResult.mockResults.prefix(3))
    }

    func fetchSavedSearches() async throws -> [SavedSearch] {
        savedSearches
    }

    func saveSearch(_ search: SavedSearch) async throws -> SavedSearch {
        savedSearches.append(search)
        return search
    }

    func deleteSavedSearch(id: UUID) async throws {
        savedSearches.removeAll { $0.id == id }
    }

    func toggleAlert(searchID: UUID, enabled: Bool) async throws -> SavedSearch {
        guard let index = savedSearches.firstIndex(where: { $0.id == searchID }) else {
            throw NSError(domain: "MockSearchRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Saved search not found."])
        }
        savedSearches[index].alertEnabled = enabled
        return savedSearches[index]
    }

    func fetchFacets(for query: SearchQuery) async throws -> [SearchFacet] {
        SearchFacet.mockFacets
    }

    func fetchHiddenGems() async throws -> [HiddenGem] {
        try await Task.sleep(nanoseconds: 300_000_000)
        return HiddenGem.mockGems
    }

    func fetchSeasonalResurfacing() async throws -> [SeasonalSuggestion] {
        SeasonalSuggestion.mockSeasonal
    }
}

// MARK: - API Implementation

final class APISearchRepository: SearchRepository {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func search(query: SearchQuery) async throws -> [SearchResult] {
        try await apiClient.request(endpoint: "search/query", method: .post, body: query, requiresAuth: true)
    }

    func semanticSearch(text: String) async throws -> [SearchResult] {
        let body = SemanticSearchBody(text: text)
        return try await apiClient.request(endpoint: "search/semantic", method: .post, body: body, requiresAuth: true)
    }

    func visualSimilaritySearch(assetID: UUID) async throws -> [SearchResult] {
        let body = VisualSearchBody(assetID: assetID.uuidString)
        return try await apiClient.request(endpoint: "search/visual", method: .post, body: body, requiresAuth: true)
    }

    func fetchSavedSearches() async throws -> [SavedSearch] {
        try await apiClient.request(endpoint: "search/saved", method: .get, requiresAuth: true)
    }

    func saveSearch(_ search: SavedSearch) async throws -> SavedSearch {
        try await apiClient.request(endpoint: "search/saved", method: .post, body: search, requiresAuth: true)
    }

    func deleteSavedSearch(id: UUID) async throws {
        try await apiClient.requestVoid(endpoint: "search/saved/\(id.uuidString)", method: .delete, requiresAuth: true)
    }

    func toggleAlert(searchID: UUID, enabled: Bool) async throws -> SavedSearch {
        let body = ToggleAlertBody(alertEnabled: enabled)
        return try await apiClient.request(endpoint: "search/saved/\(searchID.uuidString)/alert", method: .patch, body: body, requiresAuth: true)
    }

    func fetchFacets(for query: SearchQuery) async throws -> [SearchFacet] {
        try await apiClient.request(endpoint: "search/facets", method: .post, body: query, requiresAuth: true)
    }

    func fetchHiddenGems() async throws -> [HiddenGem] {
        try await apiClient.request(endpoint: "search/gems", method: .get, requiresAuth: true)
    }

    func fetchSeasonalResurfacing() async throws -> [SeasonalSuggestion] {
        try await apiClient.request(endpoint: "search/seasonal", method: .get, requiresAuth: true)
    }
}

// MARK: - Provider

enum SearchRepositoryProvider {
    static var shared = RepositoryProvider<SearchRepository>(
        dev: MockSearchRepository(),
        api: APISearchRepository()
    )
}

// MARK: - Request Bodies

private struct SemanticSearchBody: Encodable {
    let text: String
}

private struct VisualSearchBody: Encodable {
    let assetID: String
}

private struct ToggleAlertBody: Encodable {
    let alertEnabled: Bool
}
