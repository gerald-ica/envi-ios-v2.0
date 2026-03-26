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

    var filteredItems: [LibraryItem] {
        guard selectedFilter != .all else { return items }
        return items.filter { $0.type.rawValue == selectedFilter.rawValue }
    }
}

struct LibraryItem: Identifiable {
    let id = UUID()
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
