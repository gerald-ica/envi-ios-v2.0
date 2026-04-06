import Foundation

// MARK: - Protocol

protocol AgencyRepository {
    // Clients
    func fetchClients() async throws -> [ClientAccount]
    func createClient(_ client: ClientAccount) async throws -> ClientAccount

    // Portal
    func fetchPortal(clientID: UUID) async throws -> ClientPortal
    func updatePortal(_ portal: ClientPortal) async throws -> ClientPortal

    // Reports
    func generateReport(clientID: UUID, range: DateRange) async throws -> WhiteLabelReport

    // Dashboard
    func fetchDashboard() async throws -> AgencyDashboard
}

// MARK: - Mock Implementation

final class MockAgencyRepository: AgencyRepository {
    private var clients: [ClientAccount] = ClientAccount.mockList

    func fetchClients() async throws -> [ClientAccount] {
        clients
    }

    func createClient(_ client: ClientAccount) async throws -> ClientAccount {
        clients.insert(client, at: 0)
        return client
    }

    func fetchPortal(clientID: UUID) async throws -> ClientPortal {
        guard clients.contains(where: { $0.id == clientID }) else {
            throw AgencyError.clientNotFound
        }
        return ClientPortal(
            clientID: clientID,
            shareURL: "https://portal.envi.app/\(clientID.uuidString.prefix(8))",
            permissions: [.viewReports, .approveContent, .downloadAssets],
            lastViewed: Date().addingTimeInterval(-3600 * 2)
        )
    }

    func updatePortal(_ portal: ClientPortal) async throws -> ClientPortal {
        portal
    }

    func generateReport(clientID: UUID, range: DateRange) async throws -> WhiteLabelReport {
        guard let client = clients.first(where: { $0.id == clientID }) else {
            throw AgencyError.clientNotFound
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let title = "\(client.name) — \(formatter.string(from: range.end))"
        return WhiteLabelReport(
            clientID: clientID,
            title: title,
            dateRange: range,
            brandingOverride: .mock
        )
    }

    func fetchDashboard() async throws -> AgencyDashboard {
        AgencyDashboard.mock
    }
}

// MARK: - API Implementation

final class APIAgencyRepository: AgencyRepository {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchClients() async throws -> [ClientAccount] {
        try await apiClient.request(
            endpoint: "agency/clients",
            method: .get,
            requiresAuth: true
        )
    }

    func createClient(_ client: ClientAccount) async throws -> ClientAccount {
        try await apiClient.request(
            endpoint: "agency/clients",
            method: .post,
            body: client,
            requiresAuth: true
        )
    }

    func fetchPortal(clientID: UUID) async throws -> ClientPortal {
        try await apiClient.request(
            endpoint: "agency/portals/\(clientID.uuidString)",
            method: .get,
            requiresAuth: true
        )
    }

    func updatePortal(_ portal: ClientPortal) async throws -> ClientPortal {
        try await apiClient.request(
            endpoint: "agency/portals/\(portal.id.uuidString)",
            method: .put,
            body: portal,
            requiresAuth: true
        )
    }

    func generateReport(clientID: UUID, range: DateRange) async throws -> WhiteLabelReport {
        try await apiClient.request(
            endpoint: "agency/reports",
            method: .post,
            body: ReportGenerateBody(clientID: clientID, range: range),
            requiresAuth: true
        )
    }

    func fetchDashboard() async throws -> AgencyDashboard {
        try await apiClient.request(
            endpoint: "agency/dashboard",
            method: .get,
            requiresAuth: true
        )
    }
}

// MARK: - Request Bodies

private struct ReportGenerateBody: Encodable {
    let clientID: UUID
    let range: DateRange
}

// MARK: - Error

enum AgencyError: LocalizedError {
    case clientNotFound
    case portalUnavailable
    case reportGenerationFailed

    var errorDescription: String? {
        switch self {
        case .clientNotFound:         return "The requested client account was not found."
        case .portalUnavailable:      return "The client portal is currently unavailable."
        case .reportGenerationFailed: return "Failed to generate the report. Please try again."
        }
    }
}

// MARK: - Provider

enum AgencyRepositoryProvider {
    static var shared = Shared(repository: defaultRepository())

    struct Shared {
        var repository: AgencyRepository
    }

    private static func defaultRepository() -> AgencyRepository {
        switch AppEnvironment.current {
        case .dev:
            return MockAgencyRepository()
        case .staging, .prod:
            return APIAgencyRepository()
        }
    }
}
