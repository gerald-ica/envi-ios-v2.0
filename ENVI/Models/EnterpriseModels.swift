import Foundation

// MARK: - ENVI-0976 SSO Provider

/// Supported single sign-on identity providers.
enum SSOProvider: String, Codable, CaseIterable, Identifiable {
    case okta
    case azure
    case google
    case onelogin
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .okta:     return "Okta"
        case .azure:    return "Azure AD"
        case .google:   return "Google Workspace"
        case .onelogin: return "OneLogin"
        case .custom:   return "Custom SAML"
        }
    }

    var iconName: String {
        switch self {
        case .okta:     return "shield.checkered"
        case .azure:    return "cloud.fill"
        case .google:   return "globe"
        case .onelogin: return "person.badge.key.fill"
        case .custom:   return "gearshape.2.fill"
        }
    }
}

// MARK: - ENVI-0977 SSO Configuration

/// Enterprise SSO integration configuration for a tenant domain.
struct SSOConfig: Identifiable, Codable, Equatable {
    let id: String
    var provider: SSOProvider
    var domain: String
    var isEnabled: Bool
    var metadata: [String: String]
}

extension SSOConfig {
    static let mock = SSOConfig(
        id: "sso-001",
        provider: .okta,
        domain: "acme.com",
        isEnabled: true,
        metadata: ["entityId": "https://acme.okta.com", "ssoURL": "https://acme.okta.com/sso"]
    )
}

// MARK: - ENVI-0978 SCIM Configuration

/// SCIM provisioning configuration for automated user lifecycle management.
struct SCIMConfig: Identifiable, Codable, Equatable {
    let id: String
    var endpoint: String
    var token: String
    var syncEnabled: Bool
}

extension SCIMConfig {
    static let mock = SCIMConfig(
        id: "scim-001",
        endpoint: "https://api.envi.app/scim/v2",
        token: "scim-bearer-****",
        syncEnabled: true
    )
}

// MARK: - ENVI-0979 Procurement Status

/// Lifecycle status for a procurement request.
enum ProcurementStatus: String, Codable, CaseIterable, Identifiable {
    case draft
    case pendingApproval = "pending_approval"
    case approved
    case rejected
    case completed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .draft:            return "Draft"
        case .pendingApproval:  return "Pending Approval"
        case .approved:         return "Approved"
        case .rejected:         return "Rejected"
        case .completed:        return "Completed"
        }
    }

    var iconName: String {
        switch self {
        case .draft:            return "doc.text"
        case .pendingApproval:  return "clock.fill"
        case .approved:         return "checkmark.seal.fill"
        case .rejected:         return "xmark.seal.fill"
        case .completed:        return "checkmark.circle.fill"
        }
    }
}

// MARK: - ENVI-0980 Procurement Request

/// A vendor procurement request with approval workflow.
struct ProcurementRequest: Identifiable, Codable, Equatable {
    let id: String
    var vendorName: String
    var amount: Decimal
    var status: ProcurementStatus
    var approverEmail: String
    var submittedAt: Date

    /// Formatted amount string, e.g. "$12,500.00".
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: amount as NSDecimalNumber) ?? "$\(amount)"
    }
}

extension ProcurementRequest {
    static let mock: [ProcurementRequest] = [
        ProcurementRequest(
            id: "proc-001",
            vendorName: "Adobe Creative Cloud",
            amount: 12500,
            status: .pendingApproval,
            approverEmail: "cfo@acme.com",
            submittedAt: Date().addingTimeInterval(-86400 * 3)
        ),
        ProcurementRequest(
            id: "proc-002",
            vendorName: "AWS Infrastructure",
            amount: 48000,
            status: .approved,
            approverEmail: "cto@acme.com",
            submittedAt: Date().addingTimeInterval(-86400 * 7)
        ),
        ProcurementRequest(
            id: "proc-003",
            vendorName: "Figma Enterprise",
            amount: 8400,
            status: .draft,
            approverEmail: "vp-design@acme.com",
            submittedAt: Date()
        ),
    ]
}

// MARK: - ENVI-0981 Renewal Status

/// Contract renewal lifecycle state.
enum RenewalStatus: String, Codable, CaseIterable, Identifiable {
    case active
    case pendingRenewal = "pending_renewal"
    case renewed
    case expired
    case cancelled

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .active:           return "Active"
        case .pendingRenewal:   return "Pending Renewal"
        case .renewed:          return "Renewed"
        case .expired:          return "Expired"
        case .cancelled:        return "Cancelled"
        }
    }
}

// MARK: - ENVI-0982 Enterprise Contract

/// A client contract with seat allocation, value, and renewal tracking.
struct EnterpriseContract: Identifiable, Codable, Equatable {
    let id: String
    var clientName: String
    var seats: Int
    var startDate: Date
    var endDate: Date
    var value: Decimal
    var renewalStatus: RenewalStatus

    /// Formatted contract value string.
    var formattedValue: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "$\(value)"
    }

    /// Days until contract end.
    var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0
    }
}

extension EnterpriseContract {
    static let mock: [EnterpriseContract] = [
        EnterpriseContract(
            id: "contract-001",
            clientName: "Acme Corp",
            seats: 500,
            startDate: Date().addingTimeInterval(-86400 * 180),
            endDate: Date().addingTimeInterval(86400 * 185),
            value: 125000,
            renewalStatus: .active
        ),
        EnterpriseContract(
            id: "contract-002",
            clientName: "TechStart Inc",
            seats: 50,
            startDate: Date().addingTimeInterval(-86400 * 330),
            endDate: Date().addingTimeInterval(86400 * 35),
            value: 24000,
            renewalStatus: .pendingRenewal
        ),
        EnterpriseContract(
            id: "contract-003",
            clientName: "MediaGroup LLC",
            seats: 200,
            startDate: Date().addingTimeInterval(-86400 * 90),
            endDate: Date().addingTimeInterval(86400 * 275),
            value: 72000,
            renewalStatus: .active
        ),
    ]
}

// MARK: - ENVI-0983 Compliance Status

/// Current status of a compliance certification.
enum ComplianceStatus: String, Codable, CaseIterable, Identifiable {
    case valid
    case expiringSoon = "expiring_soon"
    case expired
    case inProgress = "in_progress"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .valid:        return "Valid"
        case .expiringSoon: return "Expiring Soon"
        case .expired:      return "Expired"
        case .inProgress:   return "In Progress"
        }
    }
}

// MARK: - ENVI-0984 Compliance Certification

/// A regulatory or industry compliance certification record.
struct ComplianceCertification: Identifiable, Codable, Equatable {
    let id: String
    var standard: String
    var status: ComplianceStatus
    var expiresAt: Date
    var documentURL: URL?
}

extension ComplianceCertification {
    static let mock: [ComplianceCertification] = [
        ComplianceCertification(
            id: "cert-001",
            standard: "SOC 2 Type II",
            status: .valid,
            expiresAt: Date().addingTimeInterval(86400 * 200),
            documentURL: URL(string: "https://docs.envi.app/compliance/soc2")
        ),
        ComplianceCertification(
            id: "cert-002",
            standard: "GDPR",
            status: .valid,
            expiresAt: Date().addingTimeInterval(86400 * 365),
            documentURL: URL(string: "https://docs.envi.app/compliance/gdpr")
        ),
        ComplianceCertification(
            id: "cert-003",
            standard: "ISO 27001",
            status: .expiringSoon,
            expiresAt: Date().addingTimeInterval(86400 * 30),
            documentURL: URL(string: "https://docs.envi.app/compliance/iso27001")
        ),
    ]
}
