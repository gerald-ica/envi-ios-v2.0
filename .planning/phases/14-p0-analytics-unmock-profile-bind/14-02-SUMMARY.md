# Phase 14 Plan 02: Analytics Flag Flip + Provider Pin Summary

**Analytics insights live by default; provider behavior pinned by 7 XCTests; rollback path documented.**

## Accomplishments
- Flipped `FeatureFlags.shared.connectorsInsightsLive` default from `false` to `true`. Updated the doc comment to describe both branches and reference the Remote Config rollback path.
- Added `ENVITests/FeatureFlagsAnalyticsProviderTests.swift` with 7 XCTests:
  - `testConnectorsInsightsLiveDefaultIsTrue`
  - `testAnalyticsRepositoryProviderReturnsFirestoreBackedWhenLive`
  - `testAnalyticsRepositoryProviderFallsBackWhenDisabled`
  - `testAdvancedAnalyticsRepositoryProviderReturnsFirestoreBackedWhenLive`
  - `testAdvancedAnalyticsRepositoryProviderFallsBackWhenDisabled`
  - `testBenchmarkRepositoryProviderReturnsFirestoreBackedWhenLive`
  - `testBenchmarkRepositoryProviderFallsBackWhenDisabled`
- Verified all 7 tests pass via `xcodebuild test -only-testing:ENVITests/FeatureFlagsAnalyticsProviderTests`.
- Verified full Debug build still succeeds for `iPhone 17 Pro`.
- Confirmed the three provider resolvers all use the standard `flag ? FirestoreBacked* : shared.repository` pattern. No non-standard provider patterns surfaced during review.

## Files Created/Modified
- `ENVI/Core/Config/FeatureFlags.swift` — default + doc comment
- `ENVITests/FeatureFlagsAnalyticsProviderTests.swift` — new test file (7 tests)
- `project.yml` — added `ENVITests` as a `bundle.unit-test` target (see Decisions Made)
- `ENVI.xcodeproj/project.pbxproj` — regenerated via xcodegen

## Decisions Made
- **Kept `useMock*` toggles elsewhere untouched** per the v1.0 decision (still needed for previews/tests).
- **Did NOT refactor `BenchmarkRepositoryProvider`** — the 14-02 plan asked to log any non-standard provider patterns as Phase 19-02 follow-ups. Audit result: none. All three providers follow the same `if FeatureFlags.shared.connectorsInsightsLive { return FirestoreBacked… } return shared.repository` shape. No follow-up needed on that axis.
- **Added an `ENVITests` bundle.unit-test target to `project.yml`** because the 14-02 plan's verify step runs `xcodebuild test -only-testing:ENVITests/...`, which requires a test bundle in the Xcode project. Before this plan, `ENVITests/*.swift` files were only compiled via SPM's `swift test` (which is blocked on iOS-only API surface, see `swift test` errors regarding macOS minimum). Creating the Xcode test target closes that gap.
- **Scoped the Xcode test bundle to ONLY `FeatureFlagsAnalyticsProviderTests.swift`**. The pre-existing `ENVITests/*` files had bit-rotted against the current API surface — `Media/MediaScanCoordinatorTests.swift`, `Media/ReverseGeocodeCacheTests.swift`, `Media/ClassificationCacheTests.swift`, `Media/ThermalAwareSchedulerTests.swift`, `OAuth/SocialOAuthManagerTests.swift` all fail to compile. Fixing those is out of 14-02 scope; explicitly including only this plan's new file keeps the pin tests runnable without rabbit-holing. **Phase 19 follow-up logged:** test-target consolidation — migrate the rest of `ENVITests/` into the Xcode bundle as they get un-rotted.

## Issues Encountered
- First build attempt of the Xcode test target failed because the pre-existing SPM-only tests don't compile under the Xcode test runner. Resolved by scoping the `sources` in `project.yml` to only the new file (see Decisions Made).
- No issues with the three provider `resolve()` functions themselves — all standardized.

## Rollback Path
Set Remote Config key `connectorsInsightsLive` to `false` and call `FeatureFlags.shared.refreshFromRemoteConfig()` on next app launch. Mocked analytics (`MockAnalyticsRepository` / `APIAnalyticsRepository` per `AppEnvironment.current`) will resume serving the v1.0 canned data. No code change required.

## Phase 19 Follow-ups Logged
- **Test-target consolidation**: migrate remaining `ENVITests/*.swift` files into the Xcode `ENVITests` bundle as they are un-rotted. Currently `ENVITests/FeatureFlagsAnalyticsProviderTests.swift` is the only file in the Xcode test bundle; the rest still build via SPM only (which is itself blocked on iOS-only API surface).

## Next Step
Ready for `14-03-PLAN.md` — bind real user to ProfileViewModel; remove `User.mock`.
