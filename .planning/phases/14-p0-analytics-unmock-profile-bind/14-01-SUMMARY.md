# Phase 14 Plan 01: FirebaseFirestore + RemoteConfig SPM Link Summary

**FirebaseFirestore + FirebaseRemoteConfig linked; Phase 13 Firestore-backed repos now compile live and canImport(FirebaseFirestore) evaluates true.**

## Accomplishments
- Added `FirebaseFirestore` and `FirebaseRemoteConfig` as SPM products to both `Package.swift` and `project.yml` (kept `firebase-ios-sdk` pin at `from: "11.0.0"` — resolved version is 11.15.0 per Package.resolved).
- Ran `xcodegen generate` to regenerate `ENVI.xcodeproj/project.pbxproj` from the updated `project.yml`.
- Clean debug build on `iPhone 17 Pro` simulator with `xcodebuild ... build` — exited `** BUILD SUCCEEDED **`.
- Verified `FirebaseFirestoreInternal.framework` is present at `/tmp/envi_dd_14-01/Build/Products/Debug-iphonesimulator/`, confirming Firestore is linked into the binary.
- v1.1 STATE blocker #7 ("Link FirebaseFirestore SPM product to ENVI target") is now resolvable — will be marked RESOLVED in the phase-level roll-up SUMMARY.

## Files Created/Modified
- `Package.swift` — added FirebaseFirestore + FirebaseRemoteConfig products; updated dependency-tree header comment
- `Package.resolved` — auto-updated by `swift package resolve` (gitignored; not part of commit)
- `project.yml` — mirrored the two new products under `targets.ENVI.dependencies`
- `ENVI.xcodeproj/project.pbxproj` — regenerated via `xcodegen`
- `ENVI/Core/Data/Repositories/FirestoreBackedAdvancedAnalyticsRepository.swift` — broke up a type-check-timeout expression in `loadDemographics()` (split `Double(sum + sum + sum)` into intermediate `let` bindings). Needed because once `FirebaseFirestore` is actually linked, the compiler starts type-checking the real generic types and the nested `Int + Int + Int` inside `Double(...)` exceeded the solver budget.

## Decisions Made
- Kept `firebase-ios-sdk` pin at `from: "11.0.0"` — no bump, no Swift-tools-version change.
- Linked `FirebaseRemoteConfig` in this plan (alongside Firestore) so 14-02 can remotely toggle feature flags per the `FeatureFlags.swift:188` hook.
- Did NOT touch the test target — only the `ENVI` application target picks up the new products.
- Included the `FirestoreBackedAdvancedAnalyticsRepository.swift` expression-split fix in the same commit because it is strictly necessary for the build to succeed after linking Firestore; without it, the commit would leave main in a broken state.

## Issues Encountered
- First build attempt failed with `the compiler is unable to type-check this expression in reasonable time` in `FirestoreBackedAdvancedAnalyticsRepository.swift:124`. This is a classic Swift type-check-timeout triggered by the now-visible Firestore types. Split the expression into named intermediate bindings; second build succeeded.

## Next Step
Ready for `14-02-PLAN.md` — flip `connectorsInsightsLive` feature-flag default to `true` (now that Firestore is linked it will actually take effect), and verify `AnalyticsRepositoryProvider.resolve()` returns the Firestore-backed repo when the flag is on.
