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

    private nonisolated(unsafe) let repository: BillingRepository
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

    /// Map a UI-side `PricingTier` + `BillingInterval` to a RevenueCat
    /// offering ID + package lookup key.
    ///
    /// The audit pricing model has 3 paywalls (`default` for Aura,
    /// `aura_pro` for the studio plan, `power` for the add-on). Each
    /// offering exposes two packages: `$rc_monthly` and `$rc_annual`.
    /// `enterprise` returns nil — that tier is contact-sales, not IAP.
    private func offeringRoute(for tier: PricingTier, interval: BillingInterval)
        -> (offeringID: String, packageID: String)?
    {
        let pkgID = interval == .monthly
            ? PurchaseConstants.monthlyPackageID
            : PurchaseConstants.annualPackageID
        switch tier {
        case .free:
            return nil
        case .creator:
            return (PurchaseConstants.defaultOfferingID, pkgID)
        case .pro:
            return (PurchaseConstants.auraProOfferingID, pkgID)
        case .team, .agency:
            return (PurchaseConstants.powerOfferingID, pkgID)
        case .enterprise:
            return nil
        }
    }

    /// Initiate an upgrade via RevenueCat by purchasing the package
    /// behind the plan's tier.
    ///
    /// Routes to the right offering automatically:
    /// - `.creator` → `default` (Aura)
    /// - `.pro`     → `aura_pro` (Aura Pro)
    /// - `.team`/`.agency` → `power` (Power add-on, requires Aura Pro)
    /// - `.enterprise` → returns false (contact sales)
    func upgrade(to plan: SubscriptionPlan) async -> Bool {
        guard let route = offeringRoute(for: plan.tier, interval: plan.interval) else {
            errorMessage = plan.tier == .enterprise
                ? "Enterprise plans are sold off-app — contact sales."
                : "This plan can't be purchased through the app."
            return false
        }

        guard let package = await purchaseManager.fetchPackage(
            packageID: route.packageID,
            fromOffering: route.offeringID
        ) else {
            errorMessage = "Package not found for \(plan.name)."
            return false
        }

        let success = await purchaseManager.purchase(package)
        if success {
            await loadCurrentSubscription()
        }
        return success
    }

    /// Direct entry to the Aura Pro upgrade flow. Use from the "Upgrade
    /// to Pro" CTA on the Aura paywall or from in-app feature gates that
    /// require AuraPro.
    func upgradeToAuraPro(interval: BillingInterval) async -> Bool {
        let pkgID = interval == .monthly
            ? PurchaseConstants.monthlyPackageID
            : PurchaseConstants.annualPackageID
        return await purchaseUsingOffering(
            offeringID: PurchaseConstants.auraProOfferingID,
            packageID: pkgID,
            failureLabel: "Aura Pro \(interval == .monthly ? "Monthly" : "Annual")"
        )
    }

    /// Direct entry to the Power add-on flow. App-side, this should only
    /// be reachable when the user already has AuraPro active — Power
    /// stacks on Aura Pro per the audit pricing model. Apple's
    /// subscription groups guarantee the stack works (Power lives in a
    /// separate group from Aura/AuraPro).
    func addPower(interval: BillingInterval) async -> Bool {
        let pkgID = interval == .monthly
            ? PurchaseConstants.monthlyPackageID
            : PurchaseConstants.annualPackageID
        return await purchaseUsingOffering(
            offeringID: PurchaseConstants.powerOfferingID,
            packageID: pkgID,
            failureLabel: "Power \(interval == .monthly ? "Monthly" : "Annual")"
        )
    }

    /// Trigger a PAYG token-pack purchase. Tokens are credited
    /// server-side via the RevenueCat webhook
    /// (`/api/v1/webhooks/revenuecat`); this only completes the
    /// StoreKit transaction.
    func purchasePAYGPack() async -> Bool {
        await purchaseManager.purchasePAYGPack()
    }

    /// Shared purchase plumbing — fetches the package, runs the
    /// purchase, refreshes the user's current plan on success.
    private func purchaseUsingOffering(offeringID: String, packageID: String, failureLabel: String) async -> Bool {
        guard let package = await purchaseManager.fetchPackage(
            packageID: packageID,
            fromOffering: offeringID
        ) else {
            errorMessage = "Couldn't find \(failureLabel)."
            return false
        }
        let ok = await purchaseManager.purchase(package)
        if ok { await loadCurrentSubscription() }
        return ok
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
