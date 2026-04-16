import Foundation
import SwiftUI

/// Represents a social media platform.
enum SocialPlatform: String, CaseIterable, Codable, Identifiable {
    case instagram = "Instagram"
    case facebook  = "Facebook"
    case tiktok    = "TikTok"
    case x         = "X"
    case threads   = "Threads"
    case linkedin  = "LinkedIn"
    case youtube   = "YouTube"

    var id: String { rawValue }

    /// Lowercase slug used in API endpoint paths (e.g. `oauth/instagram/connect`).
    var apiSlug: String { rawValue.lowercased() }

    var iconName: String {
        switch self {
        case .instagram: return "camera"
        case .facebook:  return "f.square"
        case .tiktok:    return "music.note"
        case .x:         return "xmark"
        case .threads:   return "at"
        case .linkedin:  return "link"
        case .youtube:   return "play.rectangle"
        }
    }

    var brandColor: Color {
        switch self {
        case .instagram: return Color(hex: "#E4405F")
        case .facebook:  return Color(hex: "#1877F2")
        case .tiktok:    return Color(hex: "#000000")
        case .x:         return Color(hex: "#1DA1F2")
        case .threads:   return Color(hex: "#000000")
        case .linkedin:  return Color(hex: "#0A66C2")
        case .youtube:   return Color(hex: "#FF0000")
        }
    }
}

/// Connection state for a platform account.
struct PlatformConnection: Identifiable, Codable {
    let id: UUID
    let platform: SocialPlatform
    var isConnected: Bool
    var handle: String?
    var followerCount: Int?
    var tokenExpiresAt: Date?
    var lastRefreshedAt: Date?
    var scopes: [String]

    /// Whether the token expires within the next 7 days.
    var isTokenExpiringSoon: Bool {
        guard let expiresAt = tokenExpiresAt else { return false }
        let sevenDays = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return expiresAt <= sevenDays
    }

    init(
        platform: SocialPlatform,
        isConnected: Bool = false,
        handle: String? = nil,
        followerCount: Int? = nil,
        tokenExpiresAt: Date? = nil,
        lastRefreshedAt: Date? = nil,
        scopes: [String] = []
    ) {
        self.id = UUID()
        self.platform = platform
        self.isConnected = isConnected
        self.handle = handle
        self.followerCount = followerCount
        self.tokenExpiresAt = tokenExpiresAt
        self.lastRefreshedAt = lastRefreshedAt
        self.scopes = scopes
    }
}
