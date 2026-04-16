# Main App UI Alignment Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the app's primary experience visually and behaviorally match Sketch page `Main App`, fix startup/navigation flow issues uncovered during verification, and restore a reliable path to run on device.

**Architecture:** Keep the existing SwiftUI + UIKit hybrid, but replace the current 3-tab shell with a `MainTabBarController` host that presents the five Sketch-aligned surfaces: Feed, Library, ENVI AI / World Explorer, Analytics, and Profile. Treat styling parity as a shared design-system pass first, then do screen-specific realignment so navigation and visual changes do not fight each other.

**Tech Stack:** Swift, SwiftUI, UIKit, Xcode project target `ENVI`, Sketch reference page `Main App`, XcodeBuildMCP / xcodebuild for verification.

---

### Task 1: Lock The Reference Surface Map

**Files:**
- Modify: `docs/plans/2026-04-15-main-app-ui-alignment.md`
- Reference: `ENVI/Navigation/MainTabBarController.swift`
- Reference: `ENVI/Features/Feed/FeedViewController.swift`
- Reference: `ENVI/Features/Library/LibraryView.swift`
- Reference: `ENVI/Features/ChatExplore/ChatExploreView.swift`
- Reference: `ENVI/Features/Analytics/AnalyticsView.swift`
- Reference: `ENVI/Features/Profile/ProfileView.swift`

**Step 1: Record the Sketch-to-code mapping**

- `10 - Feed` -> `FeedViewController` / `ForYouGalleryContainerView`
- `11 - Feed Detail` -> Feed detail route from the primary feed
- `12 - Library` -> `LibraryView`
- `13 - Envi-ous Brain Ai Chat / World Explorer` -> `ChatExploreView`
- `16 - Analytics` -> `AnalyticsView`
- `17 - Profile` -> `ProfileView`

**Step 2: Record the visual constants from Sketch**

- Background: textured black / graphite, not flat black
- Typography: bold mono headings, restrained uppercase labels, muted gray support copy
- Cards: large-radius dark panels with soft glow / blur treatments
- Navigation: bottom floating 3-icon pill in Sketch, but app information architecture needs 5 primary surfaces
- Feed / Library top controls: segmented pill switches, icon buttons, heavy spacing discipline

**Step 3: Decide the shell strategy**

- Recommended: preserve five primary surfaces and adapt the Sketch bottom pill language into a five-destination ENVI tab system.
- Do not collapse Analytics into Profile during this pass.
- Do not preserve the current 3-tab architecture.

### Task 2: Fix The Startup Flow Baseline

**Files:**
- Modify: `ENVI/App/AppCoordinator.swift`
- Modify: `ENVI/App/SceneDelegate.swift`
- Modify: `ENVI/Features/Auth/SignInView.swift`
- Test: manual simulator verification

**Step 1: Verify current post-splash routing**

Run:
```bash
xcodebuild -project ENVI.xcodeproj -scheme ENVI -destination 'platform=iOS Simulator,id=ECF3488E-5D2F-4FDC-A62E-62064D433227' build
```

Expected:
- Build succeeds.
- App launches to splash, then transitions to sign-in when onboarding/session restore does not complete.

**Step 2: Remove ambiguous splash stalls**

- Audit `SplashViewController.onComplete` timing and any async work that can trap the user on splash longer than intended.
- Ensure splash is a bounded transition, not a dependency sink.

**Step 3: Normalize the unauthenticated path**

- Sign-in must be a first-class screen, not an afterthought.
- Match the Sketch tone: centered logo, mono labels, large form fields, strong primary CTA, Apple/Google auth buttons, muted footer actions.

### Task 3: Replace The 3-Tab Shell With A 5-Surface Main App Shell

**Files:**
- Modify: `ENVI/Navigation/MainTabBarController.swift`
- Modify: `ENVI/Components/ENVITabBar.swift`
- Modify: `ENVI/App/AppCoordinator.swift`
- Test: manual simulator verification

**Step 1: Define five shell destinations**

- Feed
- Library
- AI / World Explorer
- Analytics
- Profile

**Step 2: Update the controller ownership**

- Keep UIKit as the shell host.
- Wrap SwiftUI screens in hosting controllers where needed.
- Keep per-screen nav stacks local to the screen instead of burying everything under one ambiguous root.

**Step 3: Rebuild the tab bar visual language**

- Floating glass / glow pill
- Mono / icon-forward treatment
- Correct selected-state emphasis
- Safe-area-aware placement and hide/show behavior

**Step 4: Preserve detail pushes**

- Feed detail, profile subpages, and analytics drill-downs should push or present from the correct child surface, not from a mismatched parent.

### Task 4: Realign Feed To Sketch `10 - Feed`

**Files:**
- Modify: `ENVI/Features/Feed/FeedViewController.swift`
- Modify: `ENVI/Features/Feed/ExpandableFeedCardView.swift`
- Modify: `ENVI/Features/Feed/ContentCardView.swift`
- Modify: `ENVI/Features/Feed/ExploreGridView.swift`
- Modify: `ENVI/Core/Design/ENVITheme.swift`

**Step 1: Replace current top bar semantics**

- Remove the `ENVI / FOR YOU / EXPLORE / bell` bar shape.
- Match Sketch: search icon left, segmented pill centered, calendar or utility icon right.

**Step 2: Make feed cards match the reference**

- Taller hero cards
- Overlay metrics chips on media
- Username / bookmark placement consistent with Sketch
- Stronger breathing room between cards

**Step 3: Keep the feed-detail route visually consistent**

- Feed detail should inherit the same material system and not fall back to generic UIKit spacing.

### Task 5: Realign Library To Sketch `12 - Library`

**Files:**
- Modify: `ENVI/Features/Library/LibraryView.swift`
- Modify: `ENVI/Features/Library/TemplateCarousel.swift`
- Modify: `ENVI/Features/Library/MasonryGridView.swift`
- Modify: `ENVI/Core/Design/ENVITheme.swift`

**Step 1: Replace the current title-first layout**

- Move toward segmented gallery toggle + section labels rather than a plain `LIBRARY` heading opening.

**Step 2: Restructure sections to match the reference**

- `Saved Templates`
- `Social Media Arsenal`
- Staggered gallery grid with correct card aspect ratios

**Step 3: Reduce enterprise-dashboard noise**

- De-emphasize secondary controls that do not belong in the reference surface.
- Move non-reference DAM affordances lower or behind drill-downs.

### Task 6: Realign AI / World Explorer To Sketch `13`

**Files:**
- Modify: `ENVI/Features/ChatExplore/ChatExploreView.swift`
- Modify: `ENVI/Features/ChatExplore/WorldExplorer/*.swift`
- Modify: `ENVI/Features/ChatExplore/AIChat*.swift`
- Modify: `ENVI/Core/Design/ENVITheme.swift`

**Step 1: Match the hero composition**

- Large `YOUR CONTENT TIMELINE` title
- Floating content nodes
- Right-side content-type legend / time rail
- Bottom prompt bar and quick chips

**Step 2: Keep the explorer functional**

- Do not replace real interaction with a static mock.
- Preserve content filters, prompt input, and detail routes.

**Step 3: Support the alternate chat-only state**

- Implement the `no World Explorer` variant as a real mode, not a separate dead-end view.

### Task 7: Realign Analytics To Sketch `16 - Analytics`

**Files:**
- Modify: `ENVI/Features/Analytics/AnalyticsView.swift`
- Modify: `ENVI/Features/Analytics/KPICardView.swift`
- Modify: `ENVI/Features/Analytics/EngagementChartView.swift`
- Modify: `ENVI/Features/Analytics/ContentCalendarView.swift`

**Step 1: Simplify the analytics hero**

- Single large `ANALYTICS` heading
- compact date-range chip
- platform filter row

**Step 2: Match KPI and chart styling**

- Dark cards with green status glow
- cleaner spacing and smaller chrome
- fewer stacked sections above the fold

**Step 3: Keep advanced modules below the primary reference fold**

- The top of the screen should match Sketch first.
- Advanced sections can remain, but they should not visually overpower the primary analytics summary.

### Task 8: Realign Profile To Sketch `17 - Profile`

**Files:**
- Modify: `ENVI/Features/Profile/ProfileView.swift`
- Modify: `ENVI/Features/Profile/SettingsView.swift`
- Modify: `ENVI/Features/Profile/ProfileViewModel.swift`

**Step 1: Recompose the header**

- large avatar
- centered name / handle
- numeric stat cards
- blue atmospheric background treatment

**Step 2: Rebuild subscription and platform sections**

- `Aura Active` banner with one-line management affordance
- connected platforms list with status pills

**Step 3: Simplify settings rows**

- Match the reference row spacing, icon weight, and chevron treatment.

### Task 9: Shared Design-System Pass

**Files:**
- Modify: `ENVI/Core/Design/ENVITheme.swift`
- Modify: `ENVI/Core/Design/ENVITypography.swift`
- Modify: `ENVI/Components/ENVICard.swift`
- Modify: `ENVI/Components/ENVIChip.swift`
- Modify: `ENVI/Components/ENVIButton.swift`
- Modify: `ENVI/Components/ENVIBadge.swift`

**Step 1: Add the missing visual tokens**

- textured / atmospheric background support
- glow colors
- elevated pill materials
- mono uppercase label presets

**Step 2: Normalize component geometry**

- consistent radius scale
- consistent internal padding
- consistent inactive/active contrast

**Step 3: Eliminate generic defaults**

- remove plain system buttons where Sketch calls for branded controls
- remove mismatched light-on-dark shades that flatten hierarchy

### Task 10: Runtime Configuration Fixes

**Files:**
- Modify: `ENVI/SupportingFiles/Info.plist`
- Modify: `ENVI/App/ENVIApp.swift`
- Modify: `ENVI/Core/Media/MediaScanCoordinator+BackgroundTasks.swift`
- Reference: `docs/github-wiki/Getting-Started.md`

**Step 1: Add missing background-task plist entry**

- Add `BGTaskSchedulerPermittedIdentifiers`
- Include `com.envi.mediaclassifier.fullscan`

**Step 2: Make Firebase absence explicit and safe**

- Current simulator launch logs show `Firebase not configured: missing GoogleService-Info.plist`.
- Keep the app running without Firebase, but make the degraded mode intentional and observable.

**Step 3: Keep purchase configuration clearly non-production**

- Current logs show the app uses a RevenueCat test-store key.
- Treat that as a development-only state.

### Task 11: Device Signing Recovery

**Files:**
- No repo change required first
- Optional local override only if user approves

**Step 1: Resolve Xcode account state**

Current blocker from direct device build:
```text
No Account for Team "ZM82DY7PG2"
No profiles for 'com.informal.envi' were found
```

**Step 2: Fix on the machine before retrying**

- Re-authenticate the Apple Developer account for team `ZM82DY7PG2` in Xcode Accounts, or
- switch the project to a locally valid development team and bundle ID for local-only verification

**Step 3: Retry device build**

Run:
```bash
xcodebuild -project ENVI.xcodeproj -scheme ENVI -destination 'id=00008150-001E25241A82401C' -allowProvisioningUpdates build
```

Expected:
- profile resolves
- app signs
- app installs on `Yurrr thats me (2)`

### Task 12: Verification

**Files:**
- Test: simulator + device

**Step 1: Simulator baseline**

Run:
```bash
xcodebuild -project ENVI.xcodeproj -scheme ENVI -destination 'platform=iOS Simulator,id=ECF3488E-5D2F-4FDC-A62E-62064D433227' build
```

Expected:
- `** BUILD SUCCEEDED **`

**Step 2: Simulator launch**

Run with XcodeBuildMCP:
```text
build_run_sim
```

Expected:
- App launches
- Splash transitions to sign-in or onboarding instead of hanging indefinitely

**Step 3: Device launch**

Run after signing is repaired:
```bash
xcodebuild -project ENVI.xcodeproj -scheme ENVI -destination 'id=00008150-001E25241A82401C' -allowProvisioningUpdates build
```

Expected:
- App builds and installs to `Yurrr thats me (2)`
- Manual verification confirms startup flow, tab shell, and the five primary surfaces match the Sketch direction
