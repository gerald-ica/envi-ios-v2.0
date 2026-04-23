import Foundation
import RevenueCat
import Combine

/// Singleton that owns the RevenueCat lifecycle.
/// Publishes reactive state so SwiftUI views can observe subscription status.
@MainActor
final class PurchaseManager: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = PurchaseManager()

    // MARK: - Published State

    /// Latest customer info from RevenueCat
    @Published private(set) var customerInfo: CustomerInfo?

    /// Whether the user currently has the "Aura" entitlement active
    @Published private(set) var isAuraActive: Bool = false

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
            print("⚠️ [PurchaseManager] REVENUECAT_API_KEY is missing or still the template placeholder. " +
                  "Copy Config/Secrets.xcconfig.template to Config/Secrets.xcconfig and fill in the real " +
                  "public `appl_` key from the RevenueCat dashboard. Subscriptions are disabled for this build.")
            return
        }
        Purchases.logLevel = .debug
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
        isAuraActive = info.entitlements[PurchaseConstants.auraEntitlementID]?.isActive == true
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
