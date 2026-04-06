import Foundation

// MARK: - Reward Type

enum RewardType: String, Codable, CaseIterable, Identifiable {
    case credit
    case discount
    case freePlan
    case customReward

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .credit:       return "Credit"
        case .discount:     return "Discount"
        case .freePlan:     return "Free Plan"
        case .customReward: return "Custom Reward"
        }
    }

    var iconName: String {
        switch self {
        case .credit:       return "dollarsign.circle.fill"
        case .discount:     return "percent"
        case .freePlan:     return "gift.fill"
        case .customReward: return "star.fill"
        }
    }
}

// MARK: - Referral Program

struct ReferralProgram: Identifiable, Codable {
    let id: UUID
    let code: String
    let rewardType: RewardType
    var referralCount: Int
    var earnedRewards: Double

    init(
        id: UUID = UUID(),
        code: String,
        rewardType: RewardType,
        referralCount: Int = 0,
        earnedRewards: Double = 0.0
    ) {
        self.id = id
        self.code = code
        self.rewardType = rewardType
        self.referralCount = referralCount
        self.earnedRewards = earnedRewards
    }
}

// MARK: - Referral Invite Status

enum ReferralInviteStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case accepted
    case expired
    case cancelled

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pending:   return "Pending"
        case .accepted:  return "Accepted"
        case .expired:   return "Expired"
        case .cancelled: return "Cancelled"
        }
    }

    var iconName: String {
        switch self {
        case .pending:   return "clock.fill"
        case .accepted:  return "checkmark.circle.fill"
        case .expired:   return "exclamationmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }
}

// MARK: - Referral Invite

struct ReferralInvite: Identifiable, Codable {
    let id: UUID
    let recipientEmail: String
    var status: ReferralInviteStatus
    let sentAt: Date

    init(
        id: UUID = UUID(),
        recipientEmail: String,
        status: ReferralInviteStatus = .pending,
        sentAt: Date = Date()
    ) {
        self.id = id
        self.recipientEmail = recipientEmail
        self.status = status
        self.sentAt = sentAt
    }
}

// MARK: - Growth Metric Trend

enum MetricTrend: String, Codable, CaseIterable, Identifiable {
    case up
    case down
    case flat

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .up:   return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .flat: return "arrow.right"
        }
    }
}

// MARK: - Growth Metric

struct GrowthMetric: Identifiable, Codable {
    let id: UUID
    let name: String
    let value: Double
    let trend: MetricTrend
    let period: String

    init(
        id: UUID = UUID(),
        name: String,
        value: Double,
        trend: MetricTrend,
        period: String
    ) {
        self.id = id
        self.name = name
        self.value = value
        self.trend = trend
        self.period = period
    }
}

// MARK: - Viral Loop Step

struct ViralLoopStep: Identifiable, Codable {
    let id: UUID
    let name: String
    let order: Int

    init(id: UUID = UUID(), name: String, order: Int) {
        self.id = id
        self.name = name
        self.order = order
    }
}

// MARK: - Viral Loop

struct ViralLoop: Identifiable, Codable {
    let id: UUID
    let name: String
    var conversionRate: Double
    let steps: [ViralLoopStep]

    init(
        id: UUID = UUID(),
        name: String,
        conversionRate: Double,
        steps: [ViralLoopStep] = []
    ) {
        self.id = id
        self.name = name
        self.conversionRate = conversionRate
        self.steps = steps
    }
}

// MARK: - Shareable Asset

struct ShareableAsset: Identifiable, Codable {
    let id: UUID
    let contentID: UUID
    let shareURL: String
    var views: Int
    var conversions: Int

    init(
        id: UUID = UUID(),
        contentID: UUID = UUID(),
        shareURL: String,
        views: Int = 0,
        conversions: Int = 0
    ) {
        self.id = id
        self.contentID = contentID
        self.shareURL = shareURL
        self.views = views
        self.conversions = conversions
    }

    var conversionRate: Double {
        guard views > 0 else { return 0 }
        return Double(conversions) / Double(views)
    }
}

// MARK: - Growth Error

enum GrowthError: LocalizedError {
    case notFound
    case invalidCode
    case networkError

    var errorDescription: String? {
        switch self {
        case .notFound:     return "Growth resource not found."
        case .invalidCode:  return "Invalid referral code."
        case .networkError: return "Network request failed."
        }
    }
}

// MARK: - Mock Data

extension ReferralProgram {
    static let mock = ReferralProgram(
        code: "ENVI-2024",
        rewardType: .credit,
        referralCount: 12,
        earnedRewards: 60.0
    )
}

extension ReferralInvite {
    static let mockList: [ReferralInvite] = [
        ReferralInvite(recipientEmail: "alice@example.com", status: .accepted, sentAt: Date().addingTimeInterval(-86400 * 5)),
        ReferralInvite(recipientEmail: "bob@example.com", status: .pending, sentAt: Date().addingTimeInterval(-86400 * 2)),
        ReferralInvite(recipientEmail: "carol@example.com", status: .expired, sentAt: Date().addingTimeInterval(-86400 * 30)),
        ReferralInvite(recipientEmail: "dave@example.com", status: .accepted, sentAt: Date().addingTimeInterval(-86400 * 10)),
        ReferralInvite(recipientEmail: "eve@example.com", status: .pending, sentAt: Date().addingTimeInterval(-3600)),
    ]
}

extension GrowthMetric {
    static let mockList: [GrowthMetric] = [
        GrowthMetric(name: "New Users", value: 342, trend: .up, period: "7d"),
        GrowthMetric(name: "Viral Coefficient", value: 1.4, trend: .up, period: "30d"),
        GrowthMetric(name: "Referral Rate", value: 18.5, trend: .flat, period: "7d"),
        GrowthMetric(name: "Activation Rate", value: 72.3, trend: .down, period: "30d"),
    ]
}

extension ViralLoop {
    static let mockList: [ViralLoop] = [
        ViralLoop(
            name: "Share Content Loop",
            conversionRate: 0.12,
            steps: [
                ViralLoopStep(name: "Create Content", order: 1),
                ViralLoopStep(name: "Share Link", order: 2),
                ViralLoopStep(name: "Friend Views", order: 3),
                ViralLoopStep(name: "Friend Signs Up", order: 4),
            ]
        ),
        ViralLoop(
            name: "Invite Reward Loop",
            conversionRate: 0.24,
            steps: [
                ViralLoopStep(name: "Send Invite", order: 1),
                ViralLoopStep(name: "Accept Invite", order: 2),
                ViralLoopStep(name: "Earn Reward", order: 3),
            ]
        ),
    ]
}

extension ShareableAsset {
    static let mockList: [ShareableAsset] = [
        ShareableAsset(shareURL: "https://envi.app/s/abc123", views: 1240, conversions: 89),
        ShareableAsset(shareURL: "https://envi.app/s/def456", views: 560, conversions: 34),
        ShareableAsset(shareURL: "https://envi.app/s/ghi789", views: 3200, conversions: 210),
    ]
}
