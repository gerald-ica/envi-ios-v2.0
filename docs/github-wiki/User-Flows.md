# User flows

**Last updated:** 2026-04-03 UTC

## Cold start → first run

1. User launches app → **Splash** (`SplashViewController` / `SplashSpiralView`).
2. `AppCoordinator` checks `UserDefaultsManager.hasCompletedOnboarding`.
3. **If false:** `OnboardingCoordinator` presents multi-step SwiftUI flow (see below).
4. **If true:** `MainTabBarController` with last selected tab behavior (UIKit default tab persistence not documented — verify if added).

## Onboarding flow

**ViewModel:** `OnboardingViewModel` — ordered steps with validation.

Typical sequence (from code structure):

1. **Name** (`OnboardingNameView`) — first + last name.
2. **Date of birth** (`OnboardingDOBView`).
3. **Birth time** (`OnboardingBirthTimeView`).
4. **Where from** (`OnboardingWhereFromView`) — location-style context.
5. **Photos access** (`OnboardingPhotosAccessView`) — prompts Photos permission via `PhotoLibraryManager` / system.
6. **Where born** (`OnboardingWhereBornView`).
7. **Socials** (`OnboardingSocialsView`).

Actions: **Back**, **Skip** (where applicable), **Continue** / **Get Started**. Completion sets `hasCompletedOnboarding` and profile fields in `UserDefaultsManager`, then main app.

## Sign in

**`SignInView`:** email/password style fields (placeholders). Wired to `AppCoordinator` callbacks for sign-in / create account (implementation depth — verify against `AppCoordinator` for production auth).

## Main app — Feed (For You / Explore)

1. **For You:** vertical stack of expandable cards (`ExpandableFeedCardView`); `FeedViewModel` drives content; bookmark, expand, remove, reset.
2. **Explore:** label shows placeholder copy (not a full alternate feed).
3. **Search / notifications:** alert placeholders — “next feed flow” / “not wired yet.”

## Main app — Library

1. Filter chips + template carousel + masonry grid.
2. **FAB:** alert — import/create flows **not wired** (see [Roadmap](Roadmap-and-Coming-Soon)).
3. Items = `ApprovedMediaLibraryStore.approvedItems` **merged with** mock library items.

## Main app — Chat / Explore tab

1. Segmented **EXPLORE** vs **CHAT**.
2. **Explore:** `WorldExplorerView` — 3D helix, filters, scrub, zoom, tap node → `ContentNodeView` (detail, related, open editor).
3. **Chat:** `EnhancedChatHomeView` / threads; suggestions from explorer can **seed** chat prompt (`seedPrompt`). Optional path through `ENVIBrain.shared`; otherwise mock thread lookup.

## Main app — Analytics

Platform chips, KPI cards, engagement chart, content calendar — all driven by **mock** `AnalyticsData` today.

## Main app — Profile

1. Avatar, stats, **SubscriptionStatusView**, connected platforms, settings rows.
2. **Appearance:** `ThemeManager` (light / dark / system) — persisted under `envi_appearance_mode`.
3. **Sign out:** clears `UserDefaultsManager`, `PurchaseManager.logOut`, callback to `AppCoordinator`.

## Editor

Opened from World Explorer detail or other entry points hosting `EditorContainerView` / `EditorViewController`. Timeline + toolbar; tool buttons show **placeholder** alerts until real editor stack is wired.

## Export

`ExportSheetView` / `ProgressOverlayView` / `ExportComposer` — compose export context from `ContentItem` or `ContentPiece`; AI captions UX (verify live vs mock in `ExportComposer`).

## Subscription / Aura

- **`AuraGateModifier`** (`.requiresAura()`): RevenueCat `presentPaywallIfNeeded` for Aura entitlement.
- Paywall and customer center: `ENVIPaywallView`, `ENVICustomerCenterView`.

## Content: Feed → Library

When user **approves** a feed card (if/when that action exists in Feed UI), `ApprovedMediaLibraryStore.approve(ContentItem)` adds it to Library’s approved list.

---

**Note:** Flows above reflect **current codebase behavior** as of 2026-04-03. When wiring real auth, network, and notifications, update this page and `docs/WIKI_CHANGELOG.md`.
