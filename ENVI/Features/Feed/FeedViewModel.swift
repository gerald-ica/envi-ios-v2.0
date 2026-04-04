import SwiftUI
import Combine

/// ViewModel for the feed screen. Manages the card stack data.
final class FeedViewModel: ObservableObject {
    @Published var items: [ContentItem] = []
    @Published var selectedTab: FeedTab = .forYou
    @Published var expandedItemID: UUID?
    @Published var showSearch = false

    private let repository: ContentRepository

    enum FeedTab: String, CaseIterable {
        case forYou = "For You"
        case explore = "Explore"
    }

    init(repository: ContentRepository = ContentRepositoryProvider.shared.contentRepository) {
        self.repository = repository
        Task { await reloadFeed() }
    }

    var visibleItems: [ContentItem] {
        items
    }

    func bookmarkCard(id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].isBookmarked.toggle()
        }
    }

    func toggleExpanded(id: UUID) {
        expandedItemID = expandedItemID == id ? nil : id
    }

    func removeCard(id: UUID) {
        items.removeAll { $0.id == id }
        if expandedItemID == id {
            expandedItemID = nil
        }
    }

    func resetFeed() {
        expandedItemID = nil
    }

    @MainActor
    func reloadFeed() async {
        do {
            items = try await repository.fetchFeedItems()
        } catch {
            items = ContentItem.mockFeed
        }
    }

    // Available bundled image names for feed cards
    static let imageNames = [
        "Closer", "chopsticks", "culture-food", "cyclist", "desert-car",
        "fashion-group", "fire-stunt", "industrial-girl", "jacket",
        "office-girl", "parking-garage", "red-silhouette", "runway",
        "studio-fashion", "subway", "suit-phone", "tennis"
    ]
}
