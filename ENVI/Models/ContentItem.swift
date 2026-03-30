import Foundation

/// Represents a content card in the feed.
struct ContentItem: Identifiable {
    let id: UUID
    let type: ContentType
    let creatorName: String
    let creatorHandle: String
    let creatorAvatar: String?
    let platform: SocialPlatform
    let imageName: String?       // bundled image name
    let caption: String
    let bodyText: String?
    let timestamp: Date

    // AI Insights
    let confidenceScore: Double  // 0.0–1.0
    let bestTime: String
    let estimatedReach: String

    // Engagement
    let likes: Int
    let comments: Int
    let shares: Int

    var isBookmarked: Bool = false

    enum ContentType: String {
        case photo
        case video
        case carousel
        case textPost
    }

    // MARK: - Mock Data
    static let mockFeed: [ContentItem] = [
        ContentItem(
            id: UUID(uuidString: "00000000-0001-0000-0000-000000000001")!, type: .photo,
            creatorName: "Sarah Chen", creatorHandle: "@sarahcreates",
            creatorAvatar: nil, platform: .instagram,
            imageName: "Closer", caption: "Golden hour hits different in the desert",
            bodyText: nil, timestamp: Date(),
            confidenceScore: 0.92, bestTime: "6:00 PM", estimatedReach: "45.2K",
            likes: 12400, comments: 342, shares: 891
        ),
        ContentItem(
            id: UUID(uuidString: "00000000-0001-0000-0000-000000000002")!, type: .photo,
            creatorName: "Marcus Cole", creatorHandle: "@marcuseats",
            creatorAvatar: nil, platform: .tiktok,
            imageName: "culture-food", caption: "Street food series — Episode 12: Bangkok",
            bodyText: nil, timestamp: Date().addingTimeInterval(-3600),
            confidenceScore: 0.88, bestTime: "12:00 PM", estimatedReach: "32.1K",
            likes: 8900, comments: 567, shares: 1200
        ),
        ContentItem(
            id: UUID(uuidString: "00000000-0001-0000-0000-000000000003")!, type: .photo,
            creatorName: "Mia Torres", creatorHandle: "@miatorres",
            creatorAvatar: nil, platform: .instagram,
            imageName: "cyclist", caption: "Morning ride through the city",
            bodyText: nil, timestamp: Date().addingTimeInterval(-7200),
            confidenceScore: 0.95, bestTime: "8:00 AM", estimatedReach: "67.8K",
            likes: 15600, comments: 890, shares: 2100
        ),
        ContentItem(
            id: UUID(uuidString: "00000000-0001-0000-0000-000000000004")!, type: .photo,
            creatorName: "Jordan Lee", creatorHandle: "@jordanlee",
            creatorAvatar: nil, platform: .youtube,
            imageName: "desert-car", caption: "Road trip vibes — Nevada to Arizona",
            bodyText: nil, timestamp: Date().addingTimeInterval(-10800),
            confidenceScore: 0.78, bestTime: "3:00 PM", estimatedReach: "21.5K",
            likes: 5600, comments: 234, shares: 567
        ),
        ContentItem(
            id: UUID(uuidString: "00000000-0001-0000-0000-000000000005")!, type: .photo,
            creatorName: "Nina Park", creatorHandle: "@ninapark",
            creatorAvatar: nil, platform: .instagram,
            imageName: "fashion-group", caption: "Squad goals at NYFW",
            bodyText: nil, timestamp: Date().addingTimeInterval(-14400),
            confidenceScore: 0.91, bestTime: "7:00 PM", estimatedReach: "54.3K",
            likes: 18900, comments: 1200, shares: 3400
        ),
        ContentItem(
            id: UUID(uuidString: "00000000-0001-0000-0000-000000000006")!, type: .textPost,
            creatorName: "Dev Patel", creatorHandle: "@devbuilds",
            creatorAvatar: nil, platform: .x,
            imageName: nil,
            caption: "Hot take: The best content strategy is authenticity.",
            bodyText: "I've been creating content for 5 years now, and the one thing that consistently outperforms everything else is just being real. No filters, no scripts. Just genuine thoughts and experiences. The algorithm rewards authenticity because people engage with it more.",
            timestamp: Date().addingTimeInterval(-18000),
            confidenceScore: 0.85, bestTime: "9:00 AM", estimatedReach: "28.7K",
            likes: 4500, comments: 678, shares: 1890
        ),
        ContentItem(
            id: UUID(uuidString: "00000000-0001-0000-0000-000000000007")!, type: .textPost,
            creatorName: "Maya Chen", creatorHandle: "@mayacreates",
            creatorAvatar: nil, platform: .threads,
            imageName: nil,
            caption: "Creative process thread",
            bodyText: "Thread idea: 1) The original raw footage. 2) Why the first cut did not work. 3) The pacing changes that lifted completion rate. 4) The final export and what I would still refine next time.",
            timestamp: Date().addingTimeInterval(-19800),
            confidenceScore: 0.9, bestTime: "7:30 PM", estimatedReach: "34.8K",
            likes: 5900, comments: 402, shares: 1280
        ),
        ContentItem(
            id: UUID(uuidString: "00000000-0001-0000-0000-000000000008")!, type: .photo,
            creatorName: "Kai Nakamura", creatorHandle: "@kainakamura",
            creatorAvatar: nil, platform: .instagram,
            imageName: "fire-stunt", caption: "Behind the scenes of our latest shoot",
            bodyText: nil, timestamp: Date().addingTimeInterval(-21600),
            confidenceScore: 0.87, bestTime: "5:00 PM", estimatedReach: "38.9K",
            likes: 9800, comments: 456, shares: 1100
        ),
        ContentItem(
            id: UUID(uuidString: "00000000-0001-0000-0000-000000000009")!, type: .photo,
            creatorName: "Ava Williams", creatorHandle: "@avawilliams",
            creatorAvatar: nil, platform: .tiktok,
            imageName: "industrial-girl", caption: "Industrial aesthetics",
            bodyText: nil, timestamp: Date().addingTimeInterval(-25200),
            confidenceScore: 0.93, bestTime: "4:00 PM", estimatedReach: "72.1K",
            likes: 22300, comments: 1500, shares: 4200
        ),
        ContentItem(
            id: UUID(uuidString: "00000000-0001-0000-0000-00000000000A")!, type: .photo,
            creatorName: "Liam O'Brien", creatorHandle: "@liamobrien",
            creatorAvatar: nil, platform: .instagram,
            imageName: "runway", caption: "Milan Fashion Week highlights",
            bodyText: nil, timestamp: Date().addingTimeInterval(-28800),
            confidenceScore: 0.89, bestTime: "1:00 PM", estimatedReach: "41.6K",
            likes: 11200, comments: 780, shares: 1900
        ),
        ContentItem(
            id: UUID(uuidString: "00000000-0001-0000-0000-00000000000B")!, type: .photo,
            creatorName: "Zara Ahmed", creatorHandle: "@zaraahmed",
            creatorAvatar: nil, platform: .instagram,
            imageName: "studio-fashion", caption: "Studio session with the team",
            bodyText: nil, timestamp: Date().addingTimeInterval(-32400),
            confidenceScore: 0.86, bestTime: "2:00 PM", estimatedReach: "35.4K",
            likes: 8700, comments: 345, shares: 890
        ),
    ]
}
