import SwiftUI
import Combine

/// ViewModel for the Security, Privacy, Compliance, and Governance feature set.
final class SecurityViewModel: ObservableObject {
    // MARK: - Policies
    @Published var policies: [SecurityPolicy] = []
    @Published var isLoadingPolicies = false

    // MARK: - Privacy
    @Published var privacySettings: PrivacySettings = .mock
    @Published var isLoadingPrivacy = false
    @Published var isSavingPrivacy = false
    @Published var privacySaved = false

    // MARK: - Audit Log
    @Published var auditLog: [AuditLogEntry] = []
    @Published var isLoadingAuditLog = false
    @Published var auditSearchText = ""
    @Published var auditActionFilter: String?

    // MARK: - Compliance
    @Published var complianceChecks: [ComplianceCheck] = []
    @Published var isLoadingCompliance = false
    @Published var complianceStatusFilter: ComplianceStatus?

    // MARK: - Retention
    @Published var retentionPolicies: [DataRetentionPolicy] = []
    @Published var isLoadingRetention = false

    // MARK: - General
    @Published var errorMessage: String?

    private let repository: SecurityRepository

    init(repository: SecurityRepository = SecurityRepositoryProvider.shared.repository) {
        self.repository = repository
    }

    // MARK: - Filtered Audit Log

    var filteredAuditLog: [AuditLogEntry] {
        var entries = auditLog

        if let filter = auditActionFilter {
            entries = entries.filter { $0.action.localizedCaseInsensitiveContains(filter) }
        }

        if !auditSearchText.isEmpty {
            entries = entries.filter {
                $0.actor.localizedCaseInsensitiveContains(auditSearchText) ||
                $0.action.localizedCaseInsensitiveContains(auditSearchText) ||
                $0.resource.localizedCaseInsensitiveContains(auditSearchText)
            }
        }

        return entries
    }

    /// Unique action strings for filter chips.
    var uniqueActions: [String] {
        Array(Set(auditLog.map { $0.action })).sorted()
    }

    // MARK: - Filtered Compliance

    var filteredCompliance: [ComplianceCheck] {
        guard let filter = complianceStatusFilter else { return complianceChecks }
        return complianceChecks.filter { $0.status == filter }
    }

    // MARK: - Load All

    @MainActor
    func loadAll() async {
        async let p: () = loadPolicies()
        async let pr: () = loadPrivacy()
        async let a: () = loadAuditLog()
        async let c: () = loadCompliance()
        async let r: () = loadRetention()
        _ = await (p, pr, a, c, r)
    }

    // MARK: - Policies

    @MainActor
    func loadPolicies() async {
        isLoadingPolicies = true
        errorMessage = nil
        do {
            policies = try await repository.fetchPolicies()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingPolicies = false
    }

    // MARK: - Privacy Settings

    @MainActor
    func loadPrivacy() async {
        isLoadingPrivacy = true
        errorMessage = nil
        do {
            privacySettings = try await repository.fetchPrivacySettings()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingPrivacy = false
    }

    @MainActor
    func savePrivacy() async {
        isSavingPrivacy = true
        privacySaved = false
        errorMessage = nil
        do {
            privacySettings = try await repository.updatePrivacySettings(privacySettings)
            privacySaved = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isSavingPrivacy = false
    }

    // MARK: - Audit Log

    @MainActor
    func loadAuditLog() async {
        isLoadingAuditLog = true
        errorMessage = nil
        do {
            auditLog = try await repository.fetchAuditLog()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingAuditLog = false
    }

    // MARK: - Compliance

    @MainActor
    func loadCompliance() async {
        isLoadingCompliance = true
        errorMessage = nil
        do {
            complianceChecks = try await repository.fetchComplianceChecks()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingCompliance = false
    }

    // MARK: - Retention

    @MainActor
    func loadRetention() async {
        isLoadingRetention = true
        errorMessage = nil
        do {
            retentionPolicies = try await repository.fetchRetentionPolicies()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingRetention = false
    }
}
