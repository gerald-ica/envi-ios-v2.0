# Main App Sketch Parity Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the in-app shell and the five `Main App` surfaces match the Sketch file `COPY-DRAFT ENVI-iOS-v2․0.sketch` as closely as possible: `10 - Feed`, `12 - Library`, `13 - Envi-ous Brain Ai Chat / World Explorer`, `16 - Analytics`, and `17 - Profile`.

**Architecture:** Keep the existing navigation architecture, but refactor the visual shell and screen layouts to match the Sketch artboards exactly. Use the current ENVI token layer as the integration point, then make screen-local changes in the existing owners rather than rebuilding the app structure from scratch.

**Tech Stack:** SwiftUI, UIKit host shell (`MainTabBarController` + `ENVITabBar`), existing ENVI theme/fonts/tokens, Sketch reference geometry, `copy-draft-envi-ios-v2-0.tokens.json`.

---

## Source Of Truth

- Sketch document: `/Users/wendyly/Downloads/COPY-DRAFT ENVI-iOS-v2․0.sketch`
- Token JSON: `/Users/wendyly/Downloads/copy-draft-envi-ios-v2-0.tokens.json`
- Main App page targets:
  - `10 - Feed`
  - `12 - Library`
  - `13 - Envi-ous Brain Ai Chat / World Explorer`
  - `16 - Analytics`
  - `17 - Profile`

## Verified Sketch Constraints

- Global palette:
  - Background: `#000000`
  - Surface low: `#1A1A1A`
  - Surface high: `#2A2A2A`
  - Text: `#FFFFFF`
  - Text secondary: `#FFFFFFB3`
  - Border: `#FFFFFF1F`
  - Accent token JSON: `#30217C`
- Feed / Library top segment:
  - Segment container height `40`
  - Active pill height `32`
  - Rounded `20`
- Bottom pill bar:
  - Pill width `164`
  - Pill height `64`
  - Rounded `36`
  - Active icon background `45x45`
- Analytics cards and profile stat cards:
  - Card radius `12`
- Profile avatar:
  - `88x88`

## Implementation Approach

Use three parallel execution lanes with disjoint write scopes:

1. **Shell + Shared Chrome**
   - Owns global token cleanup, tab bar, top segmented shell alignment, and any safe-area or host-container adjustments.

2. **Feed / Library**
   - Owns the first two artboards and their shared segmented experience.

3. **Chat / Analytics / Profile**
   - Owns the remaining three artboards, split internally by screen-local subviews if needed.

This keeps screen work independent while preserving a single shared shell.

## Parallel Workstreams

### Lane A: Shell + Shared Chrome

**Files:**
- Modify: `ENVI/Core/Design/ENVITheme.swift`
- Modify: `ENVI/Core/Design/ENVISpacing.swift`
- Modify: `ENVI/Components/ENVITabBar.swift`
- Modify: `ENVI/Navigation/MainTabBarController.swift`

**Deliverables:**
- Remove remaining visual drift between current token layer and Sketch values.
- Make the bottom tab pill visually identical to the Sketch shell.
- Ensure host view controllers respect the same top and bottom insets as the artboards.
- Normalize shared icon sizing, active states, border opacity, and background surfaces.

**Notes:**
- `ENVITabBar.swift` still carries old hardcoded assumptions and placeholder icon treatment.
- The shell should not change information architecture unless Sketch explicitly requires it.

### Lane B: Feed + Library

**Files:**
- Modify: `ENVI/Features/ForYouGallery/ForYouGalleryContainerView.swift`
- Modify: `ENVI/Features/ForYouGallery/ForYouSwipeView.swift`
- Modify: `ENVI/Features/ForYouGallery/GalleryGridView.swift`
- Modify: `ENVI/Features/ForYouGallery/FeedDetailView.swift`
- Modify if needed: `ENVI/Features/ForYouGallery/ForYouGalleryViewModel.swift`

**Deliverables:**
- Match `10 - Feed`:
  - top-left utility pill
  - centered `FOR YOU / GALLERY` segmented control
  - right utility icon
  - instruction copy placement
  - stacked oversized preview cards with the same bottom metadata treatment
- Match `12 - Library`:
  - same top shell
  - `SAVED TEMPLATES` horizontal row
  - `SOCIAL MEDIA ARSENAL` two-column masonry
  - floating add button placement and scale

**Notes:**
- `GalleryGridView.swift` is the correct tab-0 library target; `LibraryView.swift` is a different, heavier surface and should not be used as the first parity target.
- Feed detail should only be updated enough to avoid a jarring mismatch once a feed card is opened.

### Lane C: Chat / Analytics / Profile

**Files:**
- Modify: `ENVI/Features/ChatExplore/ChatExploreView.swift`
- Modify: `ENVI/Features/ChatExplore/WorldExplorer/WorldExplorerView.swift`
- Modify if needed: `ENVI/Features/ChatExplore/WorldExplorer/ExplorerSearchBar.swift`
- Modify if needed: `ENVI/Features/ChatExplore/WorldExplorer/SuggestionPillView.swift`
- Modify: `ENVI/Features/Analytics/AnalyticsView.swift`
- Modify supporting analytics subviews as needed:
  - `ENVI/Features/Analytics/KPICardView.swift`
  - `ENVI/Features/Analytics/EngagementChartView.swift`
  - `ENVI/Components/ENVIPlatformFilterBar.swift`
- Modify: `ENVI/Features/Profile/ProfileView.swift`

**Deliverables:**
- Match `13 - Envi-ous Brain Ai Chat / World Explorer`:
  - top utility row
  - left hero title block
  - right content type legend
  - right-side scrubber / zoom cluster
  - bottom suggestion stack and prompt input
- Match `16 - Analytics`:
  - title and date badge hierarchy
  - compact platform chips
  - KPI card sizing, radius, border, and spacing
  - first screenful composition before lower analytics modules
- Match `17 - Profile`:
  - centered compact avatar and identity stack
  - three equal stat cards
  - subscription card
  - connected platform list
  - settings rows and section dividers

## Execution Order

1. Align shared shell and token mismatches first.
2. Implement Feed / Library while shell work is in review.
3. Implement Chat / Analytics / Profile in parallel after the shared shell API settles.
4. Reconcile visual spacing across all five screens.
5. Build and run on `Yurrr thats me (2)`.
6. Compare live device output against Sketch artboards and do one parity pass.

## Verification

- Build:
  - `cd /Users/wendyly/Documents/envi-ios-v2.0 && xcodebuild -project ENVI.xcodeproj -scheme ENVI -destination 'id=00008150-001E25241A82401C' -configuration Debug -allowProvisioningUpdates build`
- Install:
  - `xcrun devicectl device install app --device 00008150-001E25241A82401C '/Users/wendyly/Library/Developer/Xcode/DerivedData/ENVI-exnbfvtplkaslraldgcmkfunilif/Build/Products/Debug-iphoneos/ENVI.app'`
- Launch:
  - `xcrun devicectl device process launch --device 00008150-001E25241A82401C com.informal.envi`
- Process check:
  - `xcrun devicectl device info processes --device 00008150-001E25241A82401C | rg 'com\\.informal\\.envi|ENVI'`
- Manual visual verification:
  - Compare each implemented screen to its matching Sketch artboard for typography, spacing, radius, surface colors, icon placement, and visible scroll-region composition.

## Risks

- Some existing screens currently expose more product scope than the Sketch artboards; parity work should reduce visual noise without deleting core behavior unless required.
- The Sketch API exposes some fills as mixed color/gradient metadata; visual screenshot comparison should be treated as the final authority where raw layer style data is ambiguous.
- `WorldExplorerView` is the highest-risk parity surface because it combines 3D content with several HUD overlays.

## Parallel Execution Plan

- **Agent Team 1:** Shell + shared chrome
- **Agent Team 2:** Feed + Library
- **Agent Team 3:** Chat + Analytics + Profile

- Integration owner:
  - Reconcile token usage
  - resolve any overlap in `MainTabBarController.swift`
  - run device build / install / launch
  - perform final parity pass
