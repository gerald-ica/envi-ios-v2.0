import Foundation

// MARK: - ENVI-0826 Integration Category

/// Categories for third-party integrations available in the ENVI ecosystem.
enum IntegrationCategory: String, Codable, CaseIterable, Identifiable {
    case storage
    case analytics
    case design
    case communication
    case commerce
    case automation

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .storage:       return "Storage"
        case .analytics:     return "Analytics"
        case .design:        return "Design"
        case .communication: return "Communication"
        case .commerce:      return "Commerce"
        case .automation:    return "Automation"
        }
    }

    var iconName: String {
        switch self {
        case .storage:       return "externaldrive.fill"
        case .analytics:     return "chart.bar.fill"
        case .design:        return "paintbrush.fill"
        case .communication: return "bubble.left.and.bubble.right.fill"
        case .commerce:      return "cart.fill"
        case .automation:    return "gearshape.2.fill"
        }
    }
}

// MARK: - ENVI-0827 Integration Status

/// Connection status of an integration.
enum IntegrationStatus: String, Codable {
    case connected
    case disconnected
    case pending

    var displayName: String {
        switch self {
        case .connected:    return "Connected"
        case .disconnected: return "Disconnected"
        case .pending:      return "Pending"
        }
    }
}

// MARK: - ENVI-0828 Integration

/// A third-party integration that can be connected to the ENVI platform.
struct Integration: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let category: IntegrationCategory
    let iconName: String
    var status: IntegrationStatus
    var connectedAt: Date?
    let description: String
}

// MARK: - ENVI-0829 Webhook Event Type

/// Events that can trigger a webhook notification.
enum WebhookEvent: String, Codable, CaseIterable, Identifiable {
    case contentPublished   = "content.published"
    case contentUpdated     = "content.updated"
    case contentDeleted     = "content.deleted"
    case analyticsReport    = "analytics.report"
    case followerMilestone  = "follower.milestone"
    case commentReceived    = "comment.received"
    case orderPlaced        = "order.placed"
    case campaignStarted    = "campaign.started"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .contentPublished:  return "Content Published"
        case .contentUpdated:    return "Content Updated"
        case .contentDeleted:    return "Content Deleted"
        case .analyticsReport:   return "Analytics Report"
        case .followerMilestone: return "Follower Milestone"
        case .commentReceived:   return "Comment Received"
        case .orderPlaced:       return "Order Placed"
        case .campaignStarted:   return "Campaign Started"
        }
    }
}

// MARK: - ENVI-0830 Webhook Config

/// Configuration for an outbound webhook endpoint.
struct WebhookConfig: Identifiable, Codable, Equatable {
    let id: String
    var url: String
    var events: [WebhookEvent]
    let secret: String
    var isActive: Bool
    var lastTriggeredAt: Date?

    /// Masked secret showing only the last 4 characters.
    var maskedSecret: String {
        guard secret.count > 4 else { return String(repeating: "*", count: secret.count) }
        let suffix = String(secret.suffix(4))
        return String(repeating: "*", count: secret.count - 4) + suffix
    }
}

// MARK: - ENVI-0831 API Key Permission

/// Granular permissions assignable to an API key.
enum APIKeyPermission: String, Codable, CaseIterable, Identifiable {
    case readContent   = "read:content"
    case writeContent  = "write:content"
    case readAnalytics = "read:analytics"
    case readAccount   = "read:account"
    case writeAccount  = "write:account"
    case fullAccess    = "full:access"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .readContent:   return "Read Content"
        case .writeContent:  return "Write Content"
        case .readAnalytics: return "Read Analytics"
        case .readAccount:   return "Read Account"
        case .writeAccount:  return "Write Account"
        case .fullAccess:    return "Full Access"
        }
    }
}

// MARK: - ENVI-0832 API Key

/// An API key used for programmatic access to ENVI platform services.
struct APIKey: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let key: String
    let permissions: [APIKeyPermission]
    let createdAt: Date
    var lastUsedAt: Date?
    var isActive: Bool

    /// Masked key showing only the last 6 characters.
    var maskedKey: String {
        guard key.count > 6 else { return key }
        let suffix = String(key.suffix(6))
        return String(repeating: "*", count: key.count - 6) + suffix
    }
}

// MARK: - Mock Data

extension Integration {
    static let mock: [Integration] = [
        Integration(id: "int-1", name: "Google Drive", category: .storage, iconName: "externaldrive.fill", status: .connected, connectedAt: Date().addingTimeInterval(-86400 * 30), description: "Sync content assets and backups to Google Drive."),
        Integration(id: "int-2", name: "Dropbox", category: .storage, iconName: "arrow.down.doc.fill", status: .disconnected, connectedAt: nil, description: "Store and share media files via Dropbox."),
        Integration(id: "int-3", name: "Google Analytics", category: .analytics, iconName: "chart.bar.fill", status: .connected, connectedAt: Date().addingTimeInterval(-86400 * 14), description: "Import website analytics and track campaign performance."),
        Integration(id: "int-4", name: "Mixpanel", category: .analytics, iconName: "chart.line.uptrend.xyaxis", status: .disconnected, connectedAt: nil, description: "Advanced product analytics and user behavior tracking."),
        Integration(id: "int-5", name: "Figma", category: .design, iconName: "paintbrush.fill", status: .connected, connectedAt: Date().addingTimeInterval(-86400 * 7), description: "Import design assets directly from Figma projects."),
        Integration(id: "int-6", name: "Canva", category: .design, iconName: "photo.artframe", status: .disconnected, connectedAt: nil, description: "Pull templates and graphics from Canva."),
        Integration(id: "int-7", name: "Slack", category: .communication, iconName: "number.square.fill", status: .connected, connectedAt: Date().addingTimeInterval(-86400 * 60), description: "Receive notifications and approvals in Slack channels."),
        Integration(id: "int-8", name: "Discord", category: .communication, iconName: "bubble.left.and.bubble.right.fill", status: .disconnected, connectedAt: nil, description: "Post updates and engage with your Discord community."),
        Integration(id: "int-9", name: "Shopify", category: .commerce, iconName: "cart.fill", status: .disconnected, connectedAt: nil, description: "Sync products and orders from your Shopify store."),
        Integration(id: "int-10", name: "Stripe", category: .commerce, iconName: "creditcard.fill", status: .connected, connectedAt: Date().addingTimeInterval(-86400 * 45), description: "Process payments and manage subscriptions via Stripe."),
        Integration(id: "int-11", name: "Zapier", category: .automation, iconName: "bolt.fill", status: .disconnected, connectedAt: nil, description: "Automate workflows across thousands of apps."),
        Integration(id: "int-12", name: "Make", category: .automation, iconName: "gearshape.2.fill", status: .disconnected, connectedAt: nil, description: "Build complex automation scenarios with Make."),
    ]
}

extension WebhookConfig {
    static let mock: [WebhookConfig] = [
        WebhookConfig(id: "wh-1", url: "https://hooks.example.com/envi/publish", events: [.contentPublished, .contentUpdated], secret: "whsec_abc123def456", isActive: true, lastTriggeredAt: Date().addingTimeInterval(-3600)),
        WebhookConfig(id: "wh-2", url: "https://api.myapp.io/webhooks/envi", events: [.orderPlaced, .campaignStarted], secret: "whsec_xyz789ghi012", isActive: false, lastTriggeredAt: nil),
    ]
}

extension APIKey {
    static let mock: [APIKey] = [
        APIKey(id: "key-1", name: "Production App", key: "envi_pk_live_a1b2c3d4e5f6g7h8i9j0", permissions: [.readContent, .readAnalytics], createdAt: Date().addingTimeInterval(-86400 * 90), lastUsedAt: Date().addingTimeInterval(-60), isActive: true),
        APIKey(id: "key-2", name: "Staging App", key: "envi_pk_test_z9y8x7w6v5u4t3s2r1q0", permissions: [.fullAccess], createdAt: Date().addingTimeInterval(-86400 * 30), lastUsedAt: Date().addingTimeInterval(-86400), isActive: true),
        APIKey(id: "key-3", name: "Legacy Script", key: "envi_pk_test_old_deprecated_key123", permissions: [.readContent], createdAt: Date().addingTimeInterval(-86400 * 365), lastUsedAt: nil, isActive: false),
    ]
}
