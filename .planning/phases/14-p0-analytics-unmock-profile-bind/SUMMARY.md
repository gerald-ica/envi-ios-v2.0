# Phase 14: p0-analytics-unmock-profile-bind — Roll-up Summary

**Status:** Complete — 2026-04-17
**Plans shipped:** 3/3
**Milestone:** v1.2 Frontend Audit Fixes (1 of 6 phases done)

## Phase Goal
Ship the two P0 items from the 2026-04-17 Frontend Audit:
1. Phase 13 analytics actually serves live data (the flag was shipped `false` and the SPM product was never linked).
2. The Profile tab stops showing `User.mock` to every signed-in user.

## Plan-by-Plan Summary

### Plan 14-01 — Link FirebaseFirestore + FirebaseRemoteConfig (build)
See `.planning/phases/14-p0-analytics-unmock-profile-bind/14-01-SUMMARY.md`.

- Added `FirebaseFirestore` and `FirebaseRemoteConfig` SPM products to `Package.swift` and `project.yml`. Kept `firebase-ios-sdk` pin at `from: "11.0.0"` (resolved version 11.15.0).
- Regenerated `ENVI.xcodeproj` via `xcodegen generate`.
- Full Debug build on `iPhone 17 Pro` simulator: `** BUILD SUCCEEDED **`.
- Incidental fix: split a type-check-timeout expression in `FirestoreBackedAdvancedAnalyticsRepository.loadDemographics` that surfaced once the real Firestore types became visible.
- **Resolved v1.1 STATE blocker #7** (FirebaseFirestore SPM link).

### Plan 14-02 — Flip `connectorsInsightsLive` + pin provider behavior (feat + test)
See `.planning/phases/14-p0-analytics-unmock-profile-bind/14-02-SUMMARY.md`.

- Flipped `FeatureFlags.shared.connectorsInsightsLive` default from `false` to `true`; updated doc comment with rollback instructions.
- Audited all 3 providers — `AnalyticsRepositoryProvider`, `AdvancedAnalyticsRepositoryProvider`, `BenchmarkRepositoryProvider` — all use the standard `flag ? FirestoreBacked* : shared.repository` pattern. No non-standard patterns logged for Phase 19-02.
- Added `ENVITests/FeatureFlagsAnalyticsProviderTests.swift` with 7 XCTests pinning flag-on / flag-off behavior for each provider. All pass.
- Created the Xcode `ENVITests` bundle.unit-test target (previously tests only built via SPM `swift test`, which is blocked on iOS-only API surface). Scoped source list to only the Phase 14 pin tests — pre-existing `ENVITests/*` had bit-rotted; **Phase 19 follow-up logged** for test-target consolidation.

### Plan 14-03 — Bind ProfileViewModel to real auth user (feat + test)
See `.planning/phases/14-p0-analytics-unmock-profile-bind/14-03-SUMMARY.md`.

- Changed `ProfileViewModel.user` from `User = .mock` to `User?` (optional, nil-init). Added `isLoadingProfile` and `profileLoadError` observable state. New `@MainActor loadProfile()` hydrates from `AuthManager.shared.currentUser()`.
- `ProfileView` now renders three states: profile UI when user is set, ProgressView while loading, error banner with Retry when no signed-in user. Never falls back to `User.mock` silently.
- New file `ENVI/Core/Auth/AuthManager+CurrentUser.swift` — thin bridge mapping `FirebaseAuth.User` → domain `User`. Deliberately partial (no Firestore round-trip); bridge approach chosen because `AuthManager.shared` had no existing domain-model getter.
- `User.mock` retained via `#if DEBUG ProfileViewModel.preview()` helper for SwiftUI previews.
- 2 new XCTests in `ENVITests/ProfileViewModelTests.swift` — both pass.

## Cumulative Verification
- **Build:** `xcodebuild -scheme ENVI -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` → `** BUILD SUCCEEDED **`
- **Tests:** `xcodebuild test -only-testing:ENVITests` → 9/9 passing (7 FeatureFlagsAnalyticsProviderTests + 2 ProfileViewModelTests)

## Commits (oldest → newest)
```
7eea273 build(14-01): link FirebaseFirestore + FirebaseRemoteConfig to ENVI target
f214e1f docs(14-01): plan summary
90a2cd2 feat(14-02): default connectorsInsightsLive to true
2d7ad59 test(14-02): pin analytics provider behavior per flag state
7f08546 docs(14-02): plan summary
260b6d0 feat(14-03): bind ProfileViewModel to real auth user
9fcd181 test(14-03): pin ProfileViewModel default state is empty
1ea8980 docs(14-03): plan summary
```
(Roll-up commit follows.)

## v1.2 Audit Findings Closed by Phase 14
- **P0 — Phase 13 analytics silently disabled** (dual cause: flag false + SPM unlinked). Both root causes addressed.
- **P0 — Mock-locked views: ProfileViewModel unconditionally uses `User.mock`.** Addressed.

## v1.1 Blockers Closed by Phase 14
- **Blocker #7 — Link FirebaseFirestore SPM product.** RESOLVED 2026-04-17.

Other v1.1 blockers (secret rotation, redirect URIs, App Review approvals, etc.) remain ops-side.

## Phase 19 Follow-ups Logged
1. **Test-target consolidation** (from 14-02): migrate the rest of `ENVITests/*.swift` into the Xcode `ENVITests` bundle as they are un-rotted. Currently only the Phase 14 pin tests build via Xcode; the rest still depend on SPM which is blocked on iOS-only API surface.

## Rollback Paths
- **Analytics live path off:** set Remote Config key `connectorsInsightsLive` to `false`, call `FeatureFlags.shared.refreshFromRemoteConfig()` on next app launch. Mocks resume; no code change.
- **Firestore link rollback:** revert commit `7eea273` and regenerate via `xcodegen`. The `#if canImport(FirebaseFirestore)` guards fall open naturally, and with the flag off nothing would hit Firestore anyway.
- **Profile bind rollback:** revert commits `260b6d0` + `9fcd181`. ProfileViewModel would return to showing `User.mock`. NOT recommended — the audit explicitly flagged this as P0.

## Next
Ready to plan Phase 15 (p1-routing-layer). Plans for 15-01, 15-02, 15-03 already exist in `.planning/phases/15-p1-routing-layer/` per commit `565860e`.
