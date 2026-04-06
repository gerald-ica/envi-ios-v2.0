import SwiftUI
import Combine

/// ViewModel powering the Integrations, Webhooks, and API Keys feature set (ENVI-0826..0850).
@MainActor
final class IntegrationViewModel: ObservableObject {

    // MARK: - Published State

    @Published var integrations: [Integration] = []
    @Published var webhooks: [WebhookConfig] = []
    @Published var apiKeys: [APIKey] = []

    @Published var selectedCategory: IntegrationCategory?
    @Published var searchText = ""

    @Published var isLoadingIntegrations = false
    @Published var isLoadingWebhooks = false
    @Published var isLoadingAPIKeys = false
    @Published var isConnecting = false

    @Published var errorMessage: String?
    @Published var successMessage: String?

    /// Temporarily stores a newly created API key so the user can copy it once.
    @Published var newlyCreatedKey: APIKey?

    // MARK: - Dependencies

    private let repository: IntegrationRepository

    // MARK: - Init

    init(repository: IntegrationRepository = IntegrationRepositoryProvider.shared.repository) {
        self.repository = repository
    }

    // MARK: - Computed

    /// Integrations filtered by selected category and search text.
    var filteredIntegrations: [Integration] {
        var results = integrations
        if let cat = selectedCategory {
            results = results.filter { $0.category == cat }
        }
        if !searchText.isEmpty {
            results = results.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        return results
    }

    /// Connected integrations count.
    var connectedCount: Int {
        integrations.filter { $0.status == .connected }.count
    }

    /// Active webhooks count.
    var activeWebhookCount: Int {
        webhooks.filter { $0.isActive }.count
    }

    /// Active API keys count.
    var activeAPIKeyCount: Int {
        apiKeys.filter { $0.isActive }.count
    }

    // MARK: - Data Loading

    /// Load all integration data in parallel.
    func loadAll() async {
        async let i: () = loadIntegrations()
        async let w: () = loadWebhooks()
        async let k: () = loadAPIKeys()
        _ = await (i, w, k)
    }

    func loadIntegrations() async {
        isLoadingIntegrations = true
        defer { isLoadingIntegrations = false }
        do {
            integrations = try await repository.fetchIntegrations()
        } catch {
            errorMessage = "Failed to load integrations: \(error.localizedDescription)"
        }
    }

    func loadWebhooks() async {
        isLoadingWebhooks = true
        defer { isLoadingWebhooks = false }
        do {
            webhooks = try await repository.fetchWebhooks()
        } catch {
            errorMessage = "Failed to load webhooks: \(error.localizedDescription)"
        }
    }

    func loadAPIKeys() async {
        isLoadingAPIKeys = true
        defer { isLoadingAPIKeys = false }
        do {
            apiKeys = try await repository.fetchAPIKeys()
        } catch {
            errorMessage = "Failed to load API keys: \(error.localizedDescription)"
        }
    }

    // MARK: - Integration Actions

    func connect(integrationId: String) async {
        isConnecting = true
        defer { isConnecting = false }
        do {
            let updated = try await repository.connectIntegration(id: integrationId)
            if let idx = integrations.firstIndex(where: { $0.id == integrationId }) {
                integrations[idx] = updated
            }
            successMessage = "\(updated.name) connected"
        } catch {
            errorMessage = "Failed to connect: \(error.localizedDescription)"
        }
    }

    func disconnect(integrationId: String) async {
        do {
            let updated = try await repository.disconnectIntegration(id: integrationId)
            if let idx = integrations.firstIndex(where: { $0.id == integrationId }) {
                integrations[idx] = updated
            }
            successMessage = "\(updated.name) disconnected"
        } catch {
            errorMessage = "Failed to disconnect: \(error.localizedDescription)"
        }
    }

    // MARK: - Webhook Actions

    func createWebhook(url: String, events: [WebhookEvent]) async {
        let webhook = WebhookConfig(
            id: "wh-\(UUID().uuidString.prefix(8))",
            url: url,
            events: events,
            secret: "whsec_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16))",
            isActive: true,
            lastTriggeredAt: nil
        )
        do {
            let created = try await repository.createWebhook(webhook)
            webhooks.append(created)
            successMessage = "Webhook created"
        } catch {
            errorMessage = "Failed to create webhook: \(error.localizedDescription)"
        }
    }

    func deleteWebhook(id: String) async {
        do {
            try await repository.deleteWebhook(id: id)
            webhooks.removeAll { $0.id == id }
            successMessage = "Webhook deleted"
        } catch {
            errorMessage = "Failed to delete webhook: \(error.localizedDescription)"
        }
    }

    func testWebhook(id: String) {
        // Simulates sending a test event — in production this would trigger a real ping.
        successMessage = "Test event sent"
    }

    // MARK: - API Key Actions

    func createAPIKey(name: String, permissions: [APIKeyPermission]) async {
        do {
            let key = try await repository.createAPIKey(name: name, permissions: permissions)
            apiKeys.append(key)
            newlyCreatedKey = key
            successMessage = "API key created — copy it now, it won't be shown again"
        } catch {
            errorMessage = "Failed to create API key: \(error.localizedDescription)"
        }
    }

    func revokeAPIKey(id: String) async {
        do {
            try await repository.revokeAPIKey(id: id)
            if let idx = apiKeys.firstIndex(where: { $0.id == id }) {
                apiKeys[idx].isActive = false
            }
            successMessage = "API key revoked"
        } catch {
            errorMessage = "Failed to revoke API key: \(error.localizedDescription)"
        }
    }

    func dismissNewKeyAlert() {
        newlyCreatedKey = nil
    }
}
