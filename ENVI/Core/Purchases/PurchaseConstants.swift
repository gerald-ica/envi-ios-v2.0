import Foundation

/// Central constants for RevenueCat configuration.
///
/// The API key is NOT hardcoded in source. It's sourced at runtime from
/// `Info.plist`, which is populated at build time by Xcode substituting
/// `$(REVENUECAT_API_KEY)` from `Config/Secrets.xcconfig` (gitignored —
/// see `Config/Secrets.xcconfig.template` for the expected format).
///
/// PRICING MODEL (per Submission Audit, Apr 2026):
/// - Aura       — $20/mo or $192/yr  (effective $16/mo annual)
/// - Aura Pro   — $100/mo or $960/yr (effective $80/mo annual)
/// - Power      — +$200/mo or +$1,920/yr add-on, stacks on Aura Pro
/// - PAYG       — $10 per 200-unit consumable pack
/// - 7-day free trial as introductory offer on `auraMonthly`
///
/// Subscription-group layout in App Store Connect:
/// - Group "Aura" (mutually exclusive): auraMonthly, auraYearly,
///   auraProMonthly, auraProYearly
/// - Group "Power" (separate so it stacks on Aura Pro): powerMonthly,
///   powerYearly
/// - Consumable `paygPack200` lives outside any group.
enum PurchaseConstants {

    // MARK: - API Keys

    /// RevenueCat iOS SDK key, read from the build-time-substituted
    /// `REVENUECAT_API_KEY` entry in Info.plist.
    static var apiKey: String {
        let raw = Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String ?? ""
        if raw.isEmpty || raw.hasPrefix("appl_REPLACE_WITH_") { return "" }
        return raw
    }

    /// True when `apiKey` is a usable value.
    static var isConfigured: Bool { !apiKey.isEmpty }

    // MARK: - Entitlements

    /// Granted by ANY active subscription tier (Aura, Aura Pro, or
    /// Power+Aura Pro). Use as the primary "is this a paying user?"
    /// gate.
    static let auraEntitlementID = "Aura"

    /// Granted by Aura Pro subscriptions only (and inherited via the
    /// stacked Power add-on, since Power requires an active Aura Pro
    /// subscription).
    static let auraProEntitlementID = "AuraPro"

    /// Granted by Power add-on subscriptions only.
    static let powerEntitlementID = "Power"

    // MARK: - Product Identifiers (App Store Connect)

    /// Aura tier — solo creator plan.
    static let auraMonthlyID = "aura_monthly"
    static let auraYearlyID  = "aura_yearly"

    /// Aura Pro tier — studio plan.
    static let auraProMonthlyID = "aura_pro_monthly"
    static let auraProYearlyID  = "aura_pro_yearly"

    /// Power add-on — stacks on Aura Pro.
    static let powerMonthlyID = "power_monthly"
    static let powerYearlyID  = "power_yearly"

    /// Pay-as-you-go consumable. 1 pack = 200 units. Tokens are credited
    /// server-side via the RevenueCat webhook (NON_RENEWING_PURCHASE).
    static let paygPack200ID = "payg_pack_200"

    /// All product IDs the SDK needs to know about.
    static let allProductIDs: Set<String> = [
        auraMonthlyID, auraYearlyID,
        auraProMonthlyID, auraProYearlyID,
        powerMonthlyID, powerYearlyID,
        paygPack200ID,
    ]

    // MARK: - Offering Identifiers

    /// Default paywall — Aura tier.
    static let defaultOfferingID = "default"

    /// Pro upgrade paywall — Aura Pro tier.
    static let auraProOfferingID = "aura_pro"

    /// Power add-on paywall — only shown to existing Aura Pro users.
    static let powerOfferingID = "power"

    // MARK: - Package Lookup Keys
    //
    // Each offering exposes two packages with these well-known
    // RevenueCat-reserved identifiers. The SDK resolves them to the
    // actual store products configured in the dashboard.
    static let monthlyPackageID = "$rc_monthly"
    static let annualPackageID  = "$rc_annual"
}
