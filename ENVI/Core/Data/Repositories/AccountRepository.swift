import Foundation

// MARK: - Protocol

/// Repository contract for account management operations.
protocol AccountRepository {
    func fetchSessions() async throws -> [DeviceSession]
    func revokeSession(id: String) async throws
    func fetchLoginHistory() async throws -> [LoginActivity]
    func requestDataExport() async throws -> DataExportResponse
    func fetchConsents() async throws -> [ConsentRecord]
    func updateCreatorProfile(_ profile: CreatorProfile) async throws
}

// MARK: - Mock Implementation (Dev)

final class MockAccountRepository: AccountRepository {
    func fetchSessions() async throws -> [DeviceSession] {
        try await Task.sleep(for: .milliseconds(400))
        return DeviceSession.mock
    }

    func revokeSession(id: String) async throws {
        try await Task.sleep(for: .milliseconds(300))
    }

    func fetchLoginHistory() async throws -> [LoginActivity] {
        try await Task.sleep(for: .milliseconds(400))
        return LoginActivity.mock
    }

    func requestDataExport() async throws -> DataExportResponse {
        try await Task.sleep(for: .milliseconds(500))
        return DataExportResponse(
            requestId: UUID().uuidString,
            status: "processing",
            estimatedReadyAt: Date().addingTimeInterval(3600)
        )
    }

    func fetchConsents() async throws -> [ConsentRecord] {
        try await Task.sleep(for: .milliseconds(300))
        return ConsentRecord.mock
    }

    func updateCreatorProfile(_ profile: CreatorProfile) async throws {
        try await Task.sleep(for: .milliseconds(400))
    }
}

// MARK: - API Implementation (Staging / Prod)

final class APIAccountRepository: AccountRepository {
    func fetchSessions() async throws -> [DeviceSession] {
        try await APIClient.shared.request(
            endpoint: "account/sessions",
            method: .get,
            requiresAuth: true
        )
    }

    func revokeSession(id: String) async throws {
        try await APIClient.shared.requestVoid(
            endpoint: "account/sessions/\(id)",
            method: .delete,
            requiresAuth: true
        )
    }

    func fetchLoginHistory() async throws -> [LoginActivity] {
        try await APIClient.shared.request(
            endpoint: "account/login-history",
            method: .get,
            requiresAuth: true
        )
    }

    func requestDataExport() async throws -> DataExportResponse {
        try await APIClient.shared.request(
            endpoint: "account/data-export",
            method: .post,
            body: Optional<String>.none,
            requiresAuth: true
        )
    }

    func fetchConsents() async throws -> [ConsentRecord] {
        try await APIClient.shared.request(
            endpoint: "account/consents",
            method: .get,
            requiresAuth: true
        )
    }

    func updateCreatorProfile(_ profile: CreatorProfile) async throws {
        try await APIClient.shared.requestVoid(
            endpoint: "account/creator-profile",
            method: .put,
            body: profile,
            requiresAuth: true
        )
    }
}

// MARK: - Factory

enum AccountRepositoryProvider {
    static var shared = RepositoryProvider<AccountRepository>(
        dev: MockAccountRepository(),
        api: APIAccountRepository()
    )
}
