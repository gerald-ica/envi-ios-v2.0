import SwiftUI
import Combine

/// ViewModel for the feed screen. Manages the card stack data.
final class FeedViewModel: ObservableObject {
    @Published var items: [ContentItem] = ContentItem.mockFeed
    @Published var currentIndex: Int = 0
    @Published var selectedTab: FeedTab = .forYou
    @Published var showSearch = false

    enum FeedTab: String, CaseIterable {
        case forYou = "For You"
        case explore = "Explore"
    }

    var currentItem: ContentItem? {
        guard currentIndex < items.count else { return nil }
        return items[currentIndex]
    }

    var remainingCards: [ContentItem] {
        guard currentIndex < items.count else { return [] }
        return Array(items[currentIndex..<min(currentIndex + 3, items.count)])
    }

    func approveCard() {
        guard currentIndex < items.count else { return }
        currentIndex += 1
    }

    func passCard() {
        guard currentIndex < items.count else { return }
        currentIndex += 1
    }

    func bookmarkCard(id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].isBookmarked.toggle()
        }
    }

    func resetFeed() {
        currentIndex = 0
    }

    // Available bundled image names for feed cards
    static let imageNames = [
        "Closer", "chopsticks", "culture-food", "cyclist", "desert-car",
        "fashion-group", "fire-stunt", "industrial-girl", "jacket",
        "office-girl", "parking-garage", "red-silhouette", "runway",
        "studio-fashion", "subway", "suit-phone", "tennis"
    ]
}
