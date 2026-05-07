import Foundation

// MARK: - Protocol

/// Repository contract for integrations, webhooks, and API key operations (ENVI-0826..0850).
protocol IntegrationRepository {
    // Integrations
    func fetchIntegrations() async throws -> [Integration]
    func connectIntegration(id: String) async throws -> Integration
    func disconnectIntegration(id: String) async throws -> Integration

    // Webhooks
    func fetchWebhooks() async throws -> [WebhookConfig]
    func createWebhook(_ webhook: WebhookConfig) async throws -> WebhookConfig
    func deleteWebhook(id: String) async throws

    // API Keys
    func fetchAPIKeys() async throws -> [APIKey]
    func createAPIKey(name: String, permissions: [APIKeyPermission]) async throws -> APIKey
    func revokeAPIKey(id: String) async throws
}

// MARK: - Mock Implementation (Dev)

final class MockIntegrationRepository: IntegrationRepository {

    private var integrations = Integration.mock
    private var webhooks = WebhookConfig.mock
    private var apiKeys = APIKey.mock

    func fetchIntegrations() async throws -> [Integration] {
        try await Task.sleep(for: .milliseconds(400))
        return integrations
    }

    func connectIntegration(id: String) async throws -> Integration {
        try await Task.sleep(for: .milliseconds(600))
        guard let idx = integrations.firstIndex(where: { $0.id == id }) else {
            throw URLError(.badURL)
        }
        integrations[idx].status = .connected
        integrations[idx].connectedAt = Date()
        return integrations[idx]
    }

    func disconnectIntegration(id: String) async throws -> Integration {
        try await Task.sleep(for: .milliseconds(400))
        guard let idx = integrations.firstIndex(where: { $0.id == id }) else {
            throw URLError(.badURL)
        }
        integrations[idx].status = .disconnected
        integrations[idx].connectedAt = nil
        return integrations[idx]
    }

    func fetchWebhooks() async throws -> [WebhookConfig] {
        try await Task.sleep(for: .milliseconds(350))
        return webhooks
    }

    func createWebhook(_ webhook: WebhookConfig) async throws -> WebhookConfig {
        try await Task.sleep(for: .milliseconds(500))
        webhooks.append(webhook)
        return webhook
    }

    func deleteWebhook(id: String) async throws {
        try await Task.sleep(for: .milliseconds(300))
        webhooks.removeAll { $0.id == id }
    }

    func fetchAPIKeys() async throws -> [APIKey] {
        try await Task.sleep(for: .milliseconds(350))
        return apiKeys
    }

    func createAPIKey(name: String, permissions: [APIKeyPermission]) async throws -> APIKey {
        try await Task.sleep(for: .milliseconds(500))
        let key = APIKey(
            id: "key-\(UUID().uuidString.prefix(8))",
            name: name,
            key: "envi_pk_live_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(24))",
            permissions: permissions,
            createdAt: Date(),
            lastUsedAt: nil,
            isActive: true
        )
        apiKeys.append(key)
        return key
    }

    func revokeAPIKey(id: String) async throws {
        try await Task.sleep(for: .milliseconds(300))
        if let idx = apiKeys.firstIndex(where: { $0.id == id }) {
            apiKeys[idx].isActive = false
        }
    }
}

// MARK: - Request Bodies

private struct CreateAPIKeyBody: Encodable {
    let name: String
    let permissions: [APIKeyPermission]
}

// MARK: - API Implementation (Staging / Prod)

final class APIIntegrationRepository: IntegrationRepository {

    func fetchIntegrations() async throws -> [Integration] {
        try await APIClient.shared.request(
            endpoint: "integrations/",
            method: .get,
            requiresAuth: true
        )
    }

    func connectIntegration(id: String) async throws -> Integration {
        try await APIClient.shared.request(
            endpoint: "integrations/\(id)/connect",
            method: .post,
            requiresAuth: true
        )
    }

    func disconnectIntegration(id: String) async throws -> Integration {
        try await APIClient.shared.request(
            endpoint: "integrations/\(id)/disconnect",
            method: .post,
            requiresAuth: true
        )
    }

    func fetchWebhooks() async throws -> [WebhookConfig] {
        try await APIClient.shared.request(
            endpoint: "integrations/webhooks",
            method: .get,
            requiresAuth: true
        )
    }

    func createWebhook(_ webhook: WebhookConfig) async throws -> WebhookConfig {
        try await APIClient.shared.request(
            endpoint: "integrations/webhooks",
            method: .post,
            body: webhook,
            requiresAuth: true
        )
    }

    func deleteWebhook(id: String) async throws {
        try await APIClient.shared.requestVoid(
            endpoint: "integrations/webhooks/\(id)",
            method: .delete,
            requiresAuth: true
        )
    }

    func fetchAPIKeys() async throws -> [APIKey] {
        try await APIClient.shared.request(
            endpoint: "integrations/api-keys",
            method: .get,
            requiresAuth: true
        )
    }

    func createAPIKey(name: String, permissions: [APIKeyPermission]) async throws -> APIKey {
        let body = CreateAPIKeyBody(name: name, permissions: permissions)
        return try await APIClient.shared.request(
            endpoint: "integrations/api-keys",
            method: .post,
            body: body,
            requiresAuth: true
        )
    }

    func revokeAPIKey(id: String) async throws {
        try await APIClient.shared.requestVoid(
            endpoint: "integrations/api-keys/\(id)/revoke",
            method: .post,
            requiresAuth: true
        )
    }
}

// MARK: - Factory

@MainActor
enum IntegrationRepositoryProvider {
    static nonisolated(unsafe) var shared = RepositoryProvider<IntegrationRepository>(
        dev: MockIntegrationRepository(),
        api: APIIntegrationRepository()
    )
}
