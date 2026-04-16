# Main App Sketch Alignment Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the iOS app UI in `/Users/wendyly/Documents/envi-ios-v2.0` visually match the Sketch file `COPY-DRAFT ENVI-iOS-v2․0.sketch` page `Main App` for Feed, Library, AI Chat / World Explorer, Analytics, Profile, and the shared tab chrome.

**Architecture:** Keep the current app structure and tab shell, but refactor each surface to match the Sketch composition exactly: spacing, typography, pill controls, floating actions, card shapes, and shared dark visual language. Reuse the existing design system where it fits, and add only the missing primitives needed to close the gap cleanly.

**Tech Stack:** SwiftUI, UIKit shell (`MainTabBarController`, `ENVITabBar`), existing `ENVITheme` / typography / spacing system, Sketch reference, token JSON.

---

### Task 1: Lock The Shared Visual System To Sketch

**Files:**
- Modify: `ENVI/Core/Design/ENVITheme.swift`
- Modify: `ENVI/Core/Design/ENVISpacing.swift`
- Modify: `ENVI/Core/Design/ENVITypography.swift`
- Modify: `ENVI/Components/ENVITabBar.swift`
- Optional create: `ENVI/Components/MainApp/ENVISketchHeader.swift`
- Optional create: `ENVI/Components/MainApp/ENVISegmentedPill.swift`
- Optional create: `ENVI/Components/MainApp/ENVIFloatingActionButton.swift`

**Design targets from tokens / Sketch:**
- Background: `#000000`
- Low surface: `#1A1A1A`
- High surface: `#2A2A2A`
- Border: `#FFFFFF1F`
- Text: `#FFFFFF`
- Secondary text: `#FFFFFFB3`
- Light text: `#FFFFFF80`
- Accent: `#30217C`
- Tab pill blue: match Sketch tab bar fill already approximated in `ENVITabBar`

**Implementation steps:**
1. Audit current theme values against the token file and normalize any mismatches.
2. Add any missing one-off colors used repeatedly in `Main App` screens instead of hardcoding them per screen.
3. Standardize display typography to Space Mono for large labels and Inter for supporting text to match Sketch hierarchy.
4. Refine the shared bottom tab pill to match the Sketch geometry exactly:
   - outer pill placement
   - active white circle
   - icon sizing / weights
   - padding and bottom safe-area behavior
5. Create shared top header / segmented pill primitives so Feed and Library do not duplicate slightly different Sketch chrome.

**Verification:**
- Build compiles with no new warnings.
- Feed and Library can share one visual segmented/header system.
- Tab bar geometry matches the Sketch frame proportionally on a 393pt-wide device.

### Task 2: Align Feed And Library To Frames `10 - Feed` And `12 - Library`

**Files:**
- Modify: `ENVI/Features/ForYouGallery/ForYouGalleryContainerView.swift`
- Modify: `ENVI/Features/ForYouGallery/ForYouSwipeView.swift`
- Modify: `ENVI/Features/Library/LibraryView.swift`
- Modify: `ENVI/Features/Library/MasonryGridView.swift`
- Modify: `ENVI/Features/Library/TemplateCarousel.swift`
- Modify: `ENVI/Features/Library/SmartCollectionView.swift`
- Modify: `ENVI/Features/ForYouGallery/FeedDetailView.swift`
- Reuse / adjust: `ENVI/Components/MainApp/*`

**Sketch targets:**
- Shared top row: left search/chat pill, centered segmented pill, right utility icon.
- Feed:
  - instruction label above the cards
  - full-bleed visual card stack with large rounded corners
  - AI score badge overlay
  - bottom metadata row on cards
- Library:
  - same top chrome, but Gallery segment active
  - “Saved Templates” horizontal row
  - “Social Media Arsenal” masonry layout
  - floating plus button at lower-right

**Implementation steps:**
1. Refactor `ForYouGalleryContainerView` so the header matches Sketch spacing and uses shared segmented/header primitives.
2. Update `ForYouSwipeView` card composition to match the front-card overlay layout in Sketch.
3. Bring the gallery state inside `LibraryView` into the same visual system so it feels like the second half of the same screen, not a separate dashboard.
4. Rework `TemplateCarousel` card sizing so the top template strip visually matches the three-card Sketch row.
5. Tighten `MasonryGridView` spacing, radii, metadata treatments, and section labeling to match `12 - Library`.
6. Move the library FAB to the exact sketch-like floating placement and weight.

**Verification:**
- Both screen states read as one shared system with only the active segment changing.
- The feed card, template row, and arsenal grid visually match Sketch proportions.

### Task 3: Align AI Chat / World Explorer To Frame `13 - Envi-ous Brain Ai Chat / World Explorer`

**Files:**
- Modify: `ENVI/Features/ChatExplore/ChatExploreView.swift`
- Modify: `ENVI/Features/ChatExplore/WorldExplorer/WorldExplorerView.swift`
- Modify: `ENVI/Features/ChatExplore/WorldExplorer/ExplorerSearchBar.swift`
- Modify: `ENVI/Features/ChatExplore/WorldExplorer/SuggestionPillView.swift`
- Modify: `ENVI/Features/ChatExplore/Chat/EnhancedChatHomeView.swift`
- Modify: `ENVI/Features/ChatExplore/ChatExploreView.swift`
- Optional create: `ENVI/Components/MainApp/ENVIBottomComposer.swift`

**Sketch targets:**
- No generic segmented control at the top; use the Sketch-specific header language.
- Large “YOUR CONTENT TIMELINE” title block.
- Right-side content-type legend.
- Right-side vertical scrubber / zoom controls.
- Suggested question stack above the bottom composer.
- Bottom composer row with plus button and rounded input shell.

**Implementation steps:**
1. Replace the current simple Explore / Chat top segmented strip with the Sketch header and mode controls.
2. Bring `WorldExplorerView` overlays into exact Sketch positions and scale.
3. Restyle suggestion pills so they match the multi-line and short-chip pattern in Sketch.
4. Update the bottom input / plus-action bar to match the Sketch chat composer shell.
5. Ensure the enhanced chat mode inherits the same shell and transitions so switching between world explorer and chat feels like one screen.

**Verification:**
- Explore mode visually matches the Sketch timeline screen.
- Chat mode still functions, but now inherits the same visual chrome and bottom composer language.

### Task 4: Align Analytics To Frame `16 - Analytics`

**Files:**
- Modify: `ENVI/Features/Analytics/AnalyticsView.swift`
- Modify: `ENVI/Features/Analytics/KPICardView.swift`
- Modify: `ENVI/Components/ENVIChip.swift`
- Modify: `ENVI/Components/ENVIPlatformFilterBar.swift`
- Modify: `ENVI/Features/Analytics/EngagementChartView.swift`

**Sketch targets:**
- Large left-aligned `ANALYTICS` title
- Date range under title
- compact “Last 7 Days” badge on the right
- platform chips directly underneath
- compact KPI cards with strong metric hierarchy
- overall vertical density closer to Sketch than the current roomy dashboard

**Implementation steps:**
1. Reduce top spacing and tighten title/date/badge grouping.
2. Restyle chips to the Sketch weight and radius.
3. Shrink KPI cards to match the denser three-up row from Sketch.
4. Adjust chart section spacing and card framing so the above-the-fold layout matches before deeper analytics continue.

**Verification:**
- First viewport of Analytics matches the Sketch frame composition.
- Existing deeper analytics content remains functional below the fold.

### Task 5: Align Profile To Frame `17 - Profile`

**Files:**
- Modify: `ENVI/Features/Profile/ProfileView.swift`
- Modify: `ENVI/Features/Profile/ProfileViewModel.swift`
- Reuse / adjust: `ENVI/Features/Profile/ConnectedPlatformsView.swift`
- Reuse / adjust: `ENVI/Features/Profile/SubscriptionStatusView.swift`

**Sketch targets:**
- Remove the current gradient-banner treatment
- Use centered avatar, name, and handle on a flat dark background
- three stat cards in one row
- subscription card immediately below the divider
- connected platforms list and settings rows with full-width row styling

**Implementation steps:**
1. Replace the banner-first composition with the flatter Sketch profile header.
2. Resize and restyle stat cards to match the 3-up profile metrics.
3. Tighten the subscription card to the Sketch height and arrow treatment.
4. Convert connected platforms and settings rows into the flatter list-row structure from Sketch.
5. Keep existing sheet/navigation behavior, but make the visual shell match the frame exactly.

**Verification:**
- Profile no longer feels like a separate visual system from Feed / Library / Analytics.
- Top half of the screen matches the Sketch hierarchy and spacing.

### Task 6: Integrate, Build, And Device-Verify

**Files:**
- Modify only if needed after integration: `ENVI/Navigation/MainTabBarController.swift`
- Verify on device build products under DerivedData

**Execution lanes for parallel implementation:**
- Lane A: Shared chrome + Feed / Library
- Lane B: AI Chat / World Explorer
- Lane C: Analytics + Profile

**Integration steps:**
1. Land shared visual primitives first.
2. Apply lane-specific screen changes in parallel.
3. Reconcile any shared component conflicts in one final pass.
4. Build for device.
5. Install and launch on `Yurrr thats me (2)`.
6. Verify no regressions in tab switching, sheets, and scroll-driven tab-bar behavior.

**Verification commands:**
- `xcodebuild -project ENVI.xcodeproj -scheme ENVI -destination 'id=00008150-001E25241A82401C' -configuration Debug -allowProvisioningUpdates build`
- `xcrun devicectl device install app --device 00008150-001E25241A82401C '/Users/wendyly/Library/Developer/Xcode/DerivedData/ENVI-exnbfvtplkaslraldgcmkfunilif/Build/Products/Debug-iphoneos/ENVI.app'`
- `xcrun devicectl device process launch --device 00008150-001E25241A82401C com.informal.envi`

