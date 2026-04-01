import Foundation
import Combine

/// Persists approved content from the For You feed.
/// Items are stored on disk as JSON so they survive app restarts.
final class ApprovedMediaLibraryStore: ObservableObject {
    static let shared = ApprovedMediaLibraryStore()

    @Published private(set) var approvedItems: [LibraryItem] = []
    @Published private(set) var savedTemplates: [TemplateItem] = []

    private let approvedKey = "envi_approved_library_items"
    private let templatesKey = "envi_saved_templates"
    private let fileManager = FileManager.default

    private init() {
        loadFromDisk()
    }

    // MARK: - Approve Content from Feed
    func approve(_ contentItem: ContentItem) {
        let libraryItem = LibraryItem(contentItem: contentItem)
        guard !approvedItems.contains(where: { $0.id == libraryItem.id }) else { return }
        approvedItems.insert(libraryItem, at: 0)
        saveToDisk()
    }

    // MARK: - Save Template
    func saveTemplate(_ template: TemplateItem) {
        guard !savedTemplates.contains(where: { $0.id == template.id }) else { return }
        savedTemplates.insert(template, at: 0)
        saveToDisk()
    }

    // MARK: - Remove Item
    func removeItem(id: String) {
        approvedItems.removeAll { $0.id == id }
        saveToDisk()
    }

    func removeTemplate(id: UUID) {
        savedTemplates.removeAll { $0.id == id }
        saveToDisk()
    }

    // MARK: - Persistence
    private var storageURL: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("approved_library.json")
    }

    private var templatesURL: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("saved_templates.json")
    }

    private func saveToDisk() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        if let data = try? encoder.encode(approvedItems) {
            try? data.write(to: storageURL, options: .atomic)
        }

        if let data = try? encoder.encode(savedTemplates) {
            try? data.write(to: templatesURL, options: .atomic)
        }
    }

    private func loadFromDisk() {
        if let data = try? Data(contentsOf: storageURL),
           let items = try? JSONDecoder().decode([LibraryItem].self, from: data) {
            approvedItems = items
        }

        if let data = try? Data(contentsOf: templatesURL),
           let templates = try? JSONDecoder().decode([TemplateItem].self, from: data) {
            savedTemplates = templates
        }
    }

    /// Clear all data (for sign-out)
    func clearAll() {
        approvedItems = []
        savedTemplates = []
        try? fileManager.removeItem(at: storageURL)
        try? fileManager.removeItem(at: templatesURL)
    }
}
