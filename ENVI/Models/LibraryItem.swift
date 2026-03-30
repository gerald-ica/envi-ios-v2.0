import SwiftUI

struct LibraryItem: Identifiable, Codable {
    let id: String
    let title: String
    let imageName: String
    let type: ItemType
    let height: CGFloat // For masonry layout

    enum ItemType: String, Codable {
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

struct TemplateItem: Identifiable, Codable {
    let id: UUID
    let title: String
    let imageName: String
    let category: String

    init(id: UUID = UUID(), title: String, imageName: String, category: String) {
        self.id = id
        self.title = title
        self.imageName = imageName
        self.category = category
    }

    static let mockTemplates: [TemplateItem] = [
        TemplateItem(title: "Minimal Story", imageName: "jacket", category: "Instagram"),
        TemplateItem(title: "Bold Reel", imageName: "industrial-girl", category: "TikTok"),
        TemplateItem(title: "Clean Post", imageName: "office-girl", category: "Instagram"),
    ]
}
