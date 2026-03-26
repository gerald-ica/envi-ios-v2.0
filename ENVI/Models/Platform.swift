import Foundation
import SwiftUI

/// Represents a social media platform.
enum SocialPlatform: String, CaseIterable, Codable, Identifiable {
    case instagram = "Instagram"
    case tiktok    = "TikTok"
    case x         = "X"
    case threads   = "Threads"
    case linkedin  = "LinkedIn"
    case youtube   = "YouTube"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .instagram: return "camera.fill"
        case .tiktok:    return "music.note"
        case .x:         return "xmark"
        case .threads:   return "at"
        case .linkedin:  return "link"
        case .youtube:   return "play.rectangle.fill"
        }
    }

    var brandColor: Color {
        switch self {
        case .instagram: return Color(hex: "#E4405F")
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

    init(platform: SocialPlatform, isConnected: Bool = false, handle: String? = nil, followerCount: Int? = nil) {
        self.id = UUID()
        self.platform = platform
        self.isConnected = isConnected
        self.handle = handle
        self.followerCount = followerCount
    }
}
