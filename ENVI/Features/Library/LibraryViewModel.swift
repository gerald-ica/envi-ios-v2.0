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
    @Published var searchQuery: String = ""
    @Published var items: [LibraryItem] = []
    @Published var templates: [TemplateItem] = TemplateItem.mockTemplates
    @Published var isLoading = false
    @Published var loadErrorMessage: String?
    private var cancellables = Set<AnyCancellable>()
    private let repository: ContentRepository

    init(repository: ContentRepository = ContentRepositoryProvider.shared.contentRepository) {
        self.repository = repository
        ApprovedMediaLibraryStore.shared.$approvedItems
            .receive(on: DispatchQueue.main)
            .sink { [weak self] approvedItems in
                self?.mergeApprovedItems(approvedItems)
            }
            .store(in: &cancellables)

        Task { await reloadLibrary() }
    }

    var filteredItems: [LibraryItem] {
        let base: [LibraryItem]
        if selectedFilter == .all {
            base = items
        } else {
            base = items.filter { $0.type.rawValue == selectedFilter.rawValue }
        }

        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return base }

        return base.filter { item in
            item.title.localizedCaseInsensitiveContains(query) ||
                item.type.rawValue.localizedCaseInsensitiveContains(query)
        }
    }

    @MainActor
    func reloadLibrary() async {
        isLoading = true
        loadErrorMessage = nil

        do {
            let contentItems = try await repository.fetchLibraryItems()
            let mapped = contentItems.map(LibraryItem.init(contentItem:))
            items = mapped
        } catch {
            if AppEnvironment.current == .dev {
                items = LibraryItem.mockItems
            } else {
                items = []
                loadErrorMessage = "Unable to load library content."
            }
        }

        isLoading = false
    }

    private func mergeApprovedItems(_ approvedItems: [LibraryItem]) {
        let nonApproved = items.filter { item in
            !approvedItems.contains(where: { $0.id == item.id })
        }
        items = approvedItems + nonApproved
    }
}

struct LibraryItem: Identifiable {
    let id: String
    let title: String
    let imageName: String
    let type: ItemType
    let height: CGFloat // For masonry layout

    enum ItemType: String {
        case photos = "Photos"
        case videos = "Videos"
        case templates = "Templates"
        case drafts = "Drafts"
    }

    init(id: String = UUID().uuidString, title: String, imageName: String, type: ItemType, height: CGFloat) {
        self.id = id
        self.title = title
        self.imageName = imageName
        self.type = type
        self.height = height
    }

    init(contentItem: ContentItem) {
        id = contentItem.id.uuidString
        title = contentItem.caption
        imageName = contentItem.imageName ?? LibraryItem.fallbackImageName(for: contentItem.platform)

        switch contentItem.type {
        case .photo:
            type = .photos
            height = 240
        case .video:
            type = .videos
            height = 240
        case .carousel:
            type = .photos
            height = 260
        case .textPost:
            type = .drafts
            height = 220
        }
    }

    private static func fallbackImageName(for platform: SocialPlatform) -> String {
        switch platform {
        case .instagram: return "studio-fashion"
        case .tiktok: return "industrial-girl"
        case .x: return "red-silhouette"
        case .threads: return "fashion-group"
        case .linkedin: return "office-girl"
        case .youtube: return "fire-stunt"
        }
    }

    static let mockItems: [LibraryItem] = [
        LibraryItem(title: "Desert Road", imageName: "desert-car", type: .photos, height: 200),
        LibraryItem(title: "Street Style", imageName: "fashion-group", type: .photos, height: 260),
        LibraryItem(title: "Urban Ride", imageName: "cyclist", type: .photos, height: 180),
        LibraryItem(title: "Studio Session", imageName: "studio-fashion", type: .photos, height: 240),
        LibraryItem(title: "Fire BTS", imageName: "fire-stunt", type: .videos, height: 220),
        LibraryItem(title: "Subway", imageName: "subway", type: .photos, height: 200),
        LibraryItem(title: "Runway", imageName: "runway", type: .photos, height: 260),
        LibraryItem(title: "Red Light", imageName: "red-silhouette", type: .photos, height: 230),
    ]
}

struct TemplateItem: Identifiable {
    let id = UUID()
    let title: String
    let imageName: String
    let category: String

    static let mockTemplates: [TemplateItem] = [
        TemplateItem(title: "Minimal Story", imageName: "jacket", category: "Instagram"),
        TemplateItem(title: "Bold Reel", imageName: "industrial-girl", category: "TikTok"),
        TemplateItem(title: "Clean Post", imageName: "office-girl", category: "Instagram"),
    ]
}
