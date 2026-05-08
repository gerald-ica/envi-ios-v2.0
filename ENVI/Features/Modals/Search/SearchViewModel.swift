import SwiftUI
import Combine

/// ViewModel for the Search, Discovery, and Retrieval domain (D08).
@MainActor
final class SearchViewModel: ObservableObject {

    // MARK: - Published State

    @Published var query: SearchQuery = SearchQuery()
    @Published var results: [SearchResult] = []
    @Published var facets: [SearchFacet] = []
    @Published var savedSearches: [SavedSearch] = []
    @Published var hiddenGems: [HiddenGem] = []
    @Published var seasonalSuggestions: [SeasonalSuggestion] = []

    @Published var isSearching = false
    @Published var isLoadingSaved = false
    @Published var isLoadingGems = false

    @Published var errorMessage: String?

    // Filter builder state
    @Published var activeFilters: [SearchFilter] = []
    @Published var isShowingFilterBuilder = false
    @Published var isShowingSavedSearches = false

    private nonisolated(unsafe) let repository: SearchRepository
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(repository: SearchRepository = SearchRepositoryProvider.shared.repository) {
        self.repository = repository
        setupDebounce()
        Task {
            await loadSavedSearches()
        }
    }

    // MARK: - Debounced Search

    private func setupDebounce() {
        $query
            .debounce(for: .milliseconds(350), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] newQuery in
                guard let self, !newQuery.isEmpty else { return }
                self.performSearch(newQuery)
            }
            .store(in: &cancellables)
    }

    // MARK: - Search

    func performSearch(_ searchQuery: SearchQuery? = nil) {
        let q = searchQuery ?? query
        searchTask?.cancel()
        searchTask = Task { @MainActor in
            isSearching = true
            errorMessage = nil
            do {
                async let resultsReq = repository.search(query: q)
                async let facetsReq = repository.fetchFacets(for: q)
                let (r, f) = try await (resultsReq, facetsReq)
                results = r
                facets = f
            } catch {
                if !(error is CancellationError) {
                    errorMessage = error.localizedDescription
                }
            }
            isSearching = false
        }
    }

    func semanticSearch(_ text: String) {
        searchTask?.cancel()
        searchTask = Task { @MainActor in
            isSearching = true
            errorMessage = nil
            do {
                results = try await repository.semanticSearch(text: text)
            } catch {
                if !(error is CancellationError) {
                    errorMessage = error.localizedDescription
                }
            }
            isSearching = false
        }
    }

    func visualSimilaritySearch(assetID: UUID) {
        searchTask?.cancel()
        searchTask = Task { @MainActor in
            isSearching = true
            errorMessage = nil
            do {
                results = try await repository.visualSimilaritySearch(assetID: assetID)
            } catch {
                if !(error is CancellationError) {
                    errorMessage = error.localizedDescription
                }
            }
            isSearching = false
        }
    }

    // MARK: - Filters

    func addFilter(field: String, op: FilterOperator, value: String) {
        let filter = SearchFilter(field: field, op: op, value: value)
        activeFilters.append(filter)
        query.filters = activeFilters
    }

    func removeFilter(_ filter: SearchFilter) {
        activeFilters.removeAll { $0.id == filter.id }
        query.filters = activeFilters
    }

    func clearFilters() {
        activeFilters.removeAll()
        query.filters = []
    }

    // MARK: - Saved Searches

    @MainActor
    func loadSavedSearches() async {
        isLoadingSaved = true
        do {
            savedSearches = try await repository.fetchSavedSearches()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingSaved = false
    }

    func saveCurrentSearch(name: String) {
        Task { @MainActor in
            do {
                let saved = SavedSearch(name: name, query: query, alertEnabled: false)
                let result = try await repository.saveSearch(saved)
                savedSearches.append(result)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func deleteSavedSearch(_ search: SavedSearch) {
        Task { @MainActor in
            do {
                try await repository.deleteSavedSearch(id: search.id)
                savedSearches.removeAll { $0.id == search.id }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func toggleAlert(for search: SavedSearch) {
        Task { @MainActor in
            do {
                let updated = try await repository.toggleAlert(searchID: search.id, enabled: !search.alertEnabled)
                if let index = savedSearches.firstIndex(where: { $0.id == search.id }) {
                    savedSearches[index] = updated
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func applySavedSearch(_ search: SavedSearch) {
        query = search.query
        activeFilters = search.query.filters
        performSearch(search.query)
    }

    // MARK: - Hidden Gems & Seasonal

    @MainActor
    func loadHiddenGems() async {
        isLoadingGems = true
        do {
            async let gemsReq = repository.fetchHiddenGems()
            async let seasonalReq = repository.fetchSeasonalResurfacing()
            let (g, s) = try await (gemsReq, seasonalReq)
            hiddenGems = g
            seasonalSuggestions = s
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingGems = false
    }

    // MARK: - Sort

    func updateSort(_ option: SearchSortOption) {
        query.sortBy = option
        performSearch()
    }
}
