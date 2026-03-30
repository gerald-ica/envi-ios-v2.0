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
    @Published var items: [LibraryItem] = LibraryItem.mockItems
    @Published var templates: [TemplateItem] = TemplateItem.mockTemplates
    @Published var isLoading = false
    private var cancellables = Set<AnyCancellable>()

    init() {
        ApprovedMediaLibraryStore.shared.$approvedItems
            .receive(on: DispatchQueue.main)
            .sink { [weak self] approvedItems in
                self?.items = approvedItems
            }
            .store(in: &cancellables)
    }

    var filteredItems: [LibraryItem] {
        guard selectedFilter != .all else { return items }
        return items.filter { $0.type.rawValue == selectedFilter.rawValue }
    }

    var isEmpty: Bool {
        items.isEmpty
    }
}
