import Foundation
import RevenueCat
import Combine
import os

private let purchaseLogger = Logger(subsystem: "com.weareinformal.ENVI", category: "Purchases")

/// Singleton that owns the RevenueCat lifecycle.
/// Publishes reactive state so SwiftUI views can observe subscription status.
@MainActor
final class PurchaseManager: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = PurchaseManager()

    // MARK: - Published State

    /// Latest customer info from RevenueCat
    @Published private(set) var customerInfo: CustomerInfo?

    /// Whether the user currently has the "Aura" entitlement active.
    /// True for any paying tier (Aura, Aura Pro, or Power+Aura Pro).
    @Published private(set) var isAuraActive: Bool = false

    /// Whether the user is on Aura Pro (true also when Power is stacked).
    @Published private(set) var isAuraProActive: Bool = false

    /// Whether the user has the Power add-on active.
    @Published private(set) var isPowerActive: Bool = false

    /// Current offering (for building custom paywalls if needed)
    @Published private(set) var currentOffering: Offering?

    /// Loading state for purchase operations
    @Published private(set) var isPurchasing: Bool = false

    /// Last error encountered during a purchase
    @Published private(set) var purchaseError: String?

    // MARK: - Init

    private override init() {
        super.init()
    }

    // MARK: - Configuration

    /// Call once at app launch — typically from `AppDelegate.didFinishLaunchingWithOptions`.
    ///
    /// If the RevenueCat API key hasn't been populated in
    /// `Config/Secrets.xcconfig` (PurchaseConstants.isConfigured is
    /// false), this is a no-op and a warning is logged. The rest of
    /// the app still runs — subscription gating will treat everyone as
    /// non-Aura in that build.
    func configure() {
        guard PurchaseConstants.isConfigured else {
            purchaseLogger.warning("REVENUECAT_API_KEY is missing or still the template placeholder. Copy Config/Secrets.xcconfig.template to Config/Secrets.xcconfig and fill in the real public `appl_` key from the RevenueCat dashboard. Subscriptions are disabled for this build.")
            return
        }

        // Reject secret keys — RevenueCat public app keys must start with "appl_"
        guard PurchaseConstants.apiKey.hasPrefix("appl_") else {
            purchaseLogger.error("⚠️ REVENUECAT_API_KEY appears to be a secret key (does not start with 'appl_'). Only public app-specific keys should be used in the client. Subscriptions are disabled for this build.")
            return
        }

        // `.debug` leaks App User IDs, transactions, and full HTTP traffic
        // to the system log — visible in Console.app and sysdiagnose. Keep
        // verbose logging local; ship Release builds with `.warn`.
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif
        Purchases.configure(withAPIKey: PurchaseConstants.apiKey)
        Purchases.shared.delegate = self

        // Seed initial customer info
        Task { await refreshCustomerInfo() }
    }

    // MARK: - Customer Info

    /// Pull the latest customer info from RevenueCat.
    func refreshCustomerInfo() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            applyCustomerInfo(info)
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Offerings

    /// Fetch available offerings (products, packages).
    func fetchOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            currentOffering = offerings.current
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    /// Fetch a specific offering by lookup key. Returns nil if RevenueCat
    /// has no offering with that identifier (e.g. dashboard misconfig) or
    /// if the network call fails.
    ///
    /// Use to drive secondary paywalls — e.g.
    /// `fetchOffering(id: PurchaseConstants.auraProOfferingID)` for the
    /// Pro upgrade modal,  `..powerOfferingID` for the Power add-on modal.
    func fetchOffering(id: String) async -> Offering? {
        do {
            let offerings = try await Purchases.shared.offerings()
            return offerings.offering(identifier: id)
        } catch {
            purchaseError = error.localizedDescription
            purchaseLogger.warning("Failed to fetch offering \(id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Fetch an offering and resolve a specific package within it.
    ///
    /// Convenience for paywall code that already knows the package
    /// lookup key (e.g. `$rc_monthly`, `$rc_annual`). Returns nil when
    /// the offering or package isn't found.
    func fetchPackage(packageID: String, fromOffering offeringID: String) async -> Package? {
        guard let offering = await fetchOffering(id: offeringID) else { return nil }
        return offering.availablePackages.first { $0.identifier == packageID }
    }

    // MARK: - Purchases

    /// Purchase a specific package.
    func purchase(_ package: Package) async -> Bool {
        isPurchasing = true
        purchaseError = nil

        do {
            let result = try await Purchases.shared.purchase(package: package)

            if result.userCancelled {
                isPurchasing = false
                return false
            }

            applyCustomerInfo(result.customerInfo)
            isPurchasing = false
            return true
        } catch {
            purchaseError = error.localizedDescription
            isPurchasing = false
            return false
        }
    }

    /// Purchase a one-time consumable product by store identifier.
    ///
    /// Used for PAYG token packs (`payg_pack_200`). Consumables aren't part
    /// of any RevenueCat offering — the StoreProduct is fetched directly.
    /// Token-balance crediting happens server-side via the RC webhook
    /// (see `revenuecat_webhook.py`); this method only confirms the
    /// StoreKit transaction completed so the UI can show "purchase
    /// successful, units will appear shortly."
    func purchaseConsumable(productID: String) async -> Bool {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        let products = await Purchases.shared.products([productID])
        guard let product = products.first else {
            purchaseError = "Product \(productID) not available"
            purchaseLogger.error("Consumable \(productID, privacy: .public) not found in StoreKit")
            return false
        }

        do {
            let result = try await Purchases.shared.purchase(product: product)
            if result.userCancelled { return false }
            applyCustomerInfo(result.customerInfo)
            return true
        } catch {
            purchaseError = error.localizedDescription
            return false
        }
    }

    /// Convenience for the PAYG pack — the only consumable in the catalog
    /// at present.
    func purchasePAYGPack() async -> Bool {
        await purchaseConsumable(productID: PurchaseConstants.paygPack200ID)
    }

    /// Restore previous purchases (App Store receipt refresh).
    func restorePurchases() async -> Bool {
        isPurchasing = true
        purchaseError = nil

        do {
            let info = try await Purchases.shared.restorePurchases()
            applyCustomerInfo(info)
            isPurchasing = false
            return isAuraActive
        } catch {
            purchaseError = error.localizedDescription
            isPurchasing = false
            return false
        }
    }

    // MARK: - Entitlement Helpers

    /// Check if a specific entitlement is currently active.
    func hasEntitlement(_ identifier: String) -> Bool {
        customerInfo?.entitlements[identifier]?.isActive == true
    }

    /// Convenience — checks the "Aura" entitlement.
    var hasAura: Bool { isAuraActive }

    /// Convenience — checks the "AuraPro" entitlement.
    var hasAuraPro: Bool { isAuraProActive }

    /// Convenience — checks the "Power" entitlement.
    var hasPower: Bool { isPowerActive }

    /// Highest active tier — useful for paywall routing.
    enum Tier { case none, aura, auraPro, power }
    var currentTier: Tier {
        if isPowerActive { return .power }
        if isAuraProActive { return .auraPro }
        if isAuraActive { return .aura }
        return .none
    }

    // MARK: - User Identity

    /// Log in a known user (e.g. after your own auth).
    func logIn(appUserID: String) async {
        do {
            let (info, _) = try await Purchases.shared.logIn(appUserID)
            applyCustomerInfo(info)
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    /// Log out — reverts to anonymous user.
    func logOut() async {
        do {
            let info = try await Purchases.shared.logOut()
            applyCustomerInfo(info)
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Private

    private func applyCustomerInfo(_ info: CustomerInfo) {
        customerInfo = info
        isAuraActive    = info.entitlements[PurchaseConstants.auraEntitlementID]?.isActive    == true
        isAuraProActive = info.entitlements[PurchaseConstants.auraProEntitlementID]?.isActive == true
        isPowerActive   = info.entitlements[PurchaseConstants.powerEntitlementID]?.isActive   == true
    }
}

// MARK: - PurchasesDelegate

extension PurchaseManager: PurchasesDelegate {

    /// Called whenever customer info updates (purchase, renewal, expiry, etc.)
    nonisolated func purchases(_ purchases: Purchases,
                               receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            applyCustomerInfo(customerInfo)
        }
    }
}
