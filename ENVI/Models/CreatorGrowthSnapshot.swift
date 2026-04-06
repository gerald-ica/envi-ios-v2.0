import Foundation

struct CreatorGrowthSnapshot {
    let followerGrowthPercent: Double
    let netNewFollowers: Int
    let weeklyRetentionPercent: Double
    let topPerformingPlatform: SocialPlatform
    let channels: [ChannelGrowth]
}

struct ChannelGrowth: Identifiable {
    let id = UUID()
    let platform: SocialPlatform
    let netFollowers: Int
    let growthPercent: Double
}

extension CreatorGrowthSnapshot {
    static let mock = CreatorGrowthSnapshot(
        followerGrowthPercent: 12.4,
        netNewFollowers: 1840,
        weeklyRetentionPercent: 78.6,
        topPerformingPlatform: .instagram,
        channels: [
            ChannelGrowth(platform: .instagram, netFollowers: 980, growthPercent: 14.2),
            ChannelGrowth(platform: .tiktok, netFollowers: 620, growthPercent: 11.7),
            ChannelGrowth(platform: .youtube, netFollowers: 240, growthPercent: 6.5)
        ]
    )
}
