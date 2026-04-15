---
phase: 05-template-tab-ui
milestone: template-tab-v1
type: execute
domain: ios-swiftui
depends-on: 04-lynx-bridge
---

<objective>
Build the user-facing Template Tab UI — SwiftUI screens showing category rows, slot-fill indicators, "For You" ranking, full-screen preview with user's real media in slots, and export flow.

Purpose: Ship the actual user experience. This is what the creator sees when they tap the Template tab.
Output: 7 new SwiftUI views, integrated into ENVI's existing MainTabBarController, matching ENVI's design system (ENVITheme, ENVITypography, ENVISpacing).
</objective>

<execution_context>
~/.claude/get-shit-done/workflows/execute-phase.md
.planning/phases/template-tab-v1/MILESTONE.md
.planning/phases/template-tab-v1/04-SUMMARY.md
</execution_context>

<context>
@.planning/phases/template-tab-v1/MILESTONE.md
@.planning/phases/template-tab-v1/04-SUMMARY.md
@ENVI/Core/Design/ENVITheme.swift
@ENVI/Core/Design/ENVITypography.swift
@ENVI/Core/Design/ENVISpacing.swift
@ENVI/Components/ENVIButton.swift
@ENVI/Components/ENVICard.swift
@ENVI/Components/ENVIChip.swift
@ENVI/Features/Library/TemplateCarousel.swift
@ENVI/Features/BrandKit/TemplateGalleryView.swift
@ENVI/Navigation/MainTabBarController.swift
@ENVI/Features/Templates/TemplateTabViewModel.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: TemplateTabView.swift — main tab shell</name>
  <files>ENVI/Features/Templates/TemplateTabView.swift</files>
  <action>
  Top-level SwiftUI view matching ENVI design system:
  
  Layout:
  - Navigation header: "TEMPLATES" title (spaceMonoBold), settings icon right
  - Scan progress banner (conditional): "Analyzing your 1,234 photos…" with progress bar, auto-hides at 100%
  - Horizontal scrolling category chips: All, For You, GRWM, Cooking, OOTD, Travel, Fitness, Product, etc. (use ENVIChip)
  - "For You" section (if category == All): 2-column grid of highest-fill templates
  - Category sections: horizontal scrolling rows per VideoTemplateCategory
  - Each row lazy-loads (LazyHStack)
  - Empty state: "Grant Photos access to see templates" CTA if PhotoLibraryManager.authorizationStatus != .authorized
  
  Uses `TemplateTabViewModel` via `@State private var viewModel = TemplateTabViewModel()` or environment injection. Triggers `viewModel.refresh()` on appear.
  
  Pull-to-refresh calls `viewModel.refresh()` (also triggers lazy rescan per Phase 1 MediaScanCoordinator).
  
  AVOID: loading full template previews eagerly (LazyVGrid/LazyHStack), hardcoding strings (use localized keys, matching ENVI pattern), breaking the floating tab bar (this view's content must fit above it).
  </action>
  <verify>Preview renders; simulator shows header, chips, empty state when Photos denied, loaded state with mock data</verify>
  <done>View compiles, uses ENVI design tokens, handles all states (loading, empty, error, loaded)</done>
</task>

<task type="auto">
  <name>Task 2: TemplateCardView.swift + TemplateCategoryRow.swift</name>
  <files>ENVI/Features/Templates/TemplateCardView.swift, ENVI/Features/Templates/TemplateCategoryRow.swift</files>
  <action>
  **TemplateCardView** — the core visual unit showing a PopulatedTemplate:
  - 2x2 thumbnail grid showing first 4 filled slots (use SDWebImage for async image loading)
  - If fewer than 4 slots: use aspectRatio-appropriate hero layout
  - Slot-fill indicator: "4/4 ✓" (green) or "2/4" (amber) in top-right pill
  - Template name (interSemiBold 14) + category label (spaceMono 10)
  - Duration badge (for video templates)
  - Tap → presents TemplatePreviewView (Task 3)
  - Context menu: "Use Template", "Find Similar Content", "Hide This Template"
  
  **TemplateCategoryRow** — horizontal LazyHStack of TemplateCardView with section title. Matches the pattern in existing `ENVI/Features/Library/TemplateCarousel.swift`.
  
  AVOID: synchronous image loading (use SDWebImage), rebuilding thumbnails on every scroll (memoize), oversized cards on large phones (cap maxWidth).
  </action>
  <verify>SwiftUI Preview with mock PopulatedTemplate renders correctly at iPhone SE, 15 Pro, 16 Pro Max widths</verify>
  <done>Cards render with user's real thumbnails, fill indicators correct, tap opens preview</done>
</task>

<task type="auto">
  <name>Task 3: TemplatePreviewView.swift — full-screen preview</name>
  <files>ENVI/Features/Templates/TemplatePreviewView.swift, ENVI/Features/Templates/TemplatePlayerView.swift</files>
  <action>
  Full-screen preview when a template card is tapped:
  
  **TemplatePreviewView** (container):
  - Top: close X, template name, duration
  - Center: TemplatePlayerView (Task 3b) — live playback with user's real media
  - Below player: horizontal strip of slot thumbnails, each tappable to swap
  - Bottom: "Export" primary button → triggers Phase 3 VM + Phase 6's export composer (or stub for now)
  - Slot swap: tap slot → BottomSheet with candidate alternates from FilledSlot.alternates + "Choose from library" option using PHPickerViewController
  
  **TemplatePlayerView**:
  - For photo templates: crossfade slideshow via SwiftUI + Animation
  - For video templates: AVPlayerViewController composing filled slot assets in order with Phase 3's transitions
  - For simplicity in Phase 5, use AVComposition to stitch clips; hook into ENVI's existing VideoEditService (ENVI/Core/Editing/VideoEditService.swift)
  
  AVOID: blocking UI during video composition (off-main Task), playing audio by default (respect silent switch), reallocating AVPlayer on every slot swap (mutate composition in place).
  </action>
  <verify>Preview works on simulator with 3 mock slots; slot swap updates player; export button triggers callback</verify>
  <done>Preview playable with user's real photos/videos, swap flow works, export triggers</done>
</task>

<task type="auto">
  <name>Task 4: TemplateOnboardingProgressView.swift + MainTabBarController integration</name>
  <files>ENVI/Features/Templates/TemplateOnboardingProgressView.swift, ENVI/Navigation/MainTabBarController.swift (modify), ENVI/Features/Auth/OnboardingPhotosAccessView.swift (modify)</files>
  <action>
  **TemplateOnboardingProgressView** — shown during onboarding after Photos permission granted:
  - "Analyzing your content to find templates that fit…"
  - Progress ring (ENVIProgressRing) bound to `MediaScanCoordinator.scanOnboardingBatch()` progress (last 500 assets)
  - Allow "Skip" → onboarding continues, full scan runs in background via BGProcessingTask
  - Shows thumbnail mosaic of 9 sample analyzed photos as they come in (keeps user engaged)
  
  **MainTabBarController modification** — add 6th tab slot:
  - New tab: "Templates" with system symbol "square.grid.2x2.fill"
  - Insert between existing Library and ChatExplore tabs (match ENVI's current tab order)
  - Wire to TemplateTabView
  
  **OnboardingPhotosAccessView modification** — after permission granted, navigate to TemplateOnboardingProgressView before completing onboarding.
  
  AVOID: blocking onboarding on scan completion (Skip must work), making the tab unreachable in onboarding skip path (lazy scan handles this), modifying the floating tab bar's pill design (just insert a new item).
  </action>
  <verify>Manual: full onboarding flow in simulator — permission granted → progress ring animates → Skip works → Template tab appears after onboarding</verify>
  <done>Onboarding integrates scan progress, new tab added, Skip path works, Template tab reachable from tab bar</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <what-built>Phase 5 complete — the Template tab is visible and functional. Users see templates populated with their own content, can preview them, swap slots, and export. Onboarding now runs the initial classification scan with a delightful progress UI.</what-built>
  <how-to-verify>
    1. Build + run on simulator with sample camera roll (import photos first via Photos app)
    2. Complete onboarding → confirm Analyzing screen shows progress → Skip or wait for completion
    3. Tap Template tab → confirm category rows render with real thumbnails from simulator's Photos
    4. Tap a template card → preview opens → tap a slot to swap → change applies → Export button visible
    5. Check: design matches ENVI aesthetic (dark mode, SpaceMono headers, Inter body, ENVI color palette)
  </how-to-verify>
  <resume-signal>Type "approved" to commit + push + proceed to Phase 6</resume-signal>
</task>

</tasks>

<verification>
- [ ] `xcodebuild build` succeeds
- [ ] UI tests cover main flows (tab load, preview open, slot swap)
- [ ] No new design tokens outside ENVITheme
- [ ] Phase 5 commit pushed
</verification>

<success_criteria>
- 7 new files: TemplateTabView, TemplateCardView, TemplateCategoryRow, TemplatePreviewView, TemplatePlayerView, TemplateOnboardingProgressView + MainTabBarController integration
- Template tab reachable from tab bar
- Preview plays templates with user's real media
- Onboarding runs scan with progress UI
- Phase committed and pushed
</success_criteria>

<output>
Create `.planning/phases/template-tab-v1/05-SUMMARY.md` with screenshots (if possible), file manifest, design decisions, and commit SHA.
</output>
