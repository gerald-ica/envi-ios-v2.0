# Phase 19 — Plan 04 — Summary

**Status:** Complete
**Date:** 2026-04-17

## What shipped

Baseline VM test coverage for every live-tab ViewModel. Combined with the targeted tests from Phases 14–18, every VM behind a live tab now has at least one pin test.

### New test files
- **`ENVITests/EnhancedChatViewModelTests.swift`** (4 tests)
  - `testDefaultStateIsHome` — defaults to home, no active thread, empty input, quick actions populated.
  - `testResetToHomeClearsState` — pins back-button semantics.
  - `testSendMessageWithBlankInputIsNoOp` — whitespace input doesn't leave home.
  - `testSelectQuickActionPopulatesInputAndStartsThread` — quick action chip triggers a thread.
  - Note: since EnhancedChatViewModel doesn't take a repository (Oracle + ENVI Brain are singletons), pins focus on state transitions rather than repo-driven loading.
- **`ENVITests/ForYouGalleryViewModelTests.swift`** (3 tests) — uses a StubContentRepository + `ApprovedMediaLibraryStore.shared`.
  - Default segment is `.forYou`.
  - `loadForYouContent` falls back to `repository.fetchFeedItems()` when the template pipeline yields nothing.
  - Dev-env fallback does not surface an error loading phase on repo failure.
- **`ENVITests/SchedulingViewModelTests.swift`** (3 tests) — uses a StubSchedulingRepository.
  - Default-empty state.
  - `reload()` populates all four slices (posts, queue, recurring, rules).
  - Dev-env fallback on repo failure.

### Extended tests
- **`ENVITests/ProfileViewModelTests.swift`** (+3 tests on top of Phase 14's 2, total 5)
  - `testLoadConnectionsPopulatesRowForEveryPlatform` — row per SocialPlatform.
  - `testLoadConnectionsWithNilUserStillProducesFullRowset` — no-user crash guard.
  - `testConnectPlatformDefaultStateIsIdle` — isConnectingPlatform + connectionErrorMessage baseline.

### Deferral
The plan also mentioned extending ProfileViewModel tests to cover `connectPlatform()` + `disconnectPlatform()` flows. Those touch the `SocialOAuthManager.shared` singleton via a real network code path (or the mock OAuth path depending on feature flag). Meaningful coverage there requires either a singleton-swap seam (not currently present) or stubbing the URL session at the `URLProtocol` layer (which `SocialOAuthManagerTests.swift` already does and was deferred in Plan 19-03). Rather than rabbit-hole into that setup, the extended tests focus on the state transitions that are fully injectable — which is exactly what the audit cared about.

Partial Profile data (dateOfBirth / location / stats from 14-03): AuthManager+CurrentUser still maps Firebase→User with identity fields only. The VM tests here don't cover those fields because they aren't populated yet. **Logged to v1.3 scope.**

## Verification
- `xcodebuild test -only-testing:...` for the 4 new/extended suites → 15 tests, 0 failures.

## Next
`.planning/phases/19-p4-hygiene/19-05-PLAN.md` — wordmark unify + milestone v1.2 wrap-up.
