---
phase: 03-template-engine
milestone: template-tab-v1
type: execute
domain: ios-swift
depends-on: 02-embedding-pipeline
---

<objective>
Build the TemplateEngine that defines what a camera-roll-driven VideoTemplate looks like, how each slot declares its media requirements, and the matching algorithm that picks the best PHAssets for each slot.

Purpose: This is the brain of the Template tab. Given a library of ClassifiedAssets + a VideoTemplate definition, the engine returns the template populated with the user's best-matching content — ranked, scored, and ready to preview.
Output: VideoTemplate/TemplateSlot/MediaRequirements models + TemplateMatchEngine + SlotFillRanker + 4 supporting files.
</objective>

<execution_context>
~/.claude/get-shit-done/workflows/execute-phase.md
.planning/phases/template-tab-v1/MILESTONE.md
.planning/phases/template-tab-v1/01-SUMMARY.md
.planning/phases/template-tab-v1/02-SUMMARY.md
</execution_context>

<context>
@.planning/phases/template-tab-v1/MILESTONE.md
@.planning/phases/template-tab-v1/01-SUMMARY.md
@.planning/phases/template-tab-v1/02-SUMMARY.md
@ENVI/Core/Media/ClassificationCache.swift
@ENVI/Core/Embedding/EmbeddingIndex.swift
@ENVI/Models/BrandKitModels.swift
@ENVI/Features/Library/LibraryViewModel.swift

**Coexistence:** ENVI already has `ContentTemplate` (caption/metadata templates) in BrandKitModels.swift. This phase adds `VideoTemplate` (media-slot templates). Different types, no conflict.
</context>

<tasks>

<task type="auto">
  <name>Task 1: VideoTemplateModels.swift — the data model</name>
  <files>ENVI/Models/VideoTemplateModels.swift</files>
  <action>
  All Codable structs for camera-roll templates:
  
  ```swift
  struct VideoTemplate: Identifiable, Codable {
    let id: UUID
    let remoteID: String?       // server-assigned (Phase 4)
    let name: String
    let category: VideoTemplateCategory  // grwm, cooking, ootd, travel, fitness, product, etc.
    let aspectRatio: AspectRatio  // .portrait9x16, .square, .landscape16x9, .portrait4x5
    let duration: TimeInterval?  // nil for photo templates
    let slots: [TemplateSlot]
    let textOverlays: [TextOverlay]
    let transitions: [TransitionType]
    let audioTrack: AudioTrackRef?
    let suggestedPlatforms: [SocialPlatform]
    let thumbnailURL: URL?       // server-provided fallback thumbnail
    let popularity: Int          // server-side trending signal
  }
  
  struct TemplateSlot: Identifiable, Codable {
    let id: UUID
    let order: Int
    let duration: TimeInterval
    let requirements: MediaRequirements
    let textOverlay: String?     // caption overlaid on this slot
  }
  
  struct MediaRequirements: Codable {
    let acceptedMediaTypes: [MediaTypeFilter]  // photo, video, livePhoto
    let preferredLabels: [String]              // Vision labels e.g., ["food", "indoor"]
    let excludedLabels: [String]               // e.g., ["text", "document"]
    let preferredOrientation: Orientation?     // portrait, landscape, square
    let minimumAestheticsScore: Double         // default -0.3, tunable per slot
    let requireNonUtility: Bool                // default true
    let preferredFaceCount: FaceCountFilter?   // .none, .exactly(1), .group, .any
    let preferredPersonCount: PersonCountFilter?
    let durationRange: Range<TimeInterval>?    // for video slots
    let requireSubtypes: [PHAssetMediaSubtypeFilter]  // e.g., requireDepthEffect, requireCinematic
    let excludeSubtypes: [PHAssetMediaSubtypeFilter]  // e.g., excludeScreenshot
    let recencyPreference: RecencyPreference   // .any, .recent30Days, .recent7Days
  }
  
  struct FilledSlot: Identifiable {
    let slot: TemplateSlot
    let matchedAsset: ClassifiedAsset?
    let matchScore: Double        // 0..1, how well this asset fits
    let alternates: [ClassifiedAsset]  // top 5 runner-ups for user to swap
  }
  
  struct PopulatedTemplate: Identifiable {
    let template: VideoTemplate
    let filledSlots: [FilledSlot]
    let fillRate: Double          // 0..1 fraction of slots with match
    let overallScore: Double      // average of matchScores across filled slots
    let previewThumbnail: UIImage?  // composited from first 1-3 filled slots
  }
  ```
  
  Include enum definitions with associated values and Codable conformance. Include `VideoTemplate.mockLibrary` with 5 example templates for testing.
  
  AVOID: making everything var (use let + init where immutable), overloading Codable with custom implementations (default synthesized Codable works), defining complex enums without CaseIterable.
  </action>
  <verify>`swift build` succeeds; mockLibrary JSON round-trip via JSONEncoder/JSONDecoder produces identical struct</verify>
  <done>All types Codable, mockLibrary has 5 diverse templates, no force-unwraps</done>
</task>

<task type="auto">
  <name>Task 2: TemplateMatchEngine.swift — slot-to-asset matching</name>
  <files>ENVI/Core/Templates/TemplateMatchEngine.swift</files>
  <action>
  Actor that implements the matching algorithm:
  
  ```swift
  actor TemplateMatchEngine {
    func populate(
      template: VideoTemplate,
      from cache: ClassificationCache,
      using index: EmbeddingIndex
    ) async -> PopulatedTemplate
    
    func populateAll(
      templates: [VideoTemplate],
      from cache: ClassificationCache,
      using index: EmbeddingIndex
    ) async -> [PopulatedTemplate]
    
    func swap(
      slot: TemplateSlot,
      in populated: PopulatedTemplate,
      to asset: ClassifiedAsset
    ) -> PopulatedTemplate
  }
  ```
  
  Matching algorithm per slot:
  1. Query ClassificationCache for all candidates matching hard filters (mediaType, subtypes, orientation, isUtility=false if required, aestheticsScore >= threshold, duration in range)
  2. Score each candidate:
     - +0.4 for label match (intersection of candidate.topLabels and slot.preferredLabels)
     - +0.2 for aesthetics (normalized 0-1 from -1..1)
     - +0.15 for face/person count match
     - +0.1 for recency match
     - +0.1 for recency (within 30 days)
     - +0.05 for favorite or burst-hero flag
  3. For multi-slot templates: prefer **visually cohesive** sets — bonus if chosen assets cluster together in EmbeddingIndex.clusters()
  4. Assign best match, top 5 alternates
  5. If no candidate meets threshold: slot stays empty (fillRate reflects this)
  
  Global constraint: no single asset can fill two slots (track used asset IDs during population).
  
  AVOID: scoring ALL assets for every slot (pre-filter via ClassificationCache query first), recomputing embeddings (use EmbeddingIndex cache), ignoring global constraint (leads to same photo in every slot).
  </action>
  <verify>Unit test: feed 50 mock ClassifiedAssets + 3 mock VideoTemplates → each slot gets appropriate match, no duplicates across slots</verify>
  <done>Matching returns sorted results, respects all filters, handles empty-match gracefully</done>
</task>

<task type="auto">
  <name>Task 3: TemplateRanker.swift — "For You" ranking + repository</name>
  <files>ENVI/Core/Templates/TemplateRanker.swift, ENVI/Core/Data/Repositories/VideoTemplateRepository.swift</files>
  <action>
  Two components:
  
  **TemplateRanker** — orders populated templates for the "For You" section:
  ```swift
  struct TemplateRanker {
    func rank(_ populated: [PopulatedTemplate]) -> [PopulatedTemplate]
  }
  ```
  Scoring: `fillRate * 0.5 + overallScore * 0.3 + (popularity/maxPopularity) * 0.2`. Secondary sort: recency of matched assets (templates matching user's recent content rank higher).
  
  **VideoTemplateRepository** — integrates with ENVI's existing Repository pattern (see ContentRepository.swift, BrandKitRepository.swift as reference). Returns mock data for Phase 3; Phase 4 swaps in Lynx/server source.
  ```swift
  protocol VideoTemplateRepository {
    func fetchCatalog() async throws -> [VideoTemplate]
    func fetchTrending() async throws -> [VideoTemplate]
    func fetchByCategory(_ category: VideoTemplateCategory) async throws -> [VideoTemplate]
  }
  
  final class MockVideoTemplateRepository: VideoTemplateRepository { /* uses VideoTemplate.mockLibrary */ }
  ```
  
  AVOID: ranking becoming un-transparent (log the score breakdown for debugging), coupling ranker to specific repository (depend on the protocol).
  </action>
  <verify>Unit test: 10 PopulatedTemplates with varying fill rates → ranker puts 100%-fill templates above 50%-fill</verify>
  <done>Ranker deterministic, repository protocol matches ENVI conventions, mock returns VideoTemplate.mockLibrary</done>
</task>

<task type="auto">
  <name>Task 4: TemplateTabViewModel.swift — SwiftUI-ready VM</name>
  <files>ENVI/Features/Templates/TemplateTabViewModel.swift</files>
  <action>
  `@MainActor @Observable` class (or ObservableObject fallback on lower platforms) that Phase 5's UI consumes:
  
  ```swift
  @MainActor
  @Observable
  final class TemplateTabViewModel {
    private(set) var populatedTemplates: [PopulatedTemplate] = []
    private(set) var trending: [PopulatedTemplate] = []
    private(set) var byCategory: [VideoTemplateCategory: [PopulatedTemplate]] = [:]
    private(set) var isLoading: Bool = false
    private(set) var scanProgress: (done: Int, total: Int)?  // bound to MediaScanCoordinator
    private(set) var error: Error?
    
    func refresh() async   // loads catalog + populates + ranks
    func swap(slot: TemplateSlot, in populated: PopulatedTemplate, to asset: ClassifiedAsset)
    func select(_ populated: PopulatedTemplate)  // emits to coordinator for preview
    
    private let repo: VideoTemplateRepository
    private let matcher: TemplateMatchEngine
    private let ranker: TemplateRanker
    private let cache: ClassificationCache
    private let index: EmbeddingIndex
    private let scanner: MediaScanCoordinator
  }
  ```
  
  Lifecycle: on `refresh()`, trigger `scanner.lazyRescan()` to catch library deltas, then populate + rank. Expose `scanProgress` so UI can show "Analyzing your 1,234 photos…" during first load.
  
  AVOID: doing work in init (lazy init via first refresh()), forgetting @MainActor (triggers SwiftUI race conditions), using ObjectWillChange manually (let @Observable handle it).
  </action>
  <verify>Unit test with mock repo+matcher+scanner: refresh() populates templates, isLoading transitions correctly</verify>
  <done>VM compiles clean, published props work with SwiftUI binding, no background-thread UI updates</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <what-built>Phase 3 complete — template engine matches classified assets to template slots, ranks by fit, and exposes a SwiftUI-ready ViewModel. Mock repository returns sample templates so Phase 5 UI can wire up immediately; Phase 4 will swap the mock for Lynx-sourced templates.</what-built>
  <how-to-verify>
    1. Run: `xcodebuild test -scheme ENVI`
    2. Confirm: 5 new files added (1 model, 2 core, 1 repo, 1 feature VM)
    3. Confirm: Tests cover matching, ranking, and VM loading flows
  </how-to-verify>
  <resume-signal>Type "approved" to commit + push + proceed to Phase 4</resume-signal>
</task>

</tasks>

<verification>
- [ ] `swift build` succeeds
- [ ] All Phase 3 tests pass
- [ ] VideoTemplate models are JSON round-trippable
- [ ] Phase 3 commit pushed
</verification>

<success_criteria>
- 5 new files: VideoTemplateModels, TemplateMatchEngine, TemplateRanker, VideoTemplateRepository, TemplateTabViewModel
- Matching respects all MediaRequirements filters
- Ranking prioritizes high-fill templates
- ViewModel loads catalog via mock repo
- Phase committed and pushed
</success_criteria>

<output>
Create `.planning/phases/template-tab-v1/03-SUMMARY.md` documenting the scoring weights chosen, mock template catalog content, and commit SHA.
</output>
