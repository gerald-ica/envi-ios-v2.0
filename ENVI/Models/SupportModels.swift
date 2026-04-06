import Foundation

// MARK: - Ticket Status

enum TicketStatus: String, Codable, CaseIterable, Identifiable {
    case open
    case inProgress
    case waitingOnCustomer
    case resolved
    case closed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .open:              return "Open"
        case .inProgress:        return "In Progress"
        case .waitingOnCustomer: return "Waiting on Customer"
        case .resolved:          return "Resolved"
        case .closed:            return "Closed"
        }
    }

    var iconName: String {
        switch self {
        case .open:              return "circle"
        case .inProgress:        return "arrow.triangle.2.circlepath"
        case .waitingOnCustomer: return "clock.fill"
        case .resolved:          return "checkmark.circle.fill"
        case .closed:            return "xmark.circle.fill"
        }
    }
}

// MARK: - Ticket Priority

enum TicketPriority: String, Codable, CaseIterable, Identifiable {
    case low
    case medium
    case high
    case urgent

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low:    return "Low"
        case .medium: return "Medium"
        case .high:   return "High"
        case .urgent: return "Urgent"
        }
    }

    var iconName: String {
        switch self {
        case .low:    return "arrow.down"
        case .medium: return "minus"
        case .high:   return "arrow.up"
        case .urgent: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Ticket Message

struct TicketMessage: Identifiable, Codable {
    let id: UUID
    let senderName: String
    let text: String
    let timestamp: Date
    let isStaff: Bool

    init(
        id: UUID = UUID(),
        senderName: String,
        text: String,
        timestamp: Date = Date(),
        isStaff: Bool = false
    ) {
        self.id = id
        self.senderName = senderName
        self.text = text
        self.timestamp = timestamp
        self.isStaff = isStaff
    }
}

// MARK: - Support Ticket

struct SupportTicket: Identifiable, Codable {
    let id: UUID
    let subject: String
    let description: String
    var status: TicketStatus
    let priority: TicketPriority
    let createdAt: Date
    var messages: [TicketMessage]

    init(
        id: UUID = UUID(),
        subject: String,
        description: String,
        status: TicketStatus = .open,
        priority: TicketPriority = .medium,
        createdAt: Date = Date(),
        messages: [TicketMessage] = []
    ) {
        self.id = id
        self.subject = subject
        self.description = description
        self.status = status
        self.priority = priority
        self.createdAt = createdAt
        self.messages = messages
    }
}

// MARK: - FAQ Article

struct FAQArticle: Identifiable, Codable {
    let id: UUID
    let title: String
    let body: String
    let category: String
    var helpfulness: Int

    init(
        id: UUID = UUID(),
        title: String,
        body: String,
        category: String,
        helpfulness: Int = 0
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.category = category
        self.helpfulness = helpfulness
    }
}

// MARK: - Health Score Factor

struct HealthScoreFactor: Identifiable, Codable {
    let id: UUID
    let name: String
    let value: Double
    let weight: Double

    init(
        id: UUID = UUID(),
        name: String,
        value: Double,
        weight: Double = 1.0
    ) {
        self.id = id
        self.name = name
        self.value = value
        self.weight = weight
    }
}

// MARK: - Health Score

struct HealthScore: Identifiable, Codable {
    let id: UUID
    let score: Int
    let factors: [HealthScoreFactor]
    let recommendation: String

    init(
        id: UUID = UUID(),
        score: Int,
        factors: [HealthScoreFactor],
        recommendation: String
    ) {
        self.id = id
        self.score = score
        self.factors = factors
        self.recommendation = recommendation
    }

    var tier: HealthTier {
        switch score {
        case 80...100: return .healthy
        case 60..<80:  return .neutral
        case 40..<60:  return .atRisk
        default:       return .critical
        }
    }
}

// MARK: - Health Tier

enum HealthTier: String, Codable, CaseIterable, Identifiable {
    case healthy
    case neutral
    case atRisk
    case critical

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .healthy:  return "Healthy"
        case .neutral:  return "Neutral"
        case .atRisk:   return "At Risk"
        case .critical: return "Critical"
        }
    }

    var iconName: String {
        switch self {
        case .healthy:  return "heart.fill"
        case .neutral:  return "heart"
        case .atRisk:   return "exclamationmark.heart.fill"
        case .critical: return "heart.slash.fill"
        }
    }
}

// MARK: - Lifecycle Stage

enum LifecycleStage: String, Codable, CaseIterable, Identifiable {
    case trial
    case active
    case atRisk
    case churned
    case winback

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .trial:   return "Trial"
        case .active:  return "Active"
        case .atRisk:  return "At Risk"
        case .churned: return "Churned"
        case .winback: return "Win-Back"
        }
    }

    var iconName: String {
        switch self {
        case .trial:   return "sparkles"
        case .active:  return "checkmark.seal.fill"
        case .atRisk:  return "exclamationmark.triangle.fill"
        case .churned: return "arrow.uturn.left.circle.fill"
        case .winback: return "arrow.counterclockwise.circle.fill"
        }
    }
}

// MARK: - Support Error

enum SupportError: LocalizedError {
    case notFound
    case invalidTicket
    case networkError

    var errorDescription: String? {
        switch self {
        case .notFound:      return "Support resource not found."
        case .invalidTicket: return "Invalid ticket data."
        case .networkError:  return "Network request failed."
        }
    }
}

// MARK: - Mock Data

extension TicketMessage {
    static let mockList: [TicketMessage] = [
        TicketMessage(senderName: "You", text: "I can't connect my Instagram account.", timestamp: Date().addingTimeInterval(-7200), isStaff: false),
        TicketMessage(senderName: "ENVI Support", text: "Could you try reconnecting from Settings > Accounts?", timestamp: Date().addingTimeInterval(-3600), isStaff: true),
        TicketMessage(senderName: "You", text: "That worked, thank you!", timestamp: Date().addingTimeInterval(-1800), isStaff: false),
    ]
}

extension SupportTicket {
    static let mockList: [SupportTicket] = [
        SupportTicket(
            subject: "Instagram connection issue",
            description: "Unable to connect my Instagram business account.",
            status: .resolved,
            priority: .high,
            createdAt: Date().addingTimeInterval(-86400 * 3),
            messages: TicketMessage.mockList
        ),
        SupportTicket(
            subject: "Billing question",
            description: "I was charged twice this month.",
            status: .open,
            priority: .urgent,
            createdAt: Date().addingTimeInterval(-86400)
        ),
        SupportTicket(
            subject: "Feature request: TikTok analytics",
            description: "Would love deeper TikTok insights.",
            status: .closed,
            priority: .low,
            createdAt: Date().addingTimeInterval(-86400 * 14)
        ),
    ]
}

extension FAQArticle {
    static let mockList: [FAQArticle] = [
        FAQArticle(title: "How do I connect a social account?", body: "Go to Settings > Accounts and tap 'Add Account'. Follow the platform-specific authentication flow.", category: "Getting Started", helpfulness: 42),
        FAQArticle(title: "How do I schedule a post?", body: "Open the Calendar tab, tap '+', compose your content, choose a date/time, and tap Schedule.", category: "Scheduling", helpfulness: 38),
        FAQArticle(title: "What analytics are available?", body: "ENVI provides engagement, reach, impressions, follower growth, and content performance analytics across all connected platforms.", category: "Analytics", helpfulness: 55),
        FAQArticle(title: "How do I cancel my subscription?", body: "Go to Settings > Billing and tap 'Manage Subscription'. You can downgrade or cancel at any time.", category: "Billing", helpfulness: 21),
        FAQArticle(title: "How do referrals work?", body: "Share your unique referral code. When someone signs up using it, both of you earn credits.", category: "Growth", helpfulness: 30),
    ]
}

extension HealthScore {
    static let mock = HealthScore(
        score: 73,
        factors: [
            HealthScoreFactor(name: "Login Frequency", value: 0.85, weight: 0.3),
            HealthScoreFactor(name: "Feature Adoption", value: 0.60, weight: 0.25),
            HealthScoreFactor(name: "Content Published", value: 0.70, weight: 0.25),
            HealthScoreFactor(name: "Support Sentiment", value: 0.90, weight: 0.2),
        ],
        recommendation: "Try exploring the Analytics dashboard to get more value from your content strategy."
    )
}
