import Foundation

// MARK: - Security Policy

struct SecurityPolicy: Identifiable, Codable {
    let id: UUID
    var name: String
    var rules: [String]
    var enforcedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        rules: [String],
        enforcedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.rules = rules
        self.enforcedAt = enforcedAt
    }

    static let mock = SecurityPolicy(
        name: "Default Content Policy",
        rules: [
            "Require two-factor authentication for publishing",
            "Auto-expire share links after 30 days",
            "Block downloads from unverified devices"
        ],
        enforcedAt: Date().addingTimeInterval(-86400 * 14)
    )

    static let mockList: [SecurityPolicy] = [
        .mock,
        SecurityPolicy(
            name: "Brand Safety Policy",
            rules: [
                "Content review before external sharing",
                "Watermark all preview exports",
                "Restrict API access to approved integrations"
            ],
            enforcedAt: Date().addingTimeInterval(-86400 * 30)
        ),
        SecurityPolicy(
            name: "Data Access Policy",
            rules: [
                "Encrypt analytics data at rest",
                "Limit PII exposure in reports",
                "Audit trail for all data exports"
            ],
            enforcedAt: Date().addingTimeInterval(-86400 * 7)
        )
    ]
}

// MARK: - Privacy Settings

struct PrivacySettings: Codable, Equatable {
    var dataCollection: Bool
    var adTracking: Bool
    var analyticsOptIn: Bool
    var locationSharing: Bool

    init(
        dataCollection: Bool = true,
        adTracking: Bool = false,
        analyticsOptIn: Bool = true,
        locationSharing: Bool = false
    ) {
        self.dataCollection = dataCollection
        self.adTracking = adTracking
        self.analyticsOptIn = analyticsOptIn
        self.locationSharing = locationSharing
    }

    static let mock = PrivacySettings()

    static let allDisabled = PrivacySettings(
        dataCollection: false,
        adTracking: false,
        analyticsOptIn: false,
        locationSharing: false
    )
}

// MARK: - Audit Log Entry

struct AuditLogEntry: Identifiable, Codable {
    let id: UUID
    var actor: String
    var action: String
    var resource: String
    var timestamp: Date
    var ipAddress: String

    init(
        id: UUID = UUID(),
        actor: String,
        action: String,
        resource: String,
        timestamp: Date = Date(),
        ipAddress: String
    ) {
        self.id = id
        self.actor = actor
        self.action = action
        self.resource = resource
        self.timestamp = timestamp
        self.ipAddress = ipAddress
    }

    static let mock = AuditLogEntry(
        actor: "sarah@envi.app",
        action: "Updated privacy settings",
        resource: "privacy_settings",
        ipAddress: "192.168.1.42"
    )

    static let mockList: [AuditLogEntry] = [
        .mock,
        AuditLogEntry(
            actor: "marcus@envi.app",
            action: "Exported analytics report",
            resource: "analytics_export",
            timestamp: Date().addingTimeInterval(-1800),
            ipAddress: "10.0.0.15"
        ),
        AuditLogEntry(
            actor: "alex@envi.app",
            action: "Created share link",
            resource: "share_link",
            timestamp: Date().addingTimeInterval(-3600),
            ipAddress: "172.16.0.8"
        ),
        AuditLogEntry(
            actor: "sarah@envi.app",
            action: "Deleted draft content",
            resource: "content_draft",
            timestamp: Date().addingTimeInterval(-7200),
            ipAddress: "192.168.1.42"
        ),
        AuditLogEntry(
            actor: "system",
            action: "Auto-purged expired tokens",
            resource: "auth_tokens",
            timestamp: Date().addingTimeInterval(-14400),
            ipAddress: "127.0.0.1"
        ),
        AuditLogEntry(
            actor: "marcus@envi.app",
            action: "Updated security policy",
            resource: "security_policy",
            timestamp: Date().addingTimeInterval(-28800),
            ipAddress: "10.0.0.15"
        )
    ]
}

// MARK: - Compliance Check

enum SecurityComplianceStatus: String, Codable, CaseIterable, Identifiable {
    case passed
    case failed
    case pending
    case inReview

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .passed:   return "Passed"
        case .failed:   return "Failed"
        case .pending:  return "Pending"
        case .inReview: return "In Review"
        }
    }

    var iconName: String {
        switch self {
        case .passed:   return "checkmark.shield.fill"
        case .failed:   return "xmark.shield.fill"
        case .pending:  return "clock.fill"
        case .inReview: return "magnifyingglass"
        }
    }
}

enum Regulation: String, Codable, CaseIterable, Identifiable {
    case gdpr
    case ccpa
    case soc2
    case hipaa
    case coppa

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gdpr:  return "GDPR"
        case .ccpa:  return "CCPA"
        case .soc2:  return "SOC 2"
        case .hipaa: return "HIPAA"
        case .coppa: return "COPPA"
        }
    }

    var description: String {
        switch self {
        case .gdpr:  return "EU General Data Protection Regulation"
        case .ccpa:  return "California Consumer Privacy Act"
        case .soc2:  return "Service Organization Control Type 2"
        case .hipaa: return "Health Insurance Portability and Accountability"
        case .coppa: return "Children's Online Privacy Protection"
        }
    }
}

struct ComplianceCheck: Identifiable, Codable {
    let id: UUID
    var regulation: Regulation
    var status: SecurityComplianceStatus
    var lastAuditDate: Date
    var findings: [String]

    init(
        id: UUID = UUID(),
        regulation: Regulation,
        status: SecurityComplianceStatus,
        lastAuditDate: Date = Date(),
        findings: [String] = []
    ) {
        self.id = id
        self.regulation = regulation
        self.status = status
        self.lastAuditDate = lastAuditDate
        self.findings = findings
    }

    static let mock = ComplianceCheck(
        regulation: .gdpr,
        status: .passed,
        lastAuditDate: Date().addingTimeInterval(-86400 * 3),
        findings: ["All data processing agreements in place"]
    )

    static let mockList: [ComplianceCheck] = [
        .mock,
        ComplianceCheck(
            regulation: .ccpa,
            status: .passed,
            lastAuditDate: Date().addingTimeInterval(-86400 * 5),
            findings: ["Consumer opt-out mechanism verified"]
        ),
        ComplianceCheck(
            regulation: .soc2,
            status: .inReview,
            lastAuditDate: Date().addingTimeInterval(-86400 * 10),
            findings: [
                "Access controls audit in progress",
                "Encryption standards verified"
            ]
        ),
        ComplianceCheck(
            regulation: .hipaa,
            status: .pending,
            lastAuditDate: Date().addingTimeInterval(-86400 * 45),
            findings: ["Awaiting updated BAA documentation"]
        ),
        ComplianceCheck(
            regulation: .coppa,
            status: .failed,
            lastAuditDate: Date().addingTimeInterval(-86400 * 2),
            findings: [
                "Age-gate mechanism needs update",
                "Parental consent flow incomplete"
            ]
        )
    ]
}

// MARK: - Data Retention Policy

struct DataRetentionPolicy: Identifiable, Codable {
    var id: String { dataType }
    var dataType: String
    var retentionDays: Int
    var autoDeleteEnabled: Bool

    init(
        dataType: String,
        retentionDays: Int,
        autoDeleteEnabled: Bool = false
    ) {
        self.dataType = dataType
        self.retentionDays = retentionDays
        self.autoDeleteEnabled = autoDeleteEnabled
    }

    var formattedRetention: String {
        if retentionDays >= 365 {
            let years = retentionDays / 365
            return "\(years) year\(years == 1 ? "" : "s")"
        } else if retentionDays >= 30 {
            let months = retentionDays / 30
            return "\(months) month\(months == 1 ? "" : "s")"
        }
        return "\(retentionDays) days"
    }

    static let mockList: [DataRetentionPolicy] = [
        DataRetentionPolicy(dataType: "Analytics Events", retentionDays: 365, autoDeleteEnabled: true),
        DataRetentionPolicy(dataType: "Audit Logs", retentionDays: 730, autoDeleteEnabled: false),
        DataRetentionPolicy(dataType: "User Content", retentionDays: 1825, autoDeleteEnabled: false),
        DataRetentionPolicy(dataType: "Session Data", retentionDays: 90, autoDeleteEnabled: true),
        DataRetentionPolicy(dataType: "Deleted Content", retentionDays: 30, autoDeleteEnabled: true)
    ]
}

// MARK: - Security Error

enum SecurityError: LocalizedError {
    case notFound
    case unauthorized
    case policyViolation

    var errorDescription: String? {
        switch self {
        case .notFound:        return "The requested security resource was not found."
        case .unauthorized:    return "You are not authorized to perform this action."
        case .policyViolation: return "This action violates an active security policy."
        }
    }
}
