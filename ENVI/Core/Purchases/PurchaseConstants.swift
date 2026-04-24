import Foundation

/// Central constants for RevenueCat configuration.
///
/// The API key is NOT hardcoded in source. It's sourced at runtime from
/// `Info.plist`, which is populated at build time by Xcode substituting
/// `$(REVENUECAT_API_KEY)` from `Config/Secrets.xcconfig` (gitignored —
/// see `Config/Secrets.xcconfig.template` for the expected format).
enum PurchaseConstants {

    // MARK: - API Keys

    /// RevenueCat iOS SDK key, read from the build-time-substituted
    /// `REVENUECAT_API_KEY` entry in Info.plist.
    ///
    /// Falls back to an empty string if the key is missing or still set
    /// to the template placeholder. In that case, `PurchaseManager`
    /// logs a warning and skips RevenueCat configuration — the rest of
    /// the app still runs, subscriptions just don't resolve.
    static var apiKey: String {
        let raw = Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String ?? ""
        // Treat the template placeholder as "not configured" so a
        // forgotten rotation doesn't silently call RevenueCat with a
        // nonsense key.
        if raw.isEmpty || raw.hasPrefix("appl_REPLACE_WITH_") { return "" }
        return raw
    }

    /// True when `apiKey` is a usable value (non-empty and not the
    /// template placeholder). `PurchaseManager` consults this before
    /// calling `Purchases.configure`.
    static var isConfigured: Bool { !apiKey.isEmpty }

    // MARK: - Entitlements

    /// The primary entitlement that unlocks premium features.
    static let auraEntitlementID = "Aura"

    // MARK: - Product Identifiers

    /// Monthly auto-renewing subscription
    static let monthlyProductID   = "monthly"
    /// Yearly auto-renewing subscription
    static let yearlyProductID    = "yearly"
    /// One-time lifetime purchase (non-consumable)
    static let lifetimeProductID  = "lifetime"
    /// Consumable in-app purchase (e.g. token packs)
    static let consumableProductID = "consumable"

    /// All subscription product IDs for convenience
    static let allProductIDs: Set<String> = [
        monthlyProductID,
        yearlyProductID,
        lifetimeProductID,
        consumableProductID,
    ]
}
