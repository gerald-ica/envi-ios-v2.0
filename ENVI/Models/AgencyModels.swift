import Foundation

// MARK: - Client Status

enum ClientStatus: String, Codable, CaseIterable, Identifiable {
    case active
    case paused
    case onboarding
    case churned

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .active:     return "Active"
        case .paused:     return "Paused"
        case .onboarding: return "Onboarding"
        case .churned:    return "Churned"
        }
    }

    var iconName: String {
        switch self {
        case .active:     return "checkmark.circle.fill"
        case .paused:     return "pause.circle.fill"
        case .onboarding: return "arrow.right.circle.fill"
        case .churned:    return "xmark.circle.fill"
        }
    }
}

// MARK: - Connected Platform

enum ConnectedPlatform: String, Codable, CaseIterable, Identifiable {
    case instagram
    case tiktok
    case youtube
    case twitter
    case facebook
    case linkedin
    case threads

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .instagram: return "Instagram"
        case .tiktok:    return "TikTok"
        case .youtube:   return "YouTube"
        case .twitter:   return "X"
        case .facebook:  return "Facebook"
        case .linkedin:  return "LinkedIn"
        case .threads:   return "Threads"
        }
    }

    var iconName: String {
        switch self {
        case .instagram: return "camera.circle.fill"
        case .tiktok:    return "play.circle.fill"
        case .youtube:   return "play.rectangle.fill"
        case .twitter:   return "at.circle.fill"
        case .facebook:  return "person.2.circle.fill"
        case .linkedin:  return "briefcase.circle.fill"
        case .threads:   return "at.circle.fill"
        }
    }
}

// MARK: - Client Account

struct ClientAccount: Identifiable, Codable {
    let id: UUID
    var name: String
    var industry: String
    var contactName: String
    var contactEmail: String
    var connectedPlatforms: [ConnectedPlatform]
    var status: ClientStatus
    var monthlyBudget: Double

    init(
        id: UUID = UUID(),
        name: String,
        industry: String,
        contactName: String,
        contactEmail: String,
        connectedPlatforms: [ConnectedPlatform] = [],
        status: ClientStatus = .onboarding,
        monthlyBudget: Double = 0
    ) {
        self.id = id
        self.name = name
        self.industry = industry
        self.contactName = contactName
        self.contactEmail = contactEmail
        self.connectedPlatforms = connectedPlatforms
        self.status = status
        self.monthlyBudget = monthlyBudget
    }

    var formattedBudget: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: monthlyBudget)) ?? "$0"
    }

    static let mock = ClientAccount(
        name: "Bloom Skincare",
        industry: "Beauty & Wellness",
        contactName: "Ava Torres",
        contactEmail: "ava@bloomskincare.com",
        connectedPlatforms: [.instagram, .tiktok, .youtube],
        status: .active,
        monthlyBudget: 8500
    )

    static let mockList: [ClientAccount] = [
        ClientAccount(
            name: "Bloom Skincare",
            industry: "Beauty & Wellness",
            contactName: "Ava Torres",
            contactEmail: "ava@bloomskincare.com",
            connectedPlatforms: [.instagram, .tiktok, .youtube],
            status: .active,
            monthlyBudget: 8500
        ),
        ClientAccount(
            name: "Apex Fitness",
            industry: "Health & Fitness",
            contactName: "Jordan Lee",
            contactEmail: "jordan@apexfit.io",
            connectedPlatforms: [.instagram, .youtube, .twitter],
            status: .active,
            monthlyBudget: 12000
        ),
        ClientAccount(
            name: "Nomad Coffee Co.",
            industry: "Food & Beverage",
            contactName: "Sam Rivera",
            contactEmail: "sam@nomadcoffee.co",
            connectedPlatforms: [.instagram, .tiktok, .threads],
            status: .active,
            monthlyBudget: 5000
        ),
        ClientAccount(
            name: "Volt EV",
            industry: "Automotive",
            contactName: "Priya Sharma",
            contactEmail: "priya@voltev.com",
            connectedPlatforms: [.youtube, .linkedin, .twitter],
            status: .onboarding,
            monthlyBudget: 20000
        ),
        ClientAccount(
            name: "Dwell Interiors",
            industry: "Home & Design",
            contactName: "Marcus Chen",
            contactEmail: "marcus@dwellinteriors.com",
            connectedPlatforms: [.instagram],
            status: .paused,
            monthlyBudget: 3500
        ),
    ]
}

// MARK: - Portal Permission

enum PortalPermission: String, Codable, CaseIterable, Identifiable {
    case viewReports
    case approveContent
    case manageCalendar
    case editBranding
    case downloadAssets

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .viewReports:    return "View Reports"
        case .approveContent: return "Approve Content"
        case .manageCalendar: return "Manage Calendar"
        case .editBranding:   return "Edit Branding"
        case .downloadAssets: return "Download Assets"
        }
    }

    var iconName: String {
        switch self {
        case .viewReports:    return "chart.bar"
        case .approveContent: return "checkmark.seal"
        case .manageCalendar: return "calendar"
        case .editBranding:   return "paintbrush"
        case .downloadAssets: return "arrow.down.circle"
        }
    }
}

// MARK: - Client Portal

struct ClientPortal: Identifiable, Codable {
    let id: UUID
    var clientID: UUID
    var shareURL: String
    var permissions: [PortalPermission]
    var lastViewed: Date?

    init(
        id: UUID = UUID(),
        clientID: UUID = UUID(),
        shareURL: String = "",
        permissions: [PortalPermission] = [.viewReports],
        lastViewed: Date? = nil
    ) {
        self.id = id
        self.clientID = clientID
        self.shareURL = shareURL
        self.permissions = permissions
        self.lastViewed = lastViewed
    }

    var isExpired: Bool { false }

    static let mock = ClientPortal(
        shareURL: "https://portal.envi.app/bloom-skincare/abc123",
        permissions: [.viewReports, .approveContent, .downloadAssets],
        lastViewed: Date().addingTimeInterval(-3600 * 4)
    )
}

// MARK: - Report Section

enum ReportSectionType: String, Codable, CaseIterable, Identifiable {
    case overview
    case engagement
    case growth
    case topContent
    case audienceDemographics
    case recommendations

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .overview:              return "Overview"
        case .engagement:            return "Engagement"
        case .growth:                return "Growth"
        case .topContent:            return "Top Content"
        case .audienceDemographics:  return "Audience Demographics"
        case .recommendations:       return "Recommendations"
        }
    }
}

// MARK: - Branding Override

struct BrandingOverride: Codable {
    var logoURL: String?
    var primaryColor: String?
    var agencyName: String?
    var footerText: String?

    static let mock = BrandingOverride(
        agencyName: "Neon Digital Agency",
        footerText: "Powered by Neon Digital"
    )
}

// MARK: - White Label Report

struct WhiteLabelReport: Identifiable, Codable {
    let id: UUID
    var clientID: UUID
    var title: String
    var dateRange: DateRange
    var sections: [ReportSectionType]
    var brandingOverride: BrandingOverride?

    init(
        id: UUID = UUID(),
        clientID: UUID = UUID(),
        title: String,
        dateRange: DateRange,
        sections: [ReportSectionType] = ReportSectionType.allCases,
        brandingOverride: BrandingOverride? = nil
    ) {
        self.id = id
        self.clientID = clientID
        self.title = title
        self.dateRange = dateRange
        self.sections = sections
        self.brandingOverride = brandingOverride
    }

    static let mock = WhiteLabelReport(
        title: "Bloom Skincare — March 2026",
        dateRange: DateRange(start: Date().addingTimeInterval(-86400 * 30), end: Date()),
        sections: [.overview, .engagement, .growth, .topContent],
        brandingOverride: .mock
    )
}

// MARK: - Date Range

struct DateRange: Codable {
    var start: Date
    var end: Date

    var formatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }
}

// MARK: - Agency Dashboard

struct AgencyDashboard: Codable {
    var totalClients: Int
    var activeClients: Int
    var totalRevenue: Double
    var pendingApprovals: Int

    init(
        totalClients: Int = 0,
        activeClients: Int = 0,
        totalRevenue: Double = 0,
        pendingApprovals: Int = 0
    ) {
        self.totalClients = totalClients
        self.activeClients = activeClients
        self.totalRevenue = totalRevenue
        self.pendingApprovals = pendingApprovals
    }

    var formattedRevenue: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: totalRevenue)) ?? "$0"
    }

    var clientRetentionRate: Double {
        guard totalClients > 0 else { return 0 }
        return Double(activeClients) / Double(totalClients) * 100
    }

    static let mock = AgencyDashboard(
        totalClients: 14,
        activeClients: 11,
        totalRevenue: 87500,
        pendingApprovals: 5
    )
}
