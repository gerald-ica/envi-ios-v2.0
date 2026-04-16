---
phase: 01-media-intelligence-core
milestone: template-tab-v1
type: execute
domain: ios-swift-vision
depends-on: none
---

<objective>
Build MediaClassifier.swift — the single scan pipeline that extracts every piece of metadata Apple already computes on camera roll assets, runs on-device Vision ML, and caches results to SwiftData for fast template matching.

Purpose: Phases 2-6 all depend on classified metadata. This phase creates the foundation data layer.
Output: MediaClassifier + ClassificationCache + MediaScanCoordinator + 5 supporting files. Every PHAsset in the library can be classified in <200ms and the results persist.
</objective>

<execution_context>
~/.claude/get-shit-done/workflows/execute-phase.md
.planning/phases/template-tab-v1/MILESTONE.md
</execution_context>

<context>
@.planning/phases/template-tab-v1/MILESTONE.md
@ENVI/Core/Storage/PhotoLibraryManager.swift
@ENVI/Core/AI/ContentAnalyzer.swift
@ENVI/Core/AI/ENVIBrain.swift
@ENVI/Models/ContentPiece.swift
@Package.swift

**Apple frameworks used:** Photos, PhotosUI, Vision, CoreLocation, ImageIO, AVFoundation, SwiftData, BackgroundTasks
**No new SPM dependencies** — all Apple-native.

**Parallelization:** Files 1-4 can be implemented in parallel by independent agents. Files 5-6 depend on 1-4 and run after.
</context>

<tasks>

<task type="auto">
  <name>Task 1: MediaMetadataExtractor.swift — EXIF/GPS/device metadata</name>
  <files>ENVI/Core/Media/MediaMetadataExtractor.swift</files>
  <action>
  Create struct that extracts ALL Apple-computed metadata from a PHAsset without running ML:
  - PHAsset surface: mediaType, mediaSubtypes bitmask (photoHDR, photoPanorama, photoScreenshot, photoLive, photoDepthEffect, photoRAW, videoStreamed, videoHighFrameRate, videoTimelapse, videoCinematic, spatialMedia), pixelWidth/Height, creationDate, modificationDate, location (CLLocation), duration, isFavorite, burstIdentifier, burstSelectionTypes, hasAdjustments, playbackStyle
  - EXIF via `PHContentEditingInput.fullSizeImageURL` → `CGImageSourceCreateWithURL` → `CGImageSourceCopyPropertiesAtIndex`: ExposureTime, FNumber, ISOSpeedRatings, FocalLength, Flash, WhiteBalance, LensMake, LensModel, SceneCaptureType, BodySerialNumber, DateTimeOriginal with subseconds
  - GPS dictionary: Latitude/LatitudeRef, Longitude/LongitudeRef, Altitude/AltitudeRef, Speed, ImgDirection, HPositioningError
  - TIFF dictionary: Make ("Apple"), Model (e.g., "iPhone 16 Pro"), Software, Orientation
  - Apple MakerNote dictionary (kCGImagePropertyMakerAppleDictionary) — capture as `[String: Any]` blob for later analysis
  - For videos: AVURLAsset → tracks → formatDescriptions for codec/bitrate, naturalSize, nominalFrameRate
  - Return typed struct `ExtractedMetadata` — all Codable, no force-unwraps, every field optional except asset localIdentifier
  
  AVOID: blocking the main thread (use async), loading full image data (use CGImageSource properties-only read), force-unwrapping EXIF fields (devices/OSes differ).
  </action>
  <verify>Unit test (ENVITests/MediaMetadataExtractorTests.swift): feed 5 fixture PHAssets representing photo/video/screenshot/panorama/livePhoto, assert each expected field populates correctly</verify>
  <done>`swift build` succeeds, tests pass, struct is Codable, zero force-unwraps</done>
</task>

<task type="auto">
  <name>Task 2: VisionAnalysisEngine.swift — on-device ML orchestration</name>
  <files>ENVI/Core/Media/VisionAnalysisEngine.swift</files>
  <action>
  Actor wrapping the Vision framework that runs a parallel batch of requests on a single image/frame:
  - ClassifyImageRequest — keep labels with confidence > 0.3, cap top 10
  - CalculateImageAestheticsScoresRequest — capture `overallScore` (-1..1) and `isUtility` Bool (for filtering screenshots/receipts)
  - DetectFaceRectanglesRequest → count + bounding boxes
  - DetectFaceCaptureQualityRequest → quality score per face (0..1)
  - DetectHumanRectanglesRequest → person count
  - GenerateAttentionBasedSaliencyImageRequest → salient region bounds
  - GenerateImageFeaturePrintRequest → VNFeaturePrintObservation (store as Data for Phase 2)
  - RecognizeAnimalsRequest → animal labels (feeds "pet content" template matching)
  - DetectHorizonRequest → horizon angle (is photo level?)
  
  For videos: sample 3 keyframes (start/middle/end) and aggregate (max aesthetics score, union of classifications, max face count).
  
  Use the new async/await Vision API (iOS 18+ `RequestHandler` pattern — check via context7 if unsure of exact symbol names). Fallback to VNImageRequestHandler only if async path unavailable.
  
  AVOID: running requests sequentially (batch them in a TaskGroup — Apple's guidance for iOS 26), keeping CIImages in memory after request completes, running on the main actor.
  </action>
  <verify>`swift build`; unit test classifies a sample food photo and asserts "food" label present with confidence > 0.3 and aesthetics score != 0</verify>
  <done>All 9 request types wrapped, async API, returns single `VisionAnalysis` struct with every field, Codable</done>
</task>

<task type="auto">
  <name>Task 3: ClassificationCache.swift — SwiftData persistence layer</name>
  <files>ENVI/Core/Media/ClassificationCache.swift, ENVI/Core/Media/Models/ClassifiedAsset.swift</files>
  <action>
  Create SwiftData `@Model` class `ClassifiedAsset` storing:
  - `localIdentifier: String` (PHAsset UUID, @Attribute(.unique))
  - `classifiedAt: Date`, `classifierVersion: Int` (bump to force rescan)
  - `metadata: Data` (Codable ExtractedMetadata blob)
  - `visionAnalysis: Data` (Codable VisionAnalysis blob)
  - `featurePrint: Data?` (VNFeaturePrintObservation data, separate for fast similarity queries)
  - `aestheticsScore: Double`, `isUtility: Bool`, `faceCount: Int`, `personCount: Int`, `topLabels: [String]`, `mediaType: Int`, `mediaSubtypeRaw: UInt` (indexed for fast template matching queries)
  - `creationDate: Date?`, `latitude: Double?`, `longitude: Double?` (indexed)
  
  Cache actor provides:
  - `upsert(_:)`, `batchUpsert(_:)` (with transaction)
  - `fetch(localIdentifier:)`, `fetchAll() -> [ClassifiedAsset]`
  - `query(matching: TemplateSlotRequirements) -> [ClassifiedAsset]` (returns Swift predicate-filtered results)
  - `invalidate(olderThan: Int)` (classifierVersion bumps)
  - `delete(localIdentifier:)`
  
  Use SwiftData's `ModelContainer` injected via `@MainActor` app entry. Store container on disk at `FileManager.default.applicationSupportDirectory/ClassificationCache.sqlite`.
  
  AVOID: storing raw CGImage data in SwiftData (use the Data blobs only), querying from main actor (use the actor), unindexed queries on large libraries.
  </action>
  <verify>`swift build`; unit test creates 100 ClassifiedAssets, queries by `isUtility == false AND aestheticsScore > 0.3`, returns in <50ms</verify>
  <done>Model compiles, indexes on hot query fields, cache actor has full CRUD, migration-safe classifierVersion bumping works</done>
</task>

<task type="auto">
  <name>Task 4: ReverseGeocodeCache.swift — CLLocation → place name</name>
  <files>ENVI/Core/Media/ReverseGeocodeCache.swift</files>
  <action>
  Actor wrapping CLGeocoder with local cache (in-memory LRU + UserDefaults JSON spillover):
  - `func place(for: CLLocation) async throws -> PlaceInfo` returning { name, locality, administrativeArea, country, areasOfInterest }
  - Cache key: round lat/lng to 4 decimals (~11m accuracy)
  - Respect Apple rate limits: max 1 req/sec, batch window via TaskGroup throttle
  - Fail gracefully on network errors (return nil, don't throw up)
  
  AVOID: hammering CLGeocoder (Apple rate-limits aggressively — user gets throttled app-wide), storing unbounded cache in UserDefaults.
  </action>
  <verify>`swift build`; test with 10 nearby Las Vegas coordinates yields 1 geocoder call + 9 cache hits</verify>
  <done>LRU cache (max 500 entries), rate-limited, fails gracefully, test passes</done>
</task>

<task type="auto">
  <name>Task 5: MediaClassifier.swift — the unified pipeline</name>
  <files>ENVI/Core/Media/MediaClassifier.swift</files>
  <action>
  The public entry point. Actor that orchestrates Tasks 1-4 into one call:
  
  ```swift
  actor MediaClassifier {
    func classify(_ asset: PHAsset, priority: TaskPriority) async throws -> ClassifiedAsset
    func classifyBatch(_ assets: [PHAsset], progress: ((Int, Int) -> Void)?) async -> [ClassifiedAsset]
    func rescanIfStale(_ asset: PHAsset) async throws -> ClassifiedAsset
  }
  ```
  
  Flow per asset:
  1. Check `ClassificationCache.fetch(localIdentifier:)` — return if fresh (classifierVersion matches)
  2. Run `MediaMetadataExtractor.extract(asset)` (cheap, always)
  3. Request image data via PHImageManager → VisionAnalysisEngine.analyze()
  4. If location, enqueue `ReverseGeocodeCache.place(for:)` (best-effort, don't block)
  5. Compose into ClassifiedAsset, `cache.upsert(_:)`, return
  
  Batch: use TaskGroup with max concurrency = `ProcessInfo.processInfo.activeProcessorCount`. Report progress every 10 items.
  
  Error handling: per-asset failures logged + skipped, never crash the batch. Surface errors via a `failures: [UUID: Error]` side-channel.
  
  AVOID: serialized processing (batch in parallel), using URLSession-like retries (Vision failures are deterministic — retry is waste), holding PHImageManager request IDs beyond scope.
  </action>
  <verify>Integration test: classify 50 sample PHAssets, all succeed, cache populated, second call returns cached results in <10ms total</verify>
  <done>Public API clean, progress callback works, batch parallelism hits all cores, second scan is cache-hit</done>
</task>

<task type="auto">
  <name>Task 6: MediaScanCoordinator.swift — scan strategy orchestrator</name>
  <files>ENVI/Core/Media/MediaScanCoordinator.swift, ENVI/Core/Media/MediaScanCoordinator+BackgroundTasks.swift</files>
  <action>
  Implements the user's scan strategy decision (B+C hybrid):
  - `scanOnboardingBatch()` — fetches last 500 PHAssets, classifies with progress callback for onboarding UI (Phase 5 consumes this)
  - `scheduleBackgroundScan()` — registers `BGProcessingTaskRequest` identifier `com.envi.mediaclassifier.fullscan`, runs on device idle/charging, processes remaining library in chunks of 100 with budget checks
  - `lazyRescan(trigger:)` — called when Template tab opens; checks for any new PHAssets since last scan (via PHPhotoLibraryChangeObserver diff) and classifies just the delta
  - `registerChangeObserver()` — extends existing `PhotoLibraryManager.changeDelegate` pattern, triggers incremental classification on library changes
  
  Extend existing `PhotoLibraryManager` via extension (do NOT fork the file) to add `scanCoordinator: MediaScanCoordinator` property.
  
  Background task: respect `task.expirationHandler`, checkpoint progress to UserDefaults, resume from last-scanned localIdentifier.
  
  AVOID: scanning from the main actor, ignoring thermal state (check `ProcessInfo.thermalState` — skip background scan if `.serious` or `.critical`), running during onboarding animation (defer until onboarding UI settles).
  </action>
  <verify>Manual: simulate `BGProcessingTaskRequest` via Xcode debugger, confirm scans chunk correctly and persist checkpoints. Unit test: changeObserver delta detection returns only new assets</verify>
  <done>All three scan modes work, BGProcessingTask registered in Info.plist BGTaskSchedulerPermittedIdentifiers, thermal-aware, resumable</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <what-built>Phase 1 complete — MediaClassifier pipeline with 6 new files wraps every piece of Apple-computed metadata + on-device Vision ML into a single cacheable call, with three scan strategies ready for Phase 5's UI.</what-built>
  <how-to-verify>
    1. Run: `xcodebuild -project ENVI.xcodeproj -scheme ENVI -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build`
    2. Run: `xcodebuild test -scheme ENVI -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`
    3. Check: All tests in ENVITests/MediaClassifier* pass
    4. Review: Six new files exist at ENVI/Core/Media/ and compile without warnings
    5. Confirm: No new SPM dependencies were added (all Apple-native)
  </how-to-verify>
  <resume-signal>Type "approved" to commit + push + proceed to Phase 2, or describe issues to fix</resume-signal>
</task>

</tasks>

<verification>
Before declaring phase complete:
- [ ] `swift build` succeeds on iOS 26+ simulator
- [ ] All unit tests pass (ENVITests/MediaClassifier*, ENVITests/VisionAnalysisEngine*, ENVITests/ClassificationCache*)
- [ ] No new SPM dependencies (all Apple frameworks)
- [ ] BGProcessingTask identifier added to Info.plist
- [ ] Phase 1 commit pushed to origin/feature/template-tab-v1
</verification>

<success_criteria>
- 6 new Swift files at ENVI/Core/Media/
- Classifying a PHAsset returns every documented Apple metadata field + Vision analysis + feature print
- Second classify call is a cache hit (< 10ms)
- Batch of 500 completes on a modern iPhone in < 2 minutes
- Background task registered and callable
- Phase committed and pushed
</success_criteria>

<output>
After completion, create `.planning/phases/template-tab-v1/01-SUMMARY.md` with:
- Files created (6)
- Vision request list implemented
- Cache schema (field names + indexes)
- BGTask identifier registered
- Commit SHA of Phase 1
- Any deviations from plan
- Readiness for Phase 2
</output>
