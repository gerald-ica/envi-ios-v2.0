import SwiftUI
import Combine

/// ViewModel for the feed screen. Manages the card stack data.
final class FeedViewModel: ObservableObject {
    @Published var items: [ContentItem] = ContentItem.mockFeed
    @Published var selectedTab: FeedTab = .forYou
    @Published var isLoading = false
    @Published var error: String?

    enum FeedTab: String, CaseIterable {
        case forYou = "For You"
        case explore = "Explore"
    }

    var visibleItems: [ContentItem] {
        switch selectedTab {
        case .forYou:
            return items
        case .explore:
            return [] // Explore feed not yet populated
        }
    }

    // MARK: - Async Loading

    /// Load the feed from the API, falling back to mock data during development.
    func loadFeed() async {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }

        do {
            let feedItems: [ContentItem] = try await APIClient.shared.get("/feed")
            await MainActor.run { self.items = feedItems }
        } catch {
            // Fall back to mock data while backend is unavailable
            await MainActor.run {
                self.items = ContentItem.mockFeed
                // Don't surface error for mock fallback during development
            }
        }
    }

    /// Pull-to-refresh handler.
    func refreshFeed() async {
        await loadFeed()
    }

    // MARK: - Actions

    func bookmarkCard(id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].isBookmarked.toggle()
        }
    }

    func removeCard(id: UUID) {
        items.removeAll { $0.id == id }
    }

    // Available bundled image names for feed cards
    static let imageNames = [
        "Closer", "chopsticks", "culture-food", "cyclist", "desert-car",
        "fashion-group", "fire-stunt", "industrial-girl", "jacket",
        "office-girl", "parking-garage", "red-silhouette", "runway",
        "studio-fashion", "subway", "suit-phone", "tennis"
    ]
}
