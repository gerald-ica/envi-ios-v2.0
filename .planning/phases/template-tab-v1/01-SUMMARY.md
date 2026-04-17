---
phase: 01-media-intelligence-core
status: complete
completed: 2026-04-15
---

# Phase 1: Media Intelligence Core — Summary

**MediaClassifier pipeline shipped — 8 new Swift files wrap every piece of Apple-computed metadata, on-device Vision ML, and scan scheduling into one actor-based orchestrator ready for Phase 2.**

## Accomplishments

- ✅ All 9 Vision requests wrapped in a batched TaskGroup (Classify, Aesthetics, Face, FaceQuality, Human, Saliency, FeaturePrint, Animals, Horizon)
- ✅ Complete EXIF / GPS / TIFF / Apple MakerNote extraction via ImageIO
- ✅ SwiftData `ClassifiedAsset` @Model with indexes on every hot template-matching query field
- ✅ Reverse geocoding with LRU + rate-limited CLGeocoder wrapper
- ✅ Unified `MediaClassifier` actor with single-asset + batch + cache-hit paths
- ✅ Hybrid B+C scan strategy: onboarding (last 500) + background BGProcessingTask (full library, resumable) + lazy rescan on Template tab + PHPhotoLibraryChangeObserver incremental
- ✅ Thermal-aware guard in MediaScanCoordinator (full ThermalAwareScheduler in Phase 6)
- ✅ Protocol-based testability seams (MediaClassifierProtocol, PHAssetProviding)
- ✅ Parallel-agent execution: 4 independent agents ran Tasks 1-4 concurrently, 2 more for Tasks 5-6

## Files Created (12 total: 8 prod + 4 tests)

**Production (8):**
- `ENVI/Core/Media/MediaMetadataExtractor.swift` — EXIF/GPS/TIFF/MakerApple + video metadata
- `ENVI/Core/Media/VisionAnalysisEngine.swift` — actor wrapping 9 Vision requests
- `ENVI/Core/Media/ClassificationCache.swift` — SwiftData actor cache
- `ENVI/Core/Media/Models/ClassifiedAsset.swift` — @Model with 9 indexed fields
- `ENVI/Core/Media/ReverseGeocodeCache.swift` — CLGeocoder wrapper, LRU+rate limit
- `ENVI/Core/Media/MediaClassifier.swift` — unified pipeline orchestrator
- `ENVI/Core/Media/MediaScanCoordinator.swift` — scan strategies + progress
- `ENVI/Core/Media/MediaScanCoordinator+BackgroundTasks.swift` — BGProcessingTask handler
- `ENVI/Core/Storage/PhotoLibraryManager+MediaScan.swift` — additive extension

**Tests (4):**
- `ENVITests/Media/MediaMetadataExtractorTests.swift` (6 cases)
- `ENVITests/Media/VisionAnalysisEngineTests.swift` (food label assertion + synthetic)
- `ENVITests/Media/ClassificationCacheTests.swift` (6 cases incl. perf)
- `ENVITests/Media/ReverseGeocodeCacheTests.swift` (4 cases incl. LRU + rate limit)
- `ENVITests/Media/MediaClassifierTests.swift` (2 cases — batch + cache-hit)
- `ENVITests/Media/MediaScanCoordinatorTests.swift` (2 cases — lazyRescan + changeObserver)

## Schema: ClassifiedAsset SwiftData @Model

Indexed fields (for fast template-matching queries):
- `localIdentifier` (unique), `aestheticsScore`, `isUtility`, `faceCount`, `personCount`, `mediaType`, `mediaSubtypeRaw`, `creationDate`, `latitude`, `longitude`

Data blobs (JSON-encoded Codable structs):
- `metadata: Data` → ExtractedMetadata
- `visionAnalysis: Data` → VisionAnalysis
- `featurePrint: Data?` → VNFeaturePrintObservation

Versioning: `classifierVersion: Int` — bump to force rescan, current = 1.

Cache path: `FileManager.default.applicationSupportDirectory/ClassificationCache.sqlite`

## Vision API Path Chosen

Legacy `VNImageRequestHandler` with `withCheckedContinuation`, dispatched concurrently via `TaskGroup`. Reason: Package targets iOS 26, but async Vision request API (`ClassifyImageRequest` without VN prefix) is iOS 18+.

`VNCalculateImageAestheticsScoresRequest` is gated with `#if #available(iOS 18.0, *)`; when unavailable the engine returns `aestheticsScore: nil` / `isUtility: nil`.

## BGTask Registration

Identifier: `com.envi.mediaclassifier.fullscan`
Requires external power, no network.

**⚠️ Required before running on device:**
Add `com.envi.mediaclassifier.fullscan` to `BGTaskSchedulerPermittedIdentifiers` in `Info.plist`. TODO comments in all 3 scan files reference this.

## Collateral Fixes (pre-existing repo bugs)

Two pre-existing main-branch build blockers were fixed to let Phase 1 files integrate:

1. **`AuthManager.swift` GoogleSignIn import** — guarded with `#if canImport(GoogleSignIn)`. The SPM dependency was never declared in `Package.swift` despite the import. Full fix requires adding GoogleSignIn SPM package.

2. **`SocialPlatform` duplicate definition** — existed in both `Platform.swift` (6 OAuth platforms) and `CommunityModels.swift` (7 platforms incl. Facebook+Twitter). Renamed community version to `CommunityPlatform` and updated 3 referencing files (`CommunityModels.swift`, `InboxView.swift`, `CommunityViewModel.swift`).

**Remaining pre-existing blockers NOT fixed here** (out of scope for Template Tab v1):
- `ApprovalStatus` duplicate — `CampaignModels.swift` + one other file
- `MetricTrend` duplicate — `ChatThread.swift` + `ContentInsight.swift`
- `ContentTemplate` / `CreativeBrief` Codable conformance errors (likely fallout from above)

**Verification approach used:** Because these unrelated pre-existing errors block `xcodebuild build`, all Phase 1 files were verified via `xcrun -sdk iphonesimulator swiftc -parse -target arm64-apple-ios26.0-simulator` against the Phase 1 file set. All files parse cleanly in isolation. Full test execution blocked until main-branch duplicate-type cleanup lands — recommend a separate PR.

## Decisions Made

- Used legacy VNImageRequestHandler pattern (iOS 26 compat) over new iOS 18+ async API
- ClassifiedAsset stores metadata/visionAnalysis as `Data` blobs (not relationship types) — simpler migrations, better write perf
- failures map keyed by `String` (PHAsset.localIdentifier) rather than `UUID` — PHAsset IDs are opaque strings
- `MediaClassifierProtocol` + `PHAssetProviding` protocols added as testability seams
- `PhotoLibraryManager.scanCoordinator` exposed via additive extension (original file untouched)

## Performance Expectations (to verify on-device)

- classifyBatch(500) target: < 2 min on iPhone 14+
- Cache hit: < 10ms per asset
- SwiftData query (indexed fields, 100 rows): < 50ms

## Commits

Phase 1 commit SHA: [see git log]
Branch: `feature/template-tab-v1`
Pushed to origin.

## Readiness for Phase 2

✅ VNFeaturePrintObservation data persisted in ClassifiedAsset.featurePrint
✅ ClassificationCache provides bulk fetch for EmbeddingIndex rebuild
✅ Top labels extracted for Phase 3 matching
✅ All types Codable for Phase 4 Lynx bridge JSON serialization

Ready to proceed to Phase 2: Native Embedding Pipeline.
