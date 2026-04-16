---
phase: 05-template-tab-ui
status: complete
completed: 2026-04-15
---

# Phase 5: Template Tab UI — Summary

**The Template tab is live. Users see templates pre-populated with their own camera roll content, ranked by how well their media fits, with full-screen preview + slot swap + export — all in ENVI's design system.**

## Files Created/Modified (8 total: 5 new + 2 modified + 1 modified+1 minor)

**New SwiftUI views:**
- `ENVI/Features/Templates/TemplateTabView.swift` — top-level shell with header, scan banner, category chips, For You grid, category rows
- `ENVI/Features/Templates/TemplateCardView.swift` — 2x2 thumb grid + slot-fill pill + context menu, AssetThumbnailLoader actor
- `ENVI/Features/Templates/TemplateCategoryRow.swift` — horizontal LazyHStack with section header
- `ENVI/Features/Templates/TemplatePreviewView.swift` — full-screen preview container with slot strip + swap + export
- `ENVI/Features/Templates/TemplatePlayerView.swift` — AVPlayer for video templates, SwiftUI crossfade for photo
- `ENVI/Features/Templates/TemplateOnboardingProgressView.swift` — onboarding scan UI with 3x3 mosaic + Skip

**Modified existing files:**
- `ENVI/Navigation/MainTabBarController.swift` — inserted Templates tab at index 2 (Feed/Library/Templates/Chat+Explore/Analytics/Profile)
- `ENVI/Features/Auth/OnboardingPhotosAccessView.swift` — presents TemplateOnboardingProgressView after Photos grant

## Tab Bar Integration

New tab order:
0. Feed (`house`)
1. Library (`square.grid.2x2`)
2. **Templates** (`square.grid.2x2.fill`) ← NEW
3. Chat + Explore (`sparkles`)
4. Analytics (`chart.bar`)
5. Profile (`person`)

**Index audit findings**: Grep for `viewControllers[N]` / `tabBar.selectedIndex = N` / `currentIndex = N` shows only internal references in MainTabBarController itself. No external code references tabs positionally — safe insertion at index 2.

## TemplateCardView Visual Design

- **Layout**: 180w × 240h cards with 180×180 thumbnail block + name + category + (optional) duration badge
- **Slot composition** adapts to slot count:
  - 1 slot → hero
  - 2 slots → side-by-side
  - 3 slots → hero-over-pair
  - 4+ slots → 2×2 grid (first four, placeholder tiles for unmatched)
- **Slot-fill pill** (top-right):
  - 100% filled → `ENVITheme.success` green with `✓`
  - ≥50% → `ENVITheme.warning` amber
  - <50% or empty → `Color.white.opacity(0.15)`
- **Context menu**: "Use Template" / "Find Similar Content" / "Hide This Template"
- **Thumbnail loading**: `AssetThumbnailLoader` actor wraps PHImageManager with in-memory cache + dedup of degraded/final double invocation
- **Responsive**: iPhone SE (375pt) shows ~1.7 cards, iPhone 16 Pro Max (440pt) shows ~2.2 cards per row in horizontal scroll

## TemplatePlayerView Composition Strategy

**Photo templates** (no video duration or all photos):
- SwiftUI ZStack with `.opacity` crossfade keyed on `currentSlotIndex`
- `Task` loop sleeps per `slot.duration`
- Tap to pause/resume
- Loops indefinitely

**Video templates**:
- `AVMutableComposition` with single video track
- Each video slot's `AVAssetTrack` inserted at running CMTime cursor
- Photo slots reserve gap of slot duration
- Single `AVPlayer` — `replaceCurrentItem` on swap (never reallocate the layer)
- Rebuild gated by `timelineSignature` (slot-id × localIdentifier hash) — no-op on identical state
- Async via `.task(id:)` off main; spinner overlay during compose
- Loops via `AVPlayerItemDidPlayToEndTime` → `seek(.zero)` + `play()`
- Audio: `AVAudioSession.ambient + .mixWithOthers` — silent switch respected, never hijacks music

**Text overlays** rendered as SwiftUI `Text` over composition (not baked in) — crisp at any scale, zero transcode cost.

## Slot Swap UX

- Tap slot in preview → SwiftUI `.sheet(item:)` with `.presentationDetents([.medium, .large])`
- Sheet shows horizontally scrolling alternates from `FilledSlot.alternates` (max 5) + "Choose from library" PHPicker option
- **Quality gate preserved**: PHPicker selection checked against `ClassifiedAsset` cache. Non-classified picks → alert "This photo is still being analyzed" (don't allow swap)
- Optimistic local update + fire-and-forget `viewModel.swap(...)` keeps VM in sync

## Onboarding Integration

After Photos grant in `OnboardingPhotosAccessView`:
1. `.fullScreenCover` presents `TemplateOnboardingProgressView`
2. View triggers `scanner.scanOnboardingBatch()` (last 500 PHAssets)
3. Live thumbnail mosaic refreshes at 1Hz from `ClassificationCache.fetchAll().suffix(9)` for engagement
4. Skip button → calls `scanner.scheduleBackgroundScan()` for full library + dismisses
5. Auto-dismiss when scan completes
6. Onboarding flow continues to next step

## Decisions Made

- **Wired real components in TemplateTabView**: After Tasks 2-3 landed, replaced `TemplateCardPlaceholder`/`TemplatePreviewPlaceholder` with real `TemplateCardView`/`TemplatePreviewView`
- **AssetThumbnailLoader** lives in TemplateCardView.swift — small, scoped actor. Phase 6 may consolidate with TemplatePreviewView's `TemplateSlotImageView` into a shared util
- **PHPicker over UIImagePickerController** — modern API, no NSPhotoLibraryUsageDescription beyond what we have, supports limited library
- **`ENVIBottomSheet` (UIKit) skipped in favor of SwiftUI `.sheet` + `presentationDetents`** — iOS 26 native, integrates better with SwiftUI navigation stack

## Known Caveats (deferred to Phase 6 or beyond)

- `MainTabBarController` and `OnboardingPhotosAccessView` each construct their own `ClassificationCache` + `MediaScanCoordinator`. Should centralize via dependency injection container in future phase.
- "Find Similar Content" context menu action wired but stubbed — needs hookup to `EmbeddingIndex.findSimilar()` for a "show similar templates" sheet
- Hide template action stubbed — needs persistence layer (UserDefaults set of hidden template IDs)
- Templates tab and Library tab use very similar SF symbols (`square.grid.2x2.fill` vs outline) — may want to differentiate before ship

## Parse Verification

All Phase 1-5 files (~37 Swift files + 2 HTML/JS resources + several existing modified) parse clean together on iOS 26.

## Commits

Phase 5 commit SHA: [see git log]
Branch: `feature/template-tab-v1`
Pushed to origin.
