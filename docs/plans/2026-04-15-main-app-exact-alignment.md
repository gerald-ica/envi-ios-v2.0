# Main App Exact Alignment Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the live iOS UI match the Sketch `Main App` page in `COPY-DRAFT ENVI-iOS-v2․0.sketch` as closely as possible across Feed, Library, AI Chat / World Explorer, Analytics, Profile, and shared chrome.

**Architecture:** Keep the existing screen routing and data sources, but replace the visible shell, spacing, typography, color, and screen composition to mirror Sketch exactly. Centralize shared chrome and token usage first, then align each screen in isolated lanes so the work can be done in parallel without file conflicts.

**Tech Stack:** SwiftUI, UIKit container shell, Sketch source-of-truth, token JSON, existing `ENVITheme` / typography helpers, `xcodebuild` device verification.

---

### Task 1: Lock Shared Main App Tokens And Chrome

**Files:**
- Modify: `ENVI/Components/ENVITabBar.swift`
- Modify: `ENVI/Navigation/MainTabBarController.swift`
- Modify: theme/token files used by screen styling (`ENVITheme` / spacing / typography definitions once identified in repo)
- Reference: `/Users/wendyly/Downloads/copy-draft-envi-ios-v2-0.tokens.json`

**Step 1: Normalize shared tokens**

- Apply the Sketch token palette as the source of truth:
  - `bg = #000000`
  - `surface-low = #1A1A1A`
  - `surface-high = #2A2A2A`
  - `text = #FFFFFF`
  - `text-secondary = #FFFFFFB3`
  - `text-light = #FFFFFF80`
  - `border = #FFFFFF1F`
  - `accent = #30217C`
- Confirm the app’s reusable chip, pill, card, and divider surfaces use these exact values where they appear on `Main App`.

**Step 2: Rebuild the tab pill exactly**

- Update `ENVITabBar` to match the Sketch pill geometry, fill, spacing, icon sizing, active circle behavior, and center-logo treatment from the `Tab Pill Bar` group.
- Replace the placeholder center symbol with the ENVI logo asset or a code-drawn equivalent that matches the Sketch mark proportions.
- Make sure the tab bar sits on the same vertical rhythm as Sketch and does not drift when screens scroll.

**Step 3: Align shared top chrome patterns**

- Standardize the small left utility pill, centered segmented control, and right utility icon treatment used across Feed and Library.
- Ensure top safe-area spacing, divider usage, and background behavior are identical across the screens that share this pattern.

**Step 4: Verify**

- Build on device.
- Compare top chrome and tab bar visually against Sketch before moving to per-screen work.

### Task 2: Feed And Library Exact Alignment

**Files:**
- Modify: `ENVI/Features/ForYouGallery/ForYouGalleryContainerView.swift`
- Modify: `ENVI/Features/ForYouGallery/ForYouSwipeView.swift`
- Modify: `ENVI/Features/ForYouGallery/GalleryGridView.swift`
- Modify: `ENVI/Features/Library/LibraryView.swift` only if reused pieces should move there instead of `ForYouGallery`
- Modify: any supporting reusable card or badge views used by these screens

**Step 1: Match Feed frame `10 - Feed`**

- Rebuild the header to match Sketch exactly:
  - left compact utility pill
  - centered `FOR YOU / GALLERY` segmented control
  - right action icon
- Update the feed card stack so the front card uses the Sketch composition:
  - oversized media card
  - top-right AI score badge cluster
  - bottom metadata row with platform badge, handle, and trailing action icon
  - correct corner radii, internal padding, and text hierarchy
- Keep the lower stacked card preview visible beneath the hero card with the same overlap and scroll behavior shown in Sketch.

**Step 2: Match Library frame `12 - Library`**

- Recompose the same top segmented chrome, but with `GALLERY` active.
- Align the Saved Templates horizontal strip to the three-card Sketch layout.
- Rebuild the Social Media Arsenal masonry section so item sizes, gutters, and vertical rhythm mirror the Sketch board.
- Restyle the FAB to match the Sketch `FAB` group exactly.

**Step 3: Verify**

- Build and compare Feed and Library side-by-side with Sketch screenshots.
- Check on-device scroll behavior, segmented state changes, and tab bar overlap.

### Task 3: AI Chat / World Explorer Exact Alignment

**Files:**
- Modify: `ENVI/Features/ChatExplore/ChatExploreView.swift`
- Modify: `ENVI/Features/ChatExplore/WorldExplorer/WorldExplorerView.swift`
- Modify: `ENVI/Features/ChatExplore/Chat/EnhancedChatHomeView.swift`
- Modify: `ENVI/Features/ChatExplore/WorldExplorer/ExplorerSearchBar.swift`
- Modify: `ENVI/Features/ChatExplore/WorldExplorer/SuggestionPillView.swift`
- Modify: `ENVI/Features/Chat/ChatInputBar.swift` or `EnhancedChatInputBar` implementation if needed

**Step 1: Match frame `13 - Envi-ous Brain Ai Chat / World Explorer`**

- Replace the current generic `EXPLORE / CHAT` top toggle with the actual Sketch header treatment:
  - left chat history icon
  - timeline toggle icon cluster
  - right utility icon / ENVI mark positioning
- Rebuild the headline block to match:
  - `[01] ENVI AI`
  - `YOUR CONTENT TIMELINE`
  - content types legend on the right

**Step 2: Recompose the explore surface**

- Make the content timeline the dominant visual:
  - clustered thumbnail field with depth and intentional irregular placement
  - right-side vertical scrubber with month label and D/W/M/Y zoom controls
- Restyle the suggested-question cluster and bottom composer to match the Sketch groups rather than the current generic chat layout.

**Step 3: Preserve behavior while changing layout**

- Keep existing interaction hooks:
  - suggestion tap seeds chat
  - timeline / card taps still route to the current details or editor flows
- Avoid changing core data flow until the visual shell is correct.

**Step 4: Verify**

- Build and confirm the explore screen matches Sketch at rest, including bottom input, timeline density, and header controls.

### Task 4: Analytics Exact Alignment

**Files:**
- Modify: `ENVI/Features/Analytics/AnalyticsView.swift`
- Modify: `ENVI/Features/Analytics/KPICardView.swift`
- Modify: `ENVI/Components/ENVIChip.swift` or use a screen-local analytics chip if exact styling differs
- Modify: supporting analytics subviews only where the visible shell diverges from Sketch

**Step 1: Match frame `16 - Analytics` above the fold**

- Align title, date range, `Last 7 Days` badge, platform chips, and KPI cards to the Sketch frame.
- Ensure chip heights, border opacity, and active/inactive states match the board exactly.
- Update KPI cards to match the Sketch card dimensions, icon placement, label sizes, and delta styling.

**Step 2: Reduce visual drift below the fold**

- Keep the deeper analytics sections, but make the first screenful match Sketch exactly.
- Where downstream sections are not represented in Sketch, inherit the same card system and spacing so the screen still feels like one designed surface.

**Step 3: Verify**

- Build and compare the first viewport against Sketch.
- Confirm navigation from Profile into Analytics still works.

### Task 5: Profile Exact Alignment

**Files:**
- Modify: `ENVI/Features/Profile/ProfileView.swift`
- Modify: `ENVI/Features/Profile/ConnectedPlatformsView.swift`
- Modify: `ENVI/Features/Profile/ProfileViewModel.swift` only if data labels need reshaping
- Modify: `ENVI/Features/Subscription/SubscriptionStatusView.swift`
- Modify: `ENVI/Features/Profile/SettingsView.swift` if row extraction is still needed

**Step 1: Match frame `17 - Profile` exactly**

- Replace the current gradient-banner profile with the Sketch composition:
  - centered circular avatar on plain dark background
  - name and handle spacing exactly as shown
  - three equal stat tiles with the same sizing and typography
  - single subscription card row
  - connected platforms heading and rows
  - account/settings list rows with background strips and chevrons

**Step 2: Remove non-Sketch extras from the first viewport**

- Defer or relocate appearance toggles and other controls that do not exist in the Sketch frame.
- Keep required app functionality, but do not let secondary controls distort the layout target.

**Step 3: Verify**

- Build and compare the entire profile screen against Sketch.
- Confirm account/settings taps still work.

### Task 6: Parallel Execution Lanes

**Lane A: Shared chrome + Feed/Library**

**Files:**
- `ENVI/Components/ENVITabBar.swift`
- `ENVI/Navigation/MainTabBarController.swift`
- `ENVI/Features/ForYouGallery/ForYouGalleryContainerView.swift`
- `ENVI/Features/ForYouGallery/ForYouSwipeView.swift`
- `ENVI/Features/ForYouGallery/GalleryGridView.swift`

**Lane B: Chat / World Explorer + Analytics**

**Files:**
- `ENVI/Features/ChatExplore/ChatExploreView.swift`
- `ENVI/Features/ChatExplore/WorldExplorer/WorldExplorerView.swift`
- `ENVI/Features/ChatExplore/Chat/EnhancedChatHomeView.swift`
- `ENVI/Features/Analytics/AnalyticsView.swift`
- `ENVI/Features/Analytics/KPICardView.swift`

**Lane C: Profile**

**Files:**
- `ENVI/Features/Profile/ProfileView.swift`
- `ENVI/Features/Profile/ConnectedPlatformsView.swift`
- `ENVI/Features/Profile/SettingsView.swift`
- `ENVI/Features/Subscription/SubscriptionStatusView.swift`

**Integration rule:**

- No lane modifies another lane’s screen files.
- Shared theme/token updates happen first or get merged through a single reviewer pass before device verification.

### Task 7: Device Verification

**Run:**

```bash
cd /Users/wendyly/Documents/envi-ios-v2.0
xcodebuild -project ENVI.xcodeproj -scheme ENVI -destination 'id=00008150-001E25241A82401C' -configuration Debug -allowProvisioningUpdates build
xcrun devicectl device install app --device 00008150-001E25241A82401C '/Users/wendyly/Library/Developer/Xcode/DerivedData/ENVI-exnbfvtplkaslraldgcmkfunilif/Build/Products/Debug-iphoneos/ENVI.app'
xcrun devicectl device process launch --device 00008150-001E25241A82401C com.informal.envi
```

**Expected:**

- Successful build
- Successful install
- Successful launch
- Manual visual verification against Sketch for:
  - Feed
  - Library
  - AI Chat / World Explorer
  - Analytics
  - Profile
  - shared tab/header chrome

### Task 8: Final Fit And Finish Pass

**Files:**
- Only files touched in tasks above

**Step 1: Pixel-drift cleanup**

- Fix any remaining differences in:
  - top safe-area spacing
  - chip heights
  - card radii
  - border opacity
  - text tracking
  - tab pill placement
  - FAB size and shadow

**Step 2: Regression check**

- Ensure no navigation regressions were introduced while making the UI exact.
- Re-run build and relaunch on device after the final polish pass.
