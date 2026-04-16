---
phase: 06-optimization
status: complete
completed: 2026-04-15
---

# Phase 6: Optimization + iOS 26 Vision Upgrades — Summary

**Production readiness: thermal-aware throttling, batched Vision (1.5x+ speedup target), checkpoint-resumable background scans, iOS 26 Vision exclusives integrated, performance regression suite, telemetry instrumentation. Template Tab v1 is ready for PR.**

## Files Created/Modified (5 new + 4 modified + 1 perf test file)

**New files:**
- `ENVI/Core/Media/ThermalAwareScheduler.swift` — adaptive WorkBudget per ProcessInfo.thermalState + LowPowerMode
- `ENVI/Core/Media/BatchedVisionRequests.swift` — single VNImageRequestHandler with sharedCIContext (Metal-backed)
- `ENVI/Core/Media/BackgroundTaskBudget.swift` — UserDefaults-backed checkpoint actor
- `ENVITests/Performance/TemplateTabPerformanceTests.swift` — 4 baselines (classify, embed rebuild, match populate, RSS memory)
- `ENVITests/Media/ThermalAwareSchedulerTests.swift`
- `ENVITests/Media/VisionPerformanceTests.swift` (batched vs serial speedup)

**Modified:**
- `ENVI/Core/Media/MediaClassifier.swift` — `classifyBatch` awaits scheduler.waitForWorkSlot() + uses dynamic chunk size
- `ENVI/Core/Media/VisionAnalysisEngine.swift` — refactored to delegate to BatchedVisionRequests; ~180 LOC of per-request scaffolding deleted
- `ENVI/Core/Media/MediaScanCoordinator+BackgroundTasks.swift` — wires BackgroundTaskBudget; resume-from-checkpoint with legacy fallback; emits scan telemetry
- `ENVI/Core/Telemetry/TelemetryManager.swift` — 10 new event cases (5 media_scan_*, 4 template_*, 1 embedding_index_rebuilt) — no PII

## Thermal Awareness

`ThermalAwareScheduler.shared` (actor) — every background work site calls into this:

| Thermal State | Budget | classifyBatch chunk | backgroundScan chunk |
|---------------|--------|---------------------|----------------------|
| nominal + !LowPower | `.full` | 20 | 100 |
| fair OR LowPower | `.reduced` | 10 | 50 |
| serious | `.minimal` | 5 | 25 |
| critical | `.none` | 0 (paused) | 0 (paused) |

- `waitForWorkSlot()` suspends via `withCheckedContinuation` when budget is `.none`, resumes on thermal recovery notification
- Observers set up in `beginObserving()` (idempotent), torn down in `deinit`
- `ThermalStateProvider` protocol allows injection of mocks in tests
- LPM caps at `.reduced` regardless of thermal

## Batched Vision (1.5x+ speedup target)

Apple's guidance: one `VNImageRequestHandler` running ALL request types is significantly faster than separate handlers because image decode + color convert happen once.

Implementation:
- `BatchedVisionRequests.sharedCIContext` — static let, lazy-init Metal-backed `CIContext` with `cacheIntermediates: false` (bulk-scan workload)
- All independent requests (classify, faceRects, humanRects, saliency, featurePrint, animals, horizon, aesthetics on iOS 18+) run in **one** `handler.perform(allRequests)` call
- Face capture quality runs as second pass (depends on face rectangles from pass 1)
- iOS 26 exclusives (`RecognizeDocumentsRequest`, `DetectCameraLensSmudgeRequest`) added behind `#available(iOS 26.0, *)` guard, resolved via `NSClassFromString` for forward compatibility
- New `VisionAnalysis` fields: `documentDetected: Bool?`, `cameraLensSmudged: Bool?` (additive, JSON backward-compatible)

Benchmark: `testBatchedClassifyVsSerial` — 100 in-memory CGImages, asserts `batched < serial * 0.60` (≥1.67x). On-device expected 1.8-2.5x per Apple guidance.

## Background Task Budget

`BackgroundTaskBudget` actor — manages iOS-assigned BGTask runtime:
- `begin(estimatedRuntime:)` — typically 30 min from iOS
- `shouldCheckpoint()` returns true when remaining < 30s
- `checkpoint(lastProcessedID:)` — saves to UserDefaults `MediaScanCoordinator.lastProcessedID` + `.checkpointAt`
- `resumeFromCheckpoint() -> String?` — fetches resume point on next BGTask invocation
- `clearCheckpoint()` — on natural completion

`MediaScanCoordinator+BackgroundTasks.swift` integration:
- `handleBackgroundTask` calls `await budget.begin()`, sets expirationHandler to checkpoint
- 100-asset chunks broken into 10-asset sub-chunks with `shouldCheckpoint()` poll between each
- When <30s remain: submits fresh `BGProcessingTaskRequest` and yields cleanly
- Resume strategy: prefers new budget key, falls back to legacy `MediaScanCoordinator.lastScannedID` for in-place upgrade safety

## Performance Test Suite

Hard thresholds in `TemplateTabPerformanceTests.swift`:

| Test | Target | Method |
|------|--------|--------|
| `test_classifyBatch_500_completes_under_120s` | < 120s | 25-at-a-time PHAssetCreationRequest seeding |
| `test_embeddingIndexRebuild_500_completes_under_8s` | < 8s | Direct ClassifiedAsset fixtures, 2048-dim feature prints |
| `test_templateMatchEnginePopulateAll_20templates_500assets_under_1s` | < 1s | In-memory cache + index |
| `test_memoryFootprint_classification_peak_under_250MB` | < 250MB RSS delta | `task_info` / `MACH_TASK_BASIC_INFO` |

`XCTSkip` when Photos auth unavailable — same pattern as existing Phase 1 tests.

## Telemetry (No PII)

Events added to `TelemetryManager`:

**Media scanning:**
- `media_scan_started` (asset count, scan type)
- `media_scan_completed` (duration ms, asset count, scan type, failure count)
- `media_scan_thermal_pause` (thermal state)
- `media_scan_thermal_resume`
- `media_scan_thermal_state_changed` (from → to)

**Template tab:**
- `template_tab_opened`
- `template_selected` (templateID, fillRate)
- `template_slot_swapped` (templateID, slotID)
- `template_exported` (templateID, duration to export ms)

**Embedding:**
- `embedding_index_rebuilt` (asset count, duration ms)

**PII guarantees**: never log asset localIdentifiers, never log location/GPS, never log filenames. Only counts, durations, public template IDs, aggregate stats, coarse thermal state strings.

## Decisions Made

- **NSClassFromString for iOS 26 Vision symbols** — defensive against SDK availability quirks
- **Hard-threshold perf tests over `XCTest.measure { }` baseline files** — fail fast in CI rather than baseline drift
- **Legacy + new checkpoint key dual-write** — in-place upgrade path safe
- **TelemetryManager extension over new Reporter protocol** — preserves existing Firebase Analytics integration, no new SPM surface

## Pre-existing Repo Issues NOT Fixed (out of scope)

These remain on `main` and should be addressed in a separate PR before this one merges:
- `ApprovalStatus` duplicate definition (CampaignModels.swift + elsewhere)
- `MetricTrend` duplicate definition (ChatThread.swift + ContentInsight.swift)
- Various Codable conformance fallout from duplicates
- `Color(hex:)` errors in Platform.swift

Phase 1 fixed:
- ✅ GoogleSignIn import guarded with `#if canImport`
- ✅ `SocialPlatform` duplicate (renamed CommunityModels' version → `CommunityPlatform`)

## Parse Verification

All 47+ Swift files (Phase 1-6 + dependencies) parse clean together on iOS 26 simulator target.

## Commits

Phase 6 commit SHA: [see git log]
PR URL: [see GitHub]
Branch: `feature/template-tab-v1`
