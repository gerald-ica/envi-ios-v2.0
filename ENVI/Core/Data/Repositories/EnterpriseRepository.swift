import Foundation

// MARK: - Protocol

/// Repository contract for enterprise IT, procurement, and compliance operations.
protocol EnterpriseRepository {
    // SSO (ENVI-0976..0977)
    func fetchSSOConfig() async throws -> SSOConfig
    func updateSSOConfig(_ config: SSOConfig) async throws -> SSOConfig

    // SCIM (ENVI-0978)
    func fetchSCIMConfig() async throws -> SCIMConfig

    // Procurement (ENVI-0979..0980)
    func fetchProcurements() async throws -> [ProcurementRequest]
    func createProcurement(_ request: ProcurementRequest) async throws -> ProcurementRequest

    // Contracts (ENVI-0981..0982)
    func fetchContracts() async throws -> [EnterpriseContract]

    // Compliance (ENVI-0983..0984)
    func fetchCertifications() async throws -> [ComplianceCertification]
}

// MARK: - Mock Implementation (Dev)

final class MockEnterpriseRepository: EnterpriseRepository {

    func fetchSSOConfig() async throws -> SSOConfig {
        try await Task.sleep(for: .milliseconds(400))
        return SSOConfig.mock
    }

    func updateSSOConfig(_ config: SSOConfig) async throws -> SSOConfig {
        try await Task.sleep(for: .milliseconds(300))
        return config
    }

    func fetchSCIMConfig() async throws -> SCIMConfig {
        try await Task.sleep(for: .milliseconds(350))
        return SCIMConfig.mock
    }

    func fetchProcurements() async throws -> [ProcurementRequest] {
        try await Task.sleep(for: .milliseconds(400))
        return ProcurementRequest.mock
    }

    func createProcurement(_ request: ProcurementRequest) async throws -> ProcurementRequest {
        try await Task.sleep(for: .milliseconds(300))
        return request
    }

    func fetchContracts() async throws -> [EnterpriseContract] {
        try await Task.sleep(for: .milliseconds(450))
        return EnterpriseContract.mock
    }

    func fetchCertifications() async throws -> [ComplianceCertification] {
        try await Task.sleep(for: .milliseconds(350))
        return ComplianceCertification.mock
    }
}

// MARK: - API Implementation (Staging / Prod)

final class APIEnterpriseRepository: EnterpriseRepository {

    func fetchSSOConfig() async throws -> SSOConfig {
        try await APIClient.shared.request(
            endpoint: "enterprise/sso",
            method: .get,
            requiresAuth: true
        )
    }

    func updateSSOConfig(_ config: SSOConfig) async throws -> SSOConfig {
        try await APIClient.shared.request(
            endpoint: "enterprise/sso",
            method: .put,
            body: config,
            requiresAuth: true
        )
    }

    func fetchSCIMConfig() async throws -> SCIMConfig {
        try await APIClient.shared.request(
            endpoint: "enterprise/scim",
            method: .get,
            requiresAuth: true
        )
    }

    func fetchProcurements() async throws -> [ProcurementRequest] {
        try await APIClient.shared.request(
            endpoint: "enterprise/procurements",
            method: .get,
            requiresAuth: true
        )
    }

    func createProcurement(_ request: ProcurementRequest) async throws -> ProcurementRequest {
        try await APIClient.shared.request(
            endpoint: "enterprise/procurements",
            method: .post,
            body: request,
            requiresAuth: true
        )
    }

    func fetchContracts() async throws -> [EnterpriseContract] {
        try await APIClient.shared.request(
            endpoint: "enterprise/contracts",
            method: .get,
            requiresAuth: true
        )
    }

    func fetchCertifications() async throws -> [ComplianceCertification] {
        try await APIClient.shared.request(
            endpoint: "enterprise/certifications",
            method: .get,
            requiresAuth: true
        )
    }
}

// MARK: - Factory

enum EnterpriseRepositoryProvider {
    static var shared = RepositoryProvider<EnterpriseRepository>(
        dev: MockEnterpriseRepository(),
        api: APIEnterpriseRepository()
    )
}
