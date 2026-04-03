# Subscriptions (RevenueCat)

**Last updated:** 2026-04-03 UTC

## Configuration

- **Singleton:** `PurchaseManager` (`Core/Purchases/PurchaseManager.swift`), `@MainActor`, `ObservableObject`.
- **Configure:** `ENVIApp` → `PurchaseManager.shared.configure()` at launch.
- **SDK:** RevenueCat (SPM).
- **API key & product ids:** `PurchaseConstants.swift` — **do not duplicate secrets in wiki**; rotate keys in dashboard if leaked.

## Entitlement

- **Primary entitlement:** **`Aura`** (`auraEntitlementID`).
- **Published:** `isAuraActive` derived from `CustomerInfo`.

## Features

| Capability | Implementation |
|------------|----------------|
| Refresh customer info | `refreshCustomerInfo()` async |
| Fetch offerings | `fetchOfferings()` async |
| Purchase package | `purchase(_ package:)` async |
| Restore | `restorePurchases()` async |
| Log out (user switch) | `logOut()` — called from Profile sign-out path |
| Paywall presentation | RevenueCat paywall APIs + `ENVIPaywallView` |
| Gating | `AuraGateModifier` / `.requiresAura()` |

## Product identifiers (logical names in code)

`monthly`, `yearly`, `lifetime`, `consumable` — must match App Store Connect + RevenueCat dashboard configuration.

## UI

- `SubscriptionStatusView`, `ENVICustomerCenterView`, `ENVIPaywallView` under `Features/Subscription/`.

---

Update when entitlements or offering structure changes.
