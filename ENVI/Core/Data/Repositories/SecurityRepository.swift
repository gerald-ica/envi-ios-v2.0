import Foundation

// MARK: - Protocol

protocol SecurityRepository {
    func fetchPolicies() async throws -> [SecurityPolicy]
    func fetchPrivacySettings() async throws -> PrivacySettings
    func updatePrivacySettings(_ settings: PrivacySettings) async throws -> PrivacySettings
    func fetchAuditLog() async throws -> [AuditLogEntry]
    func fetchComplianceChecks() async throws -> [ComplianceCheck]
    func fetchRetentionPolicies() async throws -> [DataRetentionPolicy]
}

// MARK: - Mock Implementation

final class MockSecurityRepository: SecurityRepository {
    private var policies: [SecurityPolicy] = SecurityPolicy.mockList
    private var privacy: PrivacySettings = .mock
    private var auditLog: [AuditLogEntry] = AuditLogEntry.mockList
    private var compliance: [ComplianceCheck] = ComplianceCheck.mockList
    private var retention: [DataRetentionPolicy] = DataRetentionPolicy.mockList

    func fetchPolicies() async throws -> [SecurityPolicy] {
        policies
    }

    func fetchPrivacySettings() async throws -> PrivacySettings {
        privacy
    }

    func updatePrivacySettings(_ settings: PrivacySettings) async throws -> PrivacySettings {
        privacy = settings
        return privacy
    }

    func fetchAuditLog() async throws -> [AuditLogEntry] {
        auditLog
    }

    func fetchComplianceChecks() async throws -> [ComplianceCheck] {
        compliance
    }

    func fetchRetentionPolicies() async throws -> [DataRetentionPolicy] {
        retention
    }
}

// MARK: - API Implementation

final class APISecurityRepository: SecurityRepository {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchPolicies() async throws -> [SecurityPolicy] {
        try await apiClient.request(
            endpoint: "security/policies",
            method: .get,
            requiresAuth: true
        )
    }

    func fetchPrivacySettings() async throws -> PrivacySettings {
        try await apiClient.request(
            endpoint: "security/privacy",
            method: .get,
            requiresAuth: true
        )
    }

    func updatePrivacySettings(_ settings: PrivacySettings) async throws -> PrivacySettings {
        try await apiClient.request(
            endpoint: "security/privacy",
            method: .put,
            body: settings,
            requiresAuth: true
        )
    }

    func fetchAuditLog() async throws -> [AuditLogEntry] {
        try await apiClient.request(
            endpoint: "security/audit-log",
            method: .get,
            requiresAuth: true
        )
    }

    func fetchComplianceChecks() async throws -> [ComplianceCheck] {
        try await apiClient.request(
            endpoint: "security/compliance",
            method: .get,
            requiresAuth: true
        )
    }

    func fetchRetentionPolicies() async throws -> [DataRetentionPolicy] {
        try await apiClient.request(
            endpoint: "security/retention",
            method: .get,
            requiresAuth: true
        )
    }
}

// MARK: - Provider

@MainActor
enum SecurityRepositoryProvider {
    static nonisolated(unsafe) var shared = RepositoryProvider<SecurityRepository>(
        dev: MockSecurityRepository(),
        api: APISecurityRepository()
    )
}
