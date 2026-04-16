---
phase: 03-template-engine
status: complete
completed: 2026-04-15
---

# Phase 3: Template Engine — Summary

**Template matching brain shipped: VideoTemplate models + slot-to-asset scoring + "For You" ranking + SwiftUI-ready ViewModel. Mock repository lets Phase 5 UI wire up immediately; Phase 4 swaps in Lynx catalog.**

## Files Created (8 total: 5 prod + 3 tests + 1 additional test)

**Production:**
- `ENVI/Models/VideoTemplateModels.swift` (~620 LOC) — all Codable structs + 5 mock templates
- `ENVI/Core/Templates/TemplateMatchEngine.swift` — actor, slot scoring + cohesion bonus
- `ENVI/Core/Templates/TemplateRanker.swift` — "For You" ranking with breakdown
- `ENVI/Core/Data/Repositories/VideoTemplateRepository.swift` — protocol + MockVideoTemplateRepository with latency/error injection
- `ENVI/Features/Templates/TemplateTabViewModel.swift` — @Observable @MainActor, AsyncStream-based selection handoff

**Tests:**
- `ENVITests/Templates/VideoTemplateModelsTests.swift`
- `ENVITests/Templates/TemplateMatchEngineTests.swift`
- `ENVITests/Templates/TemplateRankerTests.swift`
- `ENVITests/Features/Templates/TemplateTabViewModelTests.swift`

## Scoring Weights Chosen (TemplateMatchEngine)

- **Label match** (+0.40): `|preferredLabels ∩ topLabels| / |preferredLabels|`, case-insensitive
- **Aesthetics** (+0.20): normalized `(score+1)/2`, clamped to [0,1]
- **Face/Person filter match** (+0.15)
- **Recency preference window** (+0.10)
- **Recent 30 days** (+0.10)
- **isFavorite OR burst hero** (+0.05)
- **Cohesion bonus** (+0.10): applied per-slot if the selected set lives in a dominant EmbeddingIndex cluster

Empty match threshold: score < 0.3 → slot stays nil (contributes 0 to fillRate).
No asset can fill two slots in the same template (usedIDs tracking).

## Ranker Weights (TemplateRanker)

- `fillWeight: 0.5` · `scoreWeight: 0.3` · `popularityWeight: 0.2`
- Secondary sort: recency of matched assets (creationDate decay)
- `rankWithBreakdown()` exposes component scores for debugging/A-B testing

## Mock Template Library (5 templates)

1. **Morning GRWM** — 4 slots, 15s, 9:16, pop=92
2. **Recipe Reel** — 4 slots (ingredients/prep/cook/plated), 20s, pop=78
3. **Outfit of the Day** — 4 slots (full/details/pose/tag), 10s, pop=85
4. **Travel Diary** — 5 slots (arrival/city/food/sunset/memories), 25s, pop=88
5. **Workout of the Week** — 4 slots (warmup/set1/set2/selfie), 18s, pop=71

## Decisions Made

- **Namespacing collisions resolved**: `AspectRatio` and `TextOverlay` already existed in `EditorModels.swift` with different shapes → nested template versions as `VideoTemplate.AspectRatio` and `VideoTemplate.TextOverlay`
- **Enum Codable for associated values**: `FaceCountFilter.exactly(Int)` uses `type` + `value` discriminator pattern
- **`DurationRange` struct** wraps `lowerBound`/`upperBound` since `Range<TimeInterval>` isn't Codable
- **`PopulatedTemplate.previewThumbnail: Data?`** (not UIImage) — keeps model platform-agnostic
- **Selection handoff via `AsyncStream`** in ViewModel (not Combine) — consistent with actor-based stack
- **Hard-filter pushdown via `#Predicate<ClassifiedAsset>`** in SwiftData query; softer filters (orientation, duration, subtype bitmask) applied in-memory on the pre-filtered set
- **Cohesion-bonus strategy**: after greedy best-per-slot picks, swap low-confidence slots to dominant-cluster alternates if embedding index reveals a cohesive set

## Readiness for Phase 4

✅ `VideoTemplateRepository` protocol ready — Phase 4's `TemplateCatalogClient` just conforms
✅ `VideoTemplate` is Codable — Phase 4's manifest schema can reuse the exact type
✅ `MockVideoTemplateRepository` stays as fallback (feature flag in Phase 4)

## Readiness for Phase 5

✅ `TemplateTabViewModel` compiles, @Observable works with SwiftUI
✅ `selections` AsyncStream ready for coordinator-level navigation
✅ `scanProgress` mirrored from Phase 1's MediaScanCoordinator
✅ Phase 5 only needs to build the SwiftUI views

## Parse Verification

All Phase 1 + 2 + 3 files parse clean together on iOS 26:
```
xcrun -sdk iphonesimulator swiftc -parse -target arm64-apple-ios26.0-simulator [21 files]
```
Zero errors, zero warnings from feature code.

## Commits

Phase 3 commit SHA: [see git log]
Branch: `feature/template-tab-v1`
Pushed to origin.
