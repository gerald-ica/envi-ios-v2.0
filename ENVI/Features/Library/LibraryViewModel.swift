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
    private var cancellables = Set<AnyCancellable>()

    var isEmpty: Bool { items.isEmpty && templates.isEmpty }

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
            .sink { [weak self] templates in
                self?.templates = templates
            }
            .store(in: &cancellables)
    }

    var filteredItems: [LibraryItem] {
        guard selectedFilter != .all else { return items }
        return items.filter { $0.type.rawValue == selectedFilter.rawValue }
    }
}
