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
        case .instagram: return "camera"
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
        case .tiktok:    return Color(hex: "#FF0050")
        case .x:         return Color(.init(dynamicProvider: { traits in
            traits.userInterfaceStyle == .dark ? .white : .black
        }))
        case .threads:   return Color(.init(dynamicProvider: { traits in
            traits.userInterfaceStyle == .dark ? UIColor(white: 0.75, alpha: 1) : .black
        }))
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

    /// Deterministic UUID namespace for platform connections.
    private static func deterministicID(for platform: SocialPlatform) -> UUID {
        // Use a stable UUID derived from the platform name to avoid regenerating IDs.
        let namespace = "com.envi.platform."
        let name = namespace + platform.rawValue
        // Create a deterministic UUID by hashing the platform name into a fixed UUID format.
        var hash = name.utf8.reduce(UInt64(0)) { ($0 &<< 5) &+ $0 &+ UInt64($1) }
        var bytes = [UInt8](repeating: 0, count: 16)
        for i in 0..<8 {
            bytes[i] = UInt8(hash & 0xFF)
            hash >>= 8
        }
        // Set version 4 and variant bits for RFC 4122 compliance
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        let uuid = NSUUID(uuidBytes: bytes) as UUID
        return uuid
    }

    init(platform: SocialPlatform, isConnected: Bool = false, handle: String? = nil, followerCount: Int? = nil) {
        self.id = Self.deterministicID(for: platform)
        self.platform = platform
        self.isConnected = isConnected
        self.handle = handle
        self.followerCount = followerCount
    }
}
