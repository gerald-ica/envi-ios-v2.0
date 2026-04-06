import Foundation

// MARK: - ENVI-0851 Pricing Tier

/// The subscription tier a user belongs to.
enum PricingTier: String, Codable, CaseIterable, Identifiable {
    case free
    case creator
    case pro
    case team
    case agency
    case enterprise

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .free:       return "Free"
        case .creator:    return "Creator"
        case .pro:        return "Pro"
        case .team:       return "Team"
        case .agency:     return "Agency"
        case .enterprise: return "Enterprise"
        }
    }

    /// Tier ordering for comparison and upgrade prompts.
    var rank: Int {
        switch self {
        case .free:       return 0
        case .creator:    return 1
        case .pro:        return 2
        case .team:       return 3
        case .agency:     return 4
        case .enterprise: return 5
        }
    }
}

// MARK: - ENVI-0852 Billing Interval

/// Billing cadence for a subscription plan.
enum BillingInterval: String, Codable {
    case monthly
    case annual
}

// MARK: - ENVI-0853 Subscription Plan

/// A subscription plan offered to users.
struct SubscriptionPlan: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let tier: PricingTier
    let price: Decimal
    let interval: BillingInterval
    let features: [String]
    let isPopular: Bool

    /// Formatted price string, e.g. "$9.99/mo".
    var formattedPrice: String {
        let formatted = NSDecimalNumber(decimal: price)
            .description(withLocale: Locale(identifier: "en_US"))
        let suffix = interval == .monthly ? "/mo" : "/yr"
        return "$\(formatted)\(suffix)"
    }

    /// Monthly-equivalent price for annual plans.
    var monthlyEquivalent: Decimal? {
        guard interval == .annual else { return nil }
        return price / 12
    }

    static func == (lhs: SubscriptionPlan, rhs: SubscriptionPlan) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Mock Data

    static let mock: [SubscriptionPlan] = [
        SubscriptionPlan(
            id: "plan_free",
            name: "Free",
            tier: .free,
            price: 0,
            interval: .monthly,
            features: [
                "3 social accounts",
                "10 scheduled posts/mo",
                "Basic analytics",
            ],
            isPopular: false
        ),
        SubscriptionPlan(
            id: "plan_creator_monthly",
            name: "Creator",
            tier: .creator,
            price: 9.99,
            interval: .monthly,
            features: [
                "10 social accounts",
                "Unlimited scheduled posts",
                "Advanced analytics",
                "AI caption generation (50/mo)",
                "1 GB storage",
            ],
            isPopular: false
        ),
        SubscriptionPlan(
            id: "plan_pro_monthly",
            name: "Pro",
            tier: .pro,
            price: 24.99,
            interval: .monthly,
            features: [
                "25 social accounts",
                "Unlimited scheduled posts",
                "Full analytics suite",
                "AI caption generation (200/mo)",
                "10 GB storage",
                "Brand kit",
                "Content calendar",
            ],
            isPopular: true
        ),
        SubscriptionPlan(
            id: "plan_team_monthly",
            name: "Team",
            tier: .team,
            price: 49.99,
            interval: .monthly,
            features: [
                "Unlimited social accounts",
                "Unlimited scheduled posts",
                "Full analytics suite",
                "AI caption generation (500/mo)",
                "50 GB storage",
                "Brand kit",
                "Content calendar",
                "5 team seats",
                "Approval workflows",
            ],
            isPopular: false
        ),
        // Annual variants
        SubscriptionPlan(
            id: "plan_creator_annual",
            name: "Creator",
            tier: .creator,
            price: 95.88,
            interval: .annual,
            features: [
                "10 social accounts",
                "Unlimited scheduled posts",
                "Advanced analytics",
                "AI caption generation (50/mo)",
                "1 GB storage",
            ],
            isPopular: false
        ),
        SubscriptionPlan(
            id: "plan_pro_annual",
            name: "Pro",
            tier: .pro,
            price: 239.88,
            interval: .annual,
            features: [
                "25 social accounts",
                "Unlimited scheduled posts",
                "Full analytics suite",
                "AI caption generation (200/mo)",
                "10 GB storage",
                "Brand kit",
                "Content calendar",
            ],
            isPopular: true
        ),
        SubscriptionPlan(
            id: "plan_team_annual",
            name: "Team",
            tier: .team,
            price: 479.88,
            interval: .annual,
            features: [
                "Unlimited social accounts",
                "Unlimited scheduled posts",
                "Full analytics suite",
                "AI caption generation (500/mo)",
                "50 GB storage",
                "Brand kit",
                "Content calendar",
                "5 team seats",
                "Approval workflows",
            ],
            isPopular: false
        ),
    ]
}

// MARK: - ENVI-0854 Usage Meter

/// Tracks usage of a metered feature against its limit.
struct UsageMeter: Identifiable, Codable {
    let id: String
    let feature: String
    let used: Int
    let limit: Int
    let resetDate: Date

    /// Usage as a fraction of the limit (0.0–1.0+).
    var usageFraction: Double {
        guard limit > 0 else { return 0 }
        return Double(used) / Double(limit)
    }

    /// Remaining units.
    var remaining: Int {
        max(limit - used, 0)
    }

    /// Whether the user has exceeded the limit.
    var isOverLimit: Bool {
        used >= limit
    }

    /// Whether usage is within the warning threshold (>=80%).
    var isNearLimit: Bool {
        usageFraction >= 0.8
    }

    static let mock: [UsageMeter] = [
        UsageMeter(
            id: "meter_ai",
            feature: "AI Generations",
            used: 42,
            limit: 50,
            resetDate: Calendar.current.date(byAdding: .day, value: 12, to: Date()) ?? Date()
        ),
        UsageMeter(
            id: "meter_storage",
            feature: "Storage",
            used: 720,
            limit: 1024,
            resetDate: Calendar.current.date(byAdding: .day, value: 12, to: Date()) ?? Date()
        ),
        UsageMeter(
            id: "meter_publishes",
            feature: "Scheduled Posts",
            used: 28,
            limit: 100,
            resetDate: Calendar.current.date(byAdding: .day, value: 12, to: Date()) ?? Date()
        ),
        UsageMeter(
            id: "meter_seats",
            feature: "Team Seats",
            used: 3,
            limit: 5,
            resetDate: Calendar.current.date(byAdding: .day, value: 12, to: Date()) ?? Date()
        ),
    ]
}

// MARK: - ENVI-0855 Billing History

/// Status of a billing transaction.
enum BillingStatus: String, Codable {
    case paid
    case pending
    case failed
    case refunded
}

/// A single billing history entry (invoice / charge).
struct BillingHistoryEntry: Identifiable, Codable {
    let id: String
    let date: Date
    let amount: Decimal
    let description: String
    let status: BillingStatus
    let receiptURL: URL?

    /// Formatted amount string.
    var formattedAmount: String {
        let formatted = NSDecimalNumber(decimal: amount)
            .description(withLocale: Locale(identifier: "en_US"))
        return "$\(formatted)"
    }

    static let mock: [BillingHistoryEntry] = [
        BillingHistoryEntry(
            id: "inv-001",
            date: Date(),
            amount: 24.99,
            description: "Pro Plan - Monthly",
            status: .paid,
            receiptURL: URL(string: "https://app.envi.co/receipts/inv-001")
        ),
        BillingHistoryEntry(
            id: "inv-002",
            date: Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date(),
            amount: 24.99,
            description: "Pro Plan - Monthly",
            status: .paid,
            receiptURL: URL(string: "https://app.envi.co/receipts/inv-002")
        ),
        BillingHistoryEntry(
            id: "inv-003",
            date: Calendar.current.date(byAdding: .month, value: -2, to: Date()) ?? Date(),
            amount: 24.99,
            description: "Pro Plan - Monthly",
            status: .paid,
            receiptURL: URL(string: "https://app.envi.co/receipts/inv-003")
        ),
        BillingHistoryEntry(
            id: "inv-004",
            date: Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date(),
            amount: 9.99,
            description: "Creator Plan - Monthly",
            status: .refunded,
            receiptURL: URL(string: "https://app.envi.co/receipts/inv-004")
        ),
    ]
}

// MARK: - ENVI-0856 Upgrade Prompt

/// Contextual prompt shown when a user attempts a gated feature.
struct UpgradePrompt: Identifiable, Codable {
    let id: String
    let feature: String
    let requiredTier: PricingTier
    let message: String

    static let mock: [UpgradePrompt] = [
        UpgradePrompt(
            id: "prompt_ai",
            feature: "AI Generations",
            requiredTier: .creator,
            message: "You've used all your free AI generations. Upgrade to Creator to unlock 50 per month."
        ),
        UpgradePrompt(
            id: "prompt_brandkit",
            feature: "Brand Kit",
            requiredTier: .pro,
            message: "Brand Kit is a Pro feature. Upgrade to save brand colors, fonts, and templates."
        ),
        UpgradePrompt(
            id: "prompt_team",
            feature: "Team Seats",
            requiredTier: .team,
            message: "Invite your team members by upgrading to the Team plan."
        ),
    ]
}

// MARK: - ENVI-0857 Team Seat

/// Status of a team seat invitation or membership.
enum TeamSeatStatus: String, Codable {
    case active
    case invited
    case deactivated
}

/// Role assigned to a team seat.
enum TeamSeatRole: String, Codable {
    case owner
    case admin
    case editor
    case viewer
}

/// Represents a seat on a team plan.
struct TeamSeat: Identifiable, Codable {
    let id: String
    let email: String
    let role: TeamSeatRole
    let addedAt: Date
    let status: TeamSeatStatus

    static let mock: [TeamSeat] = [
        TeamSeat(
            id: "seat-1",
            email: "owner@envi.co",
            role: .owner,
            addedAt: Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date(),
            status: .active
        ),
        TeamSeat(
            id: "seat-2",
            email: "editor@envi.co",
            role: .editor,
            addedAt: Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date(),
            status: .active
        ),
        TeamSeat(
            id: "seat-3",
            email: "newmember@envi.co",
            role: .viewer,
            addedAt: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
            status: .invited
        ),
    ]
}

// MARK: - ENVI-0858 Current Subscription

/// The user's current active subscription.
struct CurrentSubscription: Codable {
    let plan: SubscriptionPlan
    let tier: PricingTier
    let renewsAt: Date?
    let isTrial: Bool

    static let mock = CurrentSubscription(
        plan: SubscriptionPlan.mock[2], // Pro monthly
        tier: .pro,
        renewsAt: Calendar.current.date(byAdding: .day, value: 18, to: Date()),
        isTrial: false
    )
}
