# Business logic & rules

**Last updated:** 2026-04-03 UTC

## Onboarding completion rule

- **Gate:** `UserDefaultsManager.hasCompletedOnboarding` (`Bool`).
- **Effect:** If `false`, user stays in onboarding; if `true`, user enters `MainTabBarController`.
- **Reset:** `UserDefaultsManager.resetAll()` removes entire persistent domain for the app’s bundle id (used on sign-out / tests).

## Profile persistence (`UserDefaultsManager`)

Keys (string raw values via `Key` enum):

| Key | Type | Purpose |
|-----|------|---------|
| `hasCompletedOnboarding` | Bool | Main app vs onboarding |
| `userName` | String? | Display name context |
| `userDOB` | String? | Date of birth (stored as string) |
| `userBirthTime` | String? | Birth time |
| `userLocation` | String? | “Where from” |
| `userBirthplace` | String? | Birth place |
| `connectedPlatforms` | [String] | Platform ids/strings; default `[]` |

**Note:** `Key.appearanceMode` exists in the enum but is **not** read/written in `UserDefaultsManager` — appearance uses `ThemeManager` below.

## Appearance (`ThemeManager`)

- **Storage key:** `envi_appearance_mode` — raw string of `AppearanceMode` (`light` / `dark` / `system`).
- **Default if missing:** treated as **dark** in code.
- **Effect:** Updates `UIWindow.overrideUserInterfaceStyle` for windows in the first connected `UIWindowScene`; exposes `colorScheme` for SwiftUI.

## Location (`LocationPermissionManager`)

- **Singleton** `LocationPermissionManager.shared` — CoreLocation authorization for **onboarding** flows.
- **Published:** `authorizationStatus`, `currentLocationName`.
- **Rule mapping:** Wraps `CLAuthorizationStatus` into local enum with `isAuthorized` for when-in-use / always.

## Photos library (`PhotoLibraryManager`)

- **Access level requested:** `.readWrite` on `PHPhotoLibrary`.
- **`isAuthorized`:** `.authorized` **or** `.limited`.
- **`isFullyAuthorized`:** `.authorized` only.
- **Fetch:** `fetchRecentMedia` returns up to N `PHAsset` (images + videos); documented as **stub** toward observers/background refresh.

## Library approval (`ApprovedMediaLibraryStore`)

- **Singleton** in-memory store.
- **`approve(ContentItem)`:** maps to `LibraryItem`, inserts at index 0 if not duplicate by `id`.
- **Rule:** Duplicates ignored by `id`.

## Subscription (Aura)

- **Source of truth:** RevenueCat `CustomerInfo` via `PurchaseManager`.
- **Entitlement id:** `Aura` (`PurchaseConstants.auraEntitlementID`).
- **Gate:** `AuraGateModifier` / `.requiresAura()` presents paywall when entitlement inactive (RevenueCat `presentPaywallIfNeeded`).

## Sign out

- **ProfileViewModel.signOut():** `UserDefaultsManager.shared.resetAll()`, then coordinator + `PurchaseManager` logout as wired in `ProfileView`.

## Data Connect auth levels (backend, not app)

Documented on [Firebase Data Connect](Firebase-Data-Connect): `USER` vs `PUBLIC` per operation — **production review** required for any `PUBLIC` query/mutation.

## Content / AI “rules” (on-device)

`ENVIBrain` orchestrates a **local** loop (observe → hypothesize → measure → learn). Subsystems use **mock** engagement and trend data until real APIs exist — see [ENVI Brain (AI)](ENVI-Brain-AI).

## Helix scene rules (high level)

- Content nodes identified as `content_*` for hit-testing.
- **Future** vs past styling differs (`ContentPiece.isFuture`).
- **Link lines** drawn between IDs in `ContentLink.sampleLinks`.

---

When business rules change (e.g. new UserDefaults keys), update this file **and** `docs/WIKI_CHANGELOG.md` with timestamp.
