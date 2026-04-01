import SwiftUI
import Combine

/// ViewModel for the Library screen.
final class LibraryViewModel: ObservableObject {
    enum FilterType: String, CaseIterable {
        case all = "All"
        case photos = "Photos"
        case videos = "Videos"
        case templates = "Templates"
        case drafts = "Drafts"
    }

    @Published var selectedFilter: FilterType = .all
    @Published var items: [LibraryItem] = []
    @Published var templates: [TemplateItem] = []
    @Published var isLoading = false
    @Published var error: String?
    private var cancellables = Set<AnyCancellable>()

    init() {
        let store = ApprovedMediaLibraryStore.shared

        store.$approvedItems
            .receive(on: DispatchQueue.main)
            .sink { [weak self] approvedItems in
                self?.items = approvedItems
            }
            .store(in: &cancellables)

        store.$savedTemplates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] savedTemplates in
                self?.templates = savedTemplates
            }
            .store(in: &cancellables)
    }

    var hasContent: Bool {
        !items.isEmpty || !templates.isEmpty
    }

    var filteredItems: [LibraryItem] {
        guard selectedFilter != .all else { return items }
        return items.filter { $0.type.rawValue == selectedFilter.rawValue }
    }

    var isEmpty: Bool {
        items.isEmpty
    }

    // MARK: - Async Loading

    /// Load library items from the API, falling back to local store data.
    func loadLibrary() async {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }

        do {
            let libraryItems: [LibraryItem] = try await APIClient.shared.get("/library")
            let templateItems: [TemplateItem] = try await APIClient.shared.get("/library/templates")
            await MainActor.run {
                self.items = libraryItems
                self.templates = templateItems
            }
        } catch {
            // Fall back to local ApprovedMediaLibraryStore data
            await MainActor.run {
                self.items = ApprovedMediaLibraryStore.shared.approvedItems
                self.templates = ApprovedMediaLibraryStore.shared.savedTemplates
                // Don't surface error for mock fallback during development
            }
        }
    }

    /// Pull-to-refresh handler.
    func refresh() async {
        await loadLibrary()
    }
}
