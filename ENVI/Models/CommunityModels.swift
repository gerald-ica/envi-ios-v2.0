import Foundation

// MARK: - Platform

enum SocialPlatform: String, Codable, CaseIterable, Identifiable {
    case instagram
    case tiktok
    case youtube
    case twitter
    case threads
    case facebook
    case linkedin

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .instagram: return "Instagram"
        case .tiktok:    return "TikTok"
        case .youtube:   return "YouTube"
        case .twitter:   return "X"
        case .threads:   return "Threads"
        case .facebook:  return "Facebook"
        case .linkedin:  return "LinkedIn"
        }
    }

    var iconName: String {
        switch self {
        case .instagram: return "camera.circle.fill"
        case .tiktok:    return "play.circle.fill"
        case .youtube:   return "play.rectangle.fill"
        case .twitter:   return "at.circle.fill"
        case .threads:   return "at.badge.plus"
        case .facebook:  return "person.2.circle.fill"
        case .linkedin:  return "briefcase.circle.fill"
        }
    }
}

// MARK: - Message Sentiment

enum MessageSentiment: String, Codable, CaseIterable, Identifiable {
    case positive
    case neutral
    case negative

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    var iconName: String {
        switch self {
        case .positive: return "hand.thumbsup.fill"
        case .neutral:  return "minus.circle.fill"
        case .negative: return "hand.thumbsdown.fill"
        }
    }
}

// MARK: - Inbox Filter

enum InboxFilter: String, Codable, CaseIterable, Identifiable {
    case all
    case unread
    case flagged
    case platform

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }
}

// MARK: - Inbox Message

struct InboxMessage: Identifiable, Codable {
    let id: UUID
    var platform: SocialPlatform
    var senderName: String
    var senderAvatar: String?
    var text: String
    var timestamp: Date
    var isRead: Bool
    var isFlagged: Bool
    var sentiment: MessageSentiment

    init(
        id: UUID = UUID(),
        platform: SocialPlatform,
        senderName: String,
        senderAvatar: String? = nil,
        text: String,
        timestamp: Date = Date(),
        isRead: Bool = false,
        isFlagged: Bool = false,
        sentiment: MessageSentiment = .neutral
    ) {
        self.id = id
        self.platform = platform
        self.senderName = senderName
        self.senderAvatar = senderAvatar
        self.text = text
        self.timestamp = timestamp
        self.isRead = isRead
        self.isFlagged = isFlagged
        self.sentiment = sentiment
    }
}

// MARK: - Quick Reply

struct QuickReply: Identifiable, Codable {
    let id: UUID
    var label: String
    var text: String

    init(id: UUID = UUID(), label: String, text: String) {
        self.id = id
        self.label = label
        self.text = text
    }
}

// MARK: - Audience Contact

struct AudienceContact: Identifiable, Codable {
    let id: UUID
    var name: String
    var email: String?
    var platforms: [SocialPlatform]
    var segments: [String]
    var lifetimeValue: Double
    var lastInteraction: Date
    var engagementScore: Int

    init(
        id: UUID = UUID(),
        name: String,
        email: String? = nil,
        platforms: [SocialPlatform] = [],
        segments: [String] = [],
        lifetimeValue: Double = 0,
        lastInteraction: Date = Date(),
        engagementScore: Int = 0
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.platforms = platforms
        self.segments = segments
        self.lifetimeValue = lifetimeValue
        self.lastInteraction = lastInteraction
        self.engagementScore = engagementScore
    }
}

// MARK: - Segment Rule

struct SegmentRule: Identifiable, Codable {
    let id: UUID
    var field: String
    var op: SegmentOperator
    var value: String

    init(id: UUID = UUID(), field: String, op: SegmentOperator, value: String) {
        self.id = id
        self.field = field
        self.op = op
        self.value = value
    }
}

enum SegmentOperator: String, Codable, CaseIterable, Identifiable {
    case equals
    case notEquals
    case greaterThan
    case lessThan
    case contains

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .equals:      return "equals"
        case .notEquals:   return "not equals"
        case .greaterThan: return "greater than"
        case .lessThan:    return "less than"
        case .contains:    return "contains"
        }
    }
}

// MARK: - Audience Segment

struct AudienceSegment: Identifiable, Codable {
    let id: UUID
    var name: String
    var rules: [SegmentRule]
    var memberCount: Int
    var avgEngagement: Double

    init(
        id: UUID = UUID(),
        name: String,
        rules: [SegmentRule] = [],
        memberCount: Int = 0,
        avgEngagement: Double = 0
    ) {
        self.id = id
        self.name = name
        self.rules = rules
        self.memberCount = memberCount
        self.avgEngagement = avgEngagement
    }
}

// MARK: - Mock Data

extension InboxMessage {
    static let mockList: [InboxMessage] = [
        InboxMessage(platform: .instagram, senderName: "sarah_designs", text: "Love your latest post! What camera do you use?", timestamp: Date().addingTimeInterval(-3600), sentiment: .positive),
        InboxMessage(platform: .tiktok, senderName: "creativemike", text: "Collab? DM me!", timestamp: Date().addingTimeInterval(-7200), sentiment: .positive),
        InboxMessage(platform: .youtube, senderName: "TechReviewer", text: "Great video but the audio was a bit off at 2:30", timestamp: Date().addingTimeInterval(-10800), sentiment: .neutral),
        InboxMessage(platform: .twitter, senderName: "@brand_insider", text: "This is misleading information.", timestamp: Date().addingTimeInterval(-14400), isFlagged: true, sentiment: .negative),
        InboxMessage(platform: .threads, senderName: "artlover99", text: "Your editing style is incredible!", timestamp: Date().addingTimeInterval(-18000), isRead: true, sentiment: .positive),
        InboxMessage(platform: .facebook, senderName: "Community Hub", text: "New group post waiting for approval.", timestamp: Date().addingTimeInterval(-21600), sentiment: .neutral),
    ]
}

extension QuickReply {
    static let defaults: [QuickReply] = [
        QuickReply(label: "Thank you", text: "Thank you so much! I really appreciate your support! 🙏"),
        QuickReply(label: "Noted", text: "Thanks for the feedback — noted!"),
        QuickReply(label: "DM me", text: "Send me a DM and let's chat!"),
        QuickReply(label: "Later", text: "I'll get back to you soon!"),
    ]
}

extension AudienceContact {
    static let mockList: [AudienceContact] = [
        AudienceContact(name: "Sarah Chen", email: "sarah@example.com", platforms: [.instagram, .tiktok], segments: ["Top Fans", "Creators"], lifetimeValue: 245.0, lastInteraction: Date().addingTimeInterval(-86400), engagementScore: 92),
        AudienceContact(name: "Mike Torres", email: "mike@example.com", platforms: [.youtube, .twitter], segments: ["Top Fans"], lifetimeValue: 180.0, lastInteraction: Date().addingTimeInterval(-172800), engagementScore: 78),
        AudienceContact(name: "Jess Kim", platforms: [.instagram], segments: ["New Followers"], lifetimeValue: 30.0, lastInteraction: Date().addingTimeInterval(-259200), engagementScore: 45),
        AudienceContact(name: "Alex Rao", email: "alex@example.com", platforms: [.threads, .linkedin], segments: ["Creators", "VIP"], lifetimeValue: 520.0, lastInteraction: Date().addingTimeInterval(-43200), engagementScore: 97),
    ]
}

extension AudienceSegment {
    static let mockList: [AudienceSegment] = [
        AudienceSegment(name: "Top Fans", rules: [SegmentRule(field: "engagementScore", op: .greaterThan, value: "80")], memberCount: 1240, avgEngagement: 87.3),
        AudienceSegment(name: "New Followers", rules: [SegmentRule(field: "lastInteraction", op: .lessThan, value: "7d")], memberCount: 3850, avgEngagement: 42.1),
        AudienceSegment(name: "VIP", rules: [SegmentRule(field: "lifetimeValue", op: .greaterThan, value: "200")], memberCount: 320, avgEngagement: 94.6),
    ]
}
