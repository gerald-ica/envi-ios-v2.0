# Phase 15 — Routing Layer (Complete, 2026-04-17)

Milestone: v1.2 Frontend Audit Fixes
Plans: 3 of 3 complete
Status: **Complete**

## Goal

Build the missing routing abstraction. Pre-Phase-15,
`NavigationCoordinator.swift` was protocol-only and 14+ `.sheet(isPresented:
$boolState)` call sites were scattered across the 3 live tabs — Phase 16
had no central place to wire the 14 orphan modal groups from. Phase 15
introduces `AppDestination` + `AppRouter` + `DeepLinkRouter` so Phase 16
is pure view-wiring.

## Outcome

- **`AppDestination` enum** — 35 cases covering 14 orphan modal groups +
  7 AIFeatures + 6 Profile sub-sections + 5 existing live destinations +
  2 id-payload cases (campaignDetail, contentEditor). Pure value type;
  `defaultPresentation` computed property; stable identifier for
  `.sheet(item:)` keying.
- **`AppRouter` `@MainActor ObservableObject`** — published `sheet` /
  `fullScreen` / `pushStack` / `selectedTab` with
  `present(_:preferring:)` / `dismiss()` / `replace(_:)` / `selectTab(_:)`
  API. Sheet-over-sheet deadlock handled via dismiss + re-present on next
  main-actor tick. Shared singleton for SceneDelegate/AppDelegate reach,
  `@EnvironmentObject` instance injection for SwiftUI.
- **`MainTabBarController` integration** — router threaded into each tab's
  `UIHostingController` rootView via `.environmentObject`. Two-way sync
  between `router.selectedTab` and `currentIndex` via a Combine sink +
  existing tab-bar tap callback. Programmatic `router.selectTab(n)` now
  switches tabs via the same code path as a manual tap.
- **`AppDestinationResolver`** — `AppDestinationSheetResolver` +
  `AppDestinationFullScreenResolver` structs with 4 concrete arms
  (search, contentCalendar, chatHistory, contentLibrarySettings) and a
  labelled placeholder for Phase 16's pending arms. Every live tab root
  attaches `.sheet(item: $router.sheet)` pointing at the resolver.
- **4 sheet call-sites migrated** — ForYouGalleryContainerView's search
  and calendar sheets, ChatExploreView's chatHistory and
  contentLibrarySettings sheets. Dead `@State` bool vars and private
  sheet hosts deleted; behavior visually identical.
- **`DeepLinkRouter`** — pure-Swift URL parser for
  `enviapp://destination/{caseName}[?id=…]`. Registry-driven so new
  destinations are a one-line change. OAuth callback URLs explicitly
  skipped so Phase 6's handler keeps owning them.
- **`PendingDeepLinkStore`** — replay path for deep links that arrive
  before the main tab bar is on screen (Splash/SignIn boundary). Resets
  on sign-out so stale links don't fire in a new session.
- **AppDelegate URL hook** — `OAuthCallbackHandler.handle` first
  (unchanged), then `DeepLinkRouter` → `PendingDeepLinkStore`, then
  Google Sign-In fallthrough.
- **Telemetry** — `deepLinkRouted` + `deepLinkMalformed` events added to
  TelemetryManager. Strict no-PII policy preserved.

## Tests

Total passing: **23** (was 11 pre-Phase-15 for this Xcode test bundle):

| Suite | Tests |
|---|---|
| AppRouterTests | 6 |
| AppRouterIntegrationTests | 2 |
| DeepLinkRouterTests | 6 |
| ProfileViewModelTests (pre-existing, 14-03) | 5 |
| FeatureFlagsAnalyticsProviderTests (pre-existing, 14-02) | 4 |

All tests pass on iPhone 17 Pro (iOS 26.4) simulator. Full
`xcodebuild build` green with no new warnings.

## Simulator verification

Automated tap-driven verification of the 4 migrated sheets is blocked in
this environment — `simctl` has no tap primitive and `idb` is not
installed. The documented substitution was used: build + install +
launch + no-crash. The deep-link leg was verified via
`xcrun simctl openurl` for both `enviapp://destination/search` (fires
through DeepLinkRouter) and `enviapp://oauth-callback/tiktok?code=test`
(fires through Phase 6 path, unchanged).

## Commits (Phase 15 range)

```
feat(15-01): add AppDestination enum + AppRouter
test(15-01): pin AppRouter presentation + dismissal behavior
docs(15-01): plan summary
feat(15-02): thread AppRouter through MainTabBarController + tab roots
refactor(15-02): migrate 4 live sheets to router.present
test(15-02): router integration + tab selection observation
docs(15-02): plan summary
feat(15-03): add DeepLinkRouter parser for enviapp:// destination URLs
feat(15-03): route non-OAuth deep links through AppRouter in AppDelegate
test(15-03): pin DeepLinkRouter parse behavior
docs(15-03): plan summary
docs(15): phase 15 complete — routing layer live
```

## Handoff to Phase 16

Everything Phase 16 needs is in place:
- `AppDestinationResolver` has ~22 placeholder arms waiting for view
  wiring (the 14 orphan modal groups + 7 AIFeatures + Profile sub-
  sections). Fill them in to replace the placeholder view with the real
  one.
- `AppRouter.shared.selectTab(3)` will work once `MainTabBarController`
  grows a 4th tab (the Publishing tab Phase 16 adds).
- Deep-link grammar is ready: `enviapp://destination/publishing` will
  parse once the Publishing destination is wired to a concrete view.

No routing decisions remain open for Phase 16 — it's all concrete
view-swap work from here.
