import Foundation

/// Central constants for RevenueCat configuration.
/// Update these values when moving from sandbox to production.
enum PurchaseConstants {

    // MARK: - API Keys

    /// RevenueCat public Apple API key (sandbox / test)
    static let apiKey = "sk_hoeiPqynPTZFQYNrJloynICTIJEsD"

    /// RevenueCat Stripe SDK key (for web/cross-platform billing)
    static let stripeSDKKey = "strp_PYrioztBJShaIxHdwLUvkAHByBb"

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
