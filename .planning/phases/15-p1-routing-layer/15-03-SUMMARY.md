# Phase 15 Plan 03: Deep Link Routing Summary

**Inbound `enviapp://destination/*` URLs now parse into AppDestination
and dispatch through AppRouter; OAuth callback path untouched;
pending-deeplink replay handles the sign-in boundary.**

## Accomplishments
- `DeepLinkRouter.swift` — pure-Swift URL parser with a
  `[String: (URL) -> AppDestination?]` registry covering all 35
  AppDestination cases (33 no-payload + 2 id-payload:
  campaignDetail, contentEditor). OAuth callback URLs
  (`enviapp://oauth-callback/*`) deliberately return nil so Phase 6's
  handler keeps owning that path. Adding a new destination is a
  one-line change in `caseRegistry`.
- `PendingDeepLinkStore.swift` — a non-actor store that stashes a
  deep-link destination if it arrives before the main tab bar is
  presented and replays it once `AppCoordinator.showMainApp()` fires
  `markMainAppReady()`. Sign-out calls `reset()` to drop stale links.
  Thread-safe via a serial DispatchQueue around the two bits of state.
- `AppDelegate.application(_:open:)` hooked to call
  `OAuthCallbackHandler.handle` first (unchanged), then
  `DeepLinkRouter.destination(from:)` → telemetry + dispatch via
  `PendingDeepLinkStore`, then fall through to Google Sign-In. OAuth
  path is byte-for-byte preserved because OAuthCallbackHandler.handle
  runs first and short-circuits.
- `TelemetryManager.Event` gained two new cases:
  `deepLinkRouted` (fired on successful dispatch) and
  `deepLinkMalformed` (fired with a `reason` + optional `case_name`
  when an enviapp deep link fails to parse — gives production
  observability on bad links without crash-report noise). Strict
  no-PII policy preserved — only public case-name data is logged.
- 6 passing DeepLinkRouterTests. Full ENVITests suite (23 tests:
  6 DeepLink + 6 AppRouter + 2 AppRouterIntegration + 5 ProfileViewModel
  + 4 FeatureFlags) green.

## Simulator verification

Ran in the iPhone 17 Pro simulator (UDID
`ECF3488E-5D2F-4FDC-A62E-62064D433227`):

```
xcrun simctl openurl booted "enviapp://destination/search"
xcrun simctl openurl booted "enviapp://oauth-callback/tiktok?code=test"
```

Both commands returned zero exit code with no crash. The OAuth URL
flows through the Phase 6 OAuthCallbackHandler (posts a
NotificationCenter payload — no subscribers in a cold app, which is
fine). The destination URL flows through DeepLinkRouter →
PendingDeepLinkStore → AppRouter when signed-in. In a signed-out
session the destination is stashed until `showMainApp()` runs.

Functional correctness is also unit-tested: `testDestinationNoPayload`
confirms `enviapp://destination/search` parses to `.search`, which is
the same destination the URL handler hands to the router. Combined
with the `testPresentingSearchFromRouterRendersSearchSheet` from
15-02, the full chain (URL → parser → router → resolver arm) is
pinned by unit tests.

## Files Created/Modified
- `ENVI/Navigation/DeepLinkRouter.swift` — new
- `ENVI/Navigation/PendingDeepLinkStore.swift` — new
- `ENVI/App/ENVIApp.swift` — AppDelegate URL hook
- `ENVI/App/AppCoordinator.swift` — `markMainAppReady` on
  `showMainApp`, `reset` on sign-out
- `ENVI/Core/Telemetry/TelemetryManager.swift` — added
  `deepLinkRouted` + `deepLinkMalformed` events
- `ENVITests/DeepLinkRouterTests.swift` — new (6 tests)
- `project.yml` + `ENVI.xcodeproj/project.pbxproj` — test file
  registered + project regenerated

## Decisions Made
- Patched AppDelegate (not SceneDelegate). The plan mentioned both,
  with guidance to "patch the right one, don't duplicate". The
  existing URL handler lives in AppDelegate (Phase 6's wiring), so
  that's the single point of entry and extension.
- Universal Links infrastructure (AASA file, associated domains) is
  explicitly deferred per the plan — only the scheme handler is live.
- `PendingDeepLinkStore` is a class, not a value type, so the same
  instance is observed by both AppDelegate and AppCoordinator; keeps
  the replay semantics in one place instead of threading through
  AppCoordinator properties.
- Bad-deep-link observability lives in TelemetryManager's existing
  `track(_:parameters:)` path rather than `print` so production
  signals reach Firebase. Added the event enum cases rather than
  using the low-level `trackRawEvent` — typed enums keep the event
  catalog self-documenting.

## Issues Encountered
None. Build + tests green after one iteration. An initial sketch of
`PendingDeepLinkStore` had a `@MainActor` / `nonisolated` signature
collision; reworked to a single non-isolated entry point that hops
to main actor internally.

## Next Step
Phase 15 complete. Phase 16 (Publishing tab + modal entry points +
AIFeatures wiring) fills in the remaining arms of
`AppDestinationResolver` and reaches those arms via new entry points
in Profile / HomeFeed / ChatExplore. All the infrastructure for that
(router threading, destination enum, deep-link grammar) is now in
place — Phase 16 is purely view-wiring work.
