import Foundation
import Combine

/// Shared in-memory store for approved For You posts that should appear in the Library tab.
final class ApprovedMediaLibraryStore: ObservableObject {
    static let shared = ApprovedMediaLibraryStore()

    @Published private(set) var approvedItems: [LibraryItem] = []

    private init() {}

    func approve(_ contentItem: ContentItem) {
        let libraryItem = LibraryItem(contentItem: contentItem)
        guard approvedItems.contains(where: { $0.id == libraryItem.id }) == false else { return }
        approvedItems.insert(libraryItem, at: 0)
    }
}
