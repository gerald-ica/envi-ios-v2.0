import Foundation
import Combine

/// Shared store for approved For You posts that should appear in the Library tab.
/// Persists approved items to UserDefaults via Codable serialization so they
/// survive app restarts. The @Published `approvedItems` property remains reactive.
final class ApprovedMediaLibraryStore: ObservableObject {
    nonisolated(unsafe) static let shared = ApprovedMediaLibraryStore()

    private static let userDefaultsKey = "ApprovedMediaLibraryStore.approvedItems"

    @Published private(set) var approvedItems: [LibraryItem] = [] {
        didSet { persistToUserDefaults() }
    }

    private init() {
        loadFromUserDefaults()
    }

    func approve(_ contentItem: ContentItem) {
        let libraryItem = LibraryItem(contentItem: contentItem)
        guard approvedItems.contains(where: { $0.id == libraryItem.id }) == false else { return }
        approvedItems.insert(libraryItem, at: 0)
    }

    /// Remove a previously-approved item (e.g. undo).
    func removeItem(id: String) {
        approvedItems.removeAll { $0.id == id }
    }

    /// Whether a given content item has already been approved.
    func isApproved(contentItemID: UUID) -> Bool {
        approvedItems.contains { $0.id == contentItemID.uuidString }
    }

    // MARK: - Persistence

    private func persistToUserDefaults() {
        do {
            let data = try JSONEncoder().encode(approvedItems)
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        } catch {
            assertionFailure("Failed to encode approved items: \(error)")
        }
    }

    private func loadFromUserDefaults() {
        guard let data = UserDefaults.standard.data(forKey: Self.userDefaultsKey) else { return }
        do {
            approvedItems = try JSONDecoder().decode([LibraryItem].self, from: data)
        } catch {
            assertionFailure("Failed to decode approved items: \(error)")
        }
    }
}
