# Phase 19 — Plan 03 — Summary

**Status:** Complete
**Date:** 2026-04-17

## What shipped

### 1. LibraryDAMViewModel (NOT deleted)
The plan assumed `LibraryDAMViewModel` was orphan and scheduled deletion, but a repo-wide grep revealed 4 views binding to it: `AssetDetailView`, `FolderBrowserView`, `SmartCollectionView`, `StorageQuotaView`. It is complementary to `LibraryViewModel` (different surface — DAM features vs library items/templates/plan), not a duplicate.

**Outcome:** file retained. Added a header comment clarifying the split and noting that a future consolidation is v1.3+ scope.

### 2. EnhancedChatViewModel mock gating
The 120+-line `mockThreads` dictionary was previously only runtime-gated (`guard AppEnvironment.current == .dev`). Now wrapped in `#if DEBUG` / `#endif` so the mock string literals don't compile into release binaries. The property signature is preserved, so the sole consumer (`resolveThread` inside a `.dev` branch) compiles on both configurations.

Verified per the stop-condition: `mockThreads` is only read inside a `.dev`-gated code path. No surprise production consumption.

### 3. Pre-existing test un-rot
Test count progression:
- **Phase 14 baseline:** ~9 in-target passing.
- **Phase 18 baseline:** 67 in-target passing.
- **Phase 19 Plan 03:** 208 executed, 12 skipped, 9 failures, **~187 passing** (up from 67).

Files re-enabled in `project.yml` and compiled into the Xcode ENVITests bundle:
- Embedding/ (4): DensityClusterer, DimensionReducer, EmbeddingIndex, SimilarityEngine.
- Templates/ (4): TemplateCatalogClient, TemplateMatchEngine, TemplateRanker, VideoTemplateModels.
- Connectors/ (4): LinkedIn, TikTok, TikTokIntegration, XTwitter.
- OAuth/ (2): OAuthBroker, OAuthRefreshRotation.
- Media/ (3): ClassificationCache, MediaClassifier, MediaMetadataExtractor.
- Root (6): ENVITests, AppCheckConfiguration, AppConfigConnector, ASWebAuthenticationSessionAdapter, ContentLibrarySettingsConnect, OAuthCallbackHandler.

**Total re-enabled:** 23 test files.

### 4. Deferred (FIXME-marked in project.yml)
Per the plan's time-box guidance (10-min per file max, skip anything bigger):

| File | Reason | Effort |
|---|---|---|
| `OAuth/SocialOAuthManagerTests.swift` | `StubOAuthSession` init is `@MainActor`-isolated under Swift 6 strict concurrency. Requires rewriting ~10 call sites. | >10 min |
| `Media/MediaScanCoordinatorTests.swift` | Subclass missing `override` keyword on a protocol method that changed signature. | >10 min |
| `Media/ThermalAwareSchedulerTests.swift` | `XCTAssertEqual(await foo, …)` not allowed — autoclosure doesn't support concurrency. ~8 assertions to rewrite. | >10 min |
| `Media/ReverseGeocodeCacheTests.swift` | `MockGeocoder` doesn't conform to current `ReverseGeocoding` protocol. | >10 min |
| `Media/VisionAnalysisEngineTests.swift` | Environmental: simulator lacks `espresso context` (CoreML/ANE not on iOS simulator). Device-lane only. | Env, not code |
| `Media/VisionPerformanceTests.swift` | Same environmental issue. | Env, not code |
| `Performance/TemplateTabPerformanceTests.swift` | `populateAll(20 × 500)` asserts < 1 s budget; simulator overhead makes it consistently 1.2 s. | Env, not code |

Each is logged to v1.3 test un-rot sweep.

## Verification
- `xcodebuild ... build-for-testing` → `TEST BUILD SUCCEEDED`.
- `xcodebuild test` → 208 tests executed, 9 failures (all in deferred files; now removed from sources).
- Net pass count jumped from 67 → ~187, well above the plan's "50% of pre-existing" floor.

## Next
`.planning/phases/19-p4-hygiene/19-04-PLAN.md` — baseline VM tests for the 4 live-tab VMs.
