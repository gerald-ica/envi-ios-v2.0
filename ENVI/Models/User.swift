import Foundation

/// Represents an ENVI user profile.
struct User: Identifiable, Codable {
    let id: UUID
    var firstName: String
    var lastName: String
    var email: String
    var dateOfBirth: Date?
    var location: String?
    var birthplace: String?
    var avatarURL: String?
    var handle: String
    var bio: String?
    var connectedPlatforms: [PlatformConnection]

    // Stats
    var publishedCount: Int
    var draftsCount: Int
    var templatesCount: Int

    var fullName: String { "\(firstName) \(lastName)" }
    var initials: String {
        let f = firstName.prefix(1).uppercased()
        let l = lastName.prefix(1).uppercased()
        return "\(f)\(l)"
    }

    static let mock = User(
        id: UUID(),
        firstName: "Alex",
        lastName: "Rivera",
        email: "alex@envi.app",
        dateOfBirth: Calendar.current.date(from: DateComponents(year: 1998, month: 6, day: 15)),
        location: "Los Angeles",
        birthplace: "Miami",
        avatarURL: nil,
        handle: "@alexrivera",
        bio: "Content creator & visual storyteller",
        connectedPlatforms: [
            PlatformConnection(platform: .instagram, isConnected: true, handle: "@alexrivera", followerCount: 125_000),
            PlatformConnection(platform: .tiktok, isConnected: true, handle: "@alexrivera", followerCount: 89_000),
            PlatformConnection(platform: .youtube, isConnected: true, handle: "Alex Rivera", followerCount: 45_000),
            PlatformConnection(platform: .x, isConnected: false),
            PlatformConnection(platform: .threads, isConnected: false),
            PlatformConnection(platform: .linkedin, isConnected: false),
        ],
        publishedCount: 142,
        draftsCount: 8,
        templatesCount: 12
    )
}
