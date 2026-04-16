import SwiftUI
import Combine
import RevenueCat

/// ViewModel for the billing, pricing, and usage dashboard.
/// Bridges the BillingRepository (server-side data) with PurchaseManager (RevenueCat).
@MainActor
final class BillingViewModel: ObservableObject {

    // MARK: - Published State

    @Published var plans: [SubscriptionPlan] = []
    @Published var currentSubscription: CurrentSubscription?
    @Published var usageMeters: [UsageMeter] = []
    @Published var billingHistory: [BillingHistoryEntry] = []
    @Published var teamSeats: [TeamSeat] = []
    @Published var upgradePrompts: [UpgradePrompt] = []

    @Published var selectedInterval: BillingInterval = .monthly
    @Published var isLoadingPlans = false
    @Published var isLoadingUsage = false
    @Published var isLoadingHistory = false
    @Published var isLoadingSeats = false
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let repository: BillingRepository
    private let purchaseManager: PurchaseManager

    // MARK: - Init

    init(
        repository: BillingRepository = BillingRepositoryProvider.shared.repository,
        purchaseManager: PurchaseManager? = nil
    ) {
        self.repository = repository
        self.purchaseManager = purchaseManager ?? .shared
    }

    // MARK: - Computed

    /// Plans filtered by the currently selected billing interval.
    var filteredPlans: [SubscriptionPlan] {
        plans.filter { $0.interval == selectedInterval || $0.tier == .free }
    }

    /// The user's current pricing tier, derived from subscription or defaulting to free.
    var currentTier: PricingTier {
        currentSubscription?.tier ?? .free
    }

    /// Whether the user has an active paid subscription (via RevenueCat).
    var isPaidUser: Bool {
        purchaseManager.isAuraActive
    }

    /// Plans available for upgrade (higher than current tier).
    var upgradePlans: [SubscriptionPlan] {
        filteredPlans.filter { $0.tier.rank > currentTier.rank }
    }

    // MARK: - Data Loading

    /// Load all billing data in parallel.
    func loadAll() async {
        async let plansTask: () = loadPlans()
        async let subscriptionTask: () = loadCurrentSubscription()
        async let usageTask: () = loadUsageMeters()
        async let historyTask: () = loadBillingHistory()
        _ = await (plansTask, subscriptionTask, usageTask, historyTask)
    }

    func loadPlans() async {
        isLoadingPlans = true
        errorMessage = nil
        do {
            plans = try await repository.fetchPlans()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingPlans = false
    }

    func loadCurrentSubscription() async {
        do {
            currentSubscription = try await repository.fetchCurrentSubscription()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadUsageMeters() async {
        isLoadingUsage = true
        do {
            usageMeters = try await repository.fetchUsageMeters()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingUsage = false
    }

    func loadBillingHistory() async {
        isLoadingHistory = true
        do {
            billingHistory = try await repository.fetchBillingHistory()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingHistory = false
    }

    func loadTeamSeats() async {
        isLoadingSeats = true
        do {
            teamSeats = try await repository.fetchTeamSeats()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingSeats = false
    }

    func loadUpgradePrompts(for feature: String) async {
        do {
            upgradePrompts = try await repository.fetchUpgradePrompts(feature: feature)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Upgrade / Downgrade

    /// Initiate an upgrade via RevenueCat by purchasing the corresponding package.
    func upgrade(to plan: SubscriptionPlan) async -> Bool {
        // Fetch offerings from RevenueCat to find the matching package
        await purchaseManager.fetchOfferings()

        guard let offering = purchaseManager.currentOffering else {
            errorMessage = "No offerings available."
            return false
        }

        // Match plan to RevenueCat package by product identifier
        let packageID: String = {
            switch plan.interval {
            case .monthly: return PurchaseConstants.monthlyProductID
            case .annual:  return PurchaseConstants.yearlyProductID
            }
        }()

        guard let package = offering.availablePackages.first(where: {
            $0.storeProduct.productIdentifier == packageID
        }) else {
            errorMessage = "Package not found for \(plan.name)."
            return false
        }

        let success = await purchaseManager.purchase(package)
        if success {
            await loadCurrentSubscription()
        }
        return success
    }

    /// Restore purchases through RevenueCat.
    func restorePurchases() async -> Bool {
        let restored = await purchaseManager.restorePurchases()
        if restored {
            await loadCurrentSubscription()
        }
        return restored
    }

    // MARK: - Helpers

    /// Whether the given plan is the user's current plan.
    func isCurrentPlan(_ plan: SubscriptionPlan) -> Bool {
        plan.tier == currentTier && plan.interval == selectedInterval
    }

    /// Whether the given plan is an upgrade from the current tier.
    func isUpgrade(_ plan: SubscriptionPlan) -> Bool {
        plan.tier.rank > currentTier.rank
    }

    /// CTA label for a given plan.
    func ctaLabel(for plan: SubscriptionPlan) -> String {
        if isCurrentPlan(plan) {
            return "Current Plan"
        } else if isUpgrade(plan) {
            return "Upgrade"
        } else {
            return "Downgrade"
        }
    }
}
