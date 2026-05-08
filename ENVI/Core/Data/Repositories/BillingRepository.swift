import Foundation

// MARK: - Protocol

/// Repository contract for billing, pricing, and subscription operations.
protocol BillingRepository {
    func fetchPlans() async throws -> [SubscriptionPlan]
    func fetchCurrentSubscription() async throws -> CurrentSubscription?
    func fetchUsageMeters() async throws -> [UsageMeter]
    func fetchBillingHistory() async throws -> [BillingHistoryEntry]
    func fetchUpgradePrompts(feature: String) async throws -> [UpgradePrompt]
    func fetchTeamSeats() async throws -> [TeamSeat]
}

// MARK: - Mock Implementation (Dev)

final class MockBillingRepository: BillingRepository {

    func fetchPlans() async throws -> [SubscriptionPlan] {
        try await Task.sleep(for: .milliseconds(400))
        return SubscriptionPlan.mock
    }

    func fetchCurrentSubscription() async throws -> CurrentSubscription? {
        try await Task.sleep(for: .milliseconds(300))
        return CurrentSubscription.mock
    }

    func fetchUsageMeters() async throws -> [UsageMeter] {
        try await Task.sleep(for: .milliseconds(350))
        return UsageMeter.mock
    }

    func fetchBillingHistory() async throws -> [BillingHistoryEntry] {
        try await Task.sleep(for: .milliseconds(400))
        return BillingHistoryEntry.mock
    }

    func fetchUpgradePrompts(feature: String) async throws -> [UpgradePrompt] {
        try await Task.sleep(for: .milliseconds(200))
        return UpgradePrompt.mock.filter {
            feature.isEmpty || $0.feature.localizedCaseInsensitiveContains(feature)
        }
    }

    func fetchTeamSeats() async throws -> [TeamSeat] {
        try await Task.sleep(for: .milliseconds(350))
        return TeamSeat.mock
    }
}

// MARK: - API Implementation (Staging / Prod)

final class APIBillingRepository: BillingRepository {

    func fetchPlans() async throws -> [SubscriptionPlan] {
        try await APIClient.shared.request(
            endpoint: "billing/plans",
            method: .get,
            requiresAuth: true
        )
    }

    func fetchCurrentSubscription() async throws -> CurrentSubscription? {
        try await APIClient.shared.request(
            endpoint: "billing/subscription",
            method: .get,
            requiresAuth: true
        )
    }

    func fetchUsageMeters() async throws -> [UsageMeter] {
        try await APIClient.shared.request(
            endpoint: "billing/usage",
            method: .get,
            requiresAuth: true
        )
    }

    func fetchBillingHistory() async throws -> [BillingHistoryEntry] {
        try await APIClient.shared.request(
            endpoint: "billing/history",
            method: .get,
            requiresAuth: true
        )
    }

    func fetchUpgradePrompts(feature: String) async throws -> [UpgradePrompt] {
        try await APIClient.shared.request(
            endpoint: "billing/upgrade-prompts?feature=\(feature)",
            method: .get,
            requiresAuth: true
        )
    }

    func fetchTeamSeats() async throws -> [TeamSeat] {
        try await APIClient.shared.request(
            endpoint: "billing/seats",
            method: .get,
            requiresAuth: true
        )
    }
}

// MARK: - Factory

@MainActor
enum BillingRepositoryProvider {
    static nonisolated(unsafe) var shared = RepositoryProvider<BillingRepository>(
        dev: MockBillingRepository(),
        api: APIBillingRepository()
    )
}
