import Foundation
import Combine
import Photos

/// ViewModel powering the For You / Gallery dual-mode Tab 0.
///
/// Loads template-generated content pieces via `TemplateMatchEngine` +
/// `MediaClassifier`, manages approve/disapprove state, and feeds the
/// Gallery grid with approved items from `ApprovedMediaLibraryStore`.
@MainActor
final class ForYouGalleryViewModel: ObservableObject {

    // MARK: - Segment

    enum Segment: String, CaseIterable {
        case forYou = "FOR YOU"
        case gallery = "GALLERY"
    }

    // MARK: - Published State

    @Published var selectedSegment: Segment = .forYou
    @Published private(set) var forYouItems: [ContentItem] = []
    @Published private(set) var galleryItems: [LibraryItem] = []
    @Published private(set) var isLoading = false
    @Published var searchQuery: String = ""
    @Published var showSearch = false

    // MARK: - Dependencies

    private let approvedStore: ApprovedMediaLibraryStore
    private let repository: ContentRepository
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(
        approvedStore: ApprovedMediaLibraryStore = .shared,
        repository: ContentRepository = ContentRepositoryProvider.shared.repository
    ) {
        self.approvedStore = approvedStore
        self.repository = repository

        // Keep gallery in sync with approved store
        approvedStore.$approvedItems
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.galleryItems = items
            }
            .store(in: &cancellables)

        Task { await loadForYouContent() }
    }

    // MARK: - For You Actions

    func loadForYouContent() async {
        isLoading = true
        defer { isLoading = false }

        do {
            forYouItems = try await repository.fetchFeedItems()
        } catch {
            if AppEnvironment.current == .dev {
                forYouItems = ContentItem.mockFeed
            } else {
                forYouItems = []
            }
        }
    }

    func approve(_ item: ContentItem) {
        approvedStore.approve(item)
        removeFromForYou(item.id)
    }

    func disapprove(_ itemID: UUID) {
        removeFromForYou(itemID)
    }

    func bookmarkCard(id: UUID) {
        if let index = forYouItems.firstIndex(where: { $0.id == id }) {
            forYouItems[index].isBookmarked.toggle()
        }
    }

    // MARK: - Gallery

    var filteredGalleryItems: [LibraryItem] {
        guard !searchQuery.isEmpty else { return galleryItems }
        let query = searchQuery.lowercased()
        return galleryItems.filter { $0.title.lowercased().contains(query) }
    }

    // MARK: - Helpers

    private func removeFromForYou(_ id: UUID) {
        forYouItems.removeAll { $0.id == id }
    }
}
