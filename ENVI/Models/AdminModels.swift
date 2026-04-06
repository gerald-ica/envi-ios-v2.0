import Foundation

// MARK: - Admin Role

/// Role-based access levels for admin users (ENVI-0926..0935).
enum AdminRole: String, CaseIterable, Codable, Identifiable {
    case superAdmin
    case moderator
    case analyst
    case support

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .superAdmin: return "Super Admin"
        case .moderator:  return "Moderator"
        case .analyst:    return "Analyst"
        case .support:    return "Support"
        }
    }
}

// MARK: - Admin Permission

/// Granular permissions assignable to admin roles.
enum AdminPermission: String, CaseIterable, Codable {
    case manageUsers
    case manageFlags
    case moderateContent
    case viewAnalytics
    case manageSystem

    var displayName: String {
        switch self {
        case .manageUsers:     return "Manage Users"
        case .manageFlags:     return "Manage Flags"
        case .moderateContent: return "Moderate Content"
        case .viewAnalytics:   return "View Analytics"
        case .manageSystem:    return "Manage System"
        }
    }
}

// MARK: - Admin User

/// An administrator with role-based permissions.
struct AdminUser: Identifiable {
    let id: UUID
    let email: String
    let role: AdminRole
    let permissions: [AdminPermission]

    init(
        id: UUID = UUID(),
        email: String,
        role: AdminRole,
        permissions: [AdminPermission]
    ) {
        self.id = id
        self.email = email
        self.role = role
        self.permissions = permissions
    }
}

// MARK: - Feature Flag

/// A feature flag with progressive rollout targeting (ENVI-0936..0940).
struct FeatureFlag: Identifiable {
    let id: UUID
    let name: String
    var isEnabled: Bool
    let targetPercentage: Double
    let description: String

    init(
        id: UUID = UUID(),
        name: String,
        isEnabled: Bool,
        targetPercentage: Double = 100,
        description: String
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.targetPercentage = targetPercentage
        self.description = description
    }
}

// MARK: - Moderation Status

/// Status lifecycle for moderated content (ENVI-0941..0950).
enum ModerationStatus: String, CaseIterable, Codable, Identifiable {
    case pending
    case approved
    case rejected
    case escalated

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    var iconName: String {
        switch self {
        case .pending:   return "clock"
        case .approved:  return "checkmark.circle"
        case .rejected:  return "xmark.circle"
        case .escalated: return "exclamationmark.triangle"
        }
    }
}

// MARK: - Moderation Item

/// A piece of content flagged for moderation review.
struct ModerationItem: Identifiable {
    let id: UUID
    let contentType: String
    let reportReason: String
    var status: ModerationStatus
    let reportedAt: Date

    init(
        id: UUID = UUID(),
        contentType: String,
        reportReason: String,
        status: ModerationStatus = .pending,
        reportedAt: Date = Date()
    ) {
        self.id = id
        self.contentType = contentType
        self.reportReason = reportReason
        self.status = status
        self.reportedAt = reportedAt
    }
}

// MARK: - Trust Score

/// User trust score derived from behavioral factors (ENVI-0951..0955).
struct TrustScore: Identifiable {
    let id: UUID
    let userID: String
    let score: Double
    let factors: [String]
    let lastUpdated: Date

    var id_: String { userID }

    init(
        id: UUID = UUID(),
        userID: String,
        score: Double,
        factors: [String],
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.userID = userID
        self.score = score
        self.factors = factors
        self.lastUpdated = lastUpdated
    }

    /// Readable trust level derived from numeric score.
    var level: String {
        switch score {
        case 80...100: return "High"
        case 50..<80:  return "Medium"
        default:       return "Low"
        }
    }
}

// MARK: - System Health Status

/// Status indicator for system health metrics.
enum HealthStatus: String, CaseIterable, Codable {
    case healthy
    case degraded
    case critical

    var displayName: String { rawValue.capitalized }

    var iconName: String {
        switch self {
        case .healthy:  return "checkmark.circle.fill"
        case .degraded: return "exclamationmark.circle.fill"
        case .critical: return "xmark.circle.fill"
        }
    }
}

// MARK: - System Health Metric

/// A single system health metric with threshold checking (ENVI-0956..0960).
struct SystemHealthMetric: Identifiable {
    let id: UUID
    let name: String
    let value: Double
    let status: HealthStatus
    let threshold: Double

    init(
        id: UUID = UUID(),
        name: String,
        value: Double,
        status: HealthStatus,
        threshold: Double
    ) {
        self.id = id
        self.name = name
        self.value = value
        self.status = status
        self.threshold = threshold
    }

    /// Formatted value string.
    var formattedValue: String {
        String(format: "%.1f", value)
    }
}

// MARK: - Mock Data

extension AdminUser {
    static let mock: [AdminUser] = [
        AdminUser(email: "admin@envi.app", role: .superAdmin, permissions: AdminPermission.allCases),
        AdminUser(email: "mod@envi.app", role: .moderator, permissions: [.moderateContent, .viewAnalytics]),
    ]
}

extension FeatureFlag {
    static let mock: [FeatureFlag] = [
        FeatureFlag(name: "ai_captions", isEnabled: true, targetPercentage: 100, description: "AI-powered caption generation"),
        FeatureFlag(name: "dark_mode_v2", isEnabled: true, targetPercentage: 50, description: "Redesigned dark mode palette"),
        FeatureFlag(name: "reels_editor", isEnabled: false, targetPercentage: 0, description: "In-app short-form video editor"),
        FeatureFlag(name: "collab_boards", isEnabled: true, targetPercentage: 25, description: "Collaborative mood boards"),
        FeatureFlag(name: "smart_scheduling", isEnabled: false, targetPercentage: 0, description: "ML-driven optimal post timing"),
    ]
}

extension ModerationItem {
    static let mock: [ModerationItem] = [
        ModerationItem(contentType: "Post", reportReason: "Spam", status: .pending, reportedAt: Date().addingTimeInterval(-3600)),
        ModerationItem(contentType: "Comment", reportReason: "Harassment", status: .pending, reportedAt: Date().addingTimeInterval(-7200)),
        ModerationItem(contentType: "Profile", reportReason: "Impersonation", status: .escalated, reportedAt: Date().addingTimeInterval(-86400)),
        ModerationItem(contentType: "Story", reportReason: "Inappropriate Content", status: .approved, reportedAt: Date().addingTimeInterval(-172800)),
    ]
}

extension TrustScore {
    static let mock: [TrustScore] = [
        TrustScore(userID: "usr_001", score: 92, factors: ["Verified email", "Active 6+ months", "No reports"]),
        TrustScore(userID: "usr_002", score: 45, factors: ["New account", "Multiple reports"]),
    ]
}

extension SystemHealthMetric {
    static let mock: [SystemHealthMetric] = [
        SystemHealthMetric(name: "API Latency (ms)", value: 120, status: .healthy, threshold: 500),
        SystemHealthMetric(name: "Error Rate (%)", value: 0.3, status: .healthy, threshold: 2.0),
        SystemHealthMetric(name: "CPU Usage (%)", value: 67, status: .degraded, threshold: 80),
        SystemHealthMetric(name: "Memory Usage (%)", value: 82, status: .critical, threshold: 85),
        SystemHealthMetric(name: "Queue Depth", value: 14, status: .healthy, threshold: 100),
        SystemHealthMetric(name: "DB Connections", value: 45, status: .healthy, threshold: 100),
    ]
}
