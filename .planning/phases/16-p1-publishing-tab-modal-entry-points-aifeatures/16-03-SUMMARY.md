# Phase 16 Plan 03: AIFeatures Wiring Summary

**Surfaced 7 previously-orphan AIFeatures views via a new AI mode in ChatExploreView's mode switcher, backed by a 2-column LazyVGrid menu.**

## Accomplishments
- New `AIToolsMenuView` — 7-card LazyVGrid with icon, title, subtitle per tool. Each card taps through `router.present(.destination)`.
- `ExploreMode` enum extended with `.ai` as a peer of `.explore` / `.chat`. `ChatExploreView` switches on the new case and renders `AIToolsMenuView` with the same `.opacity + .offset` transition style as the other modes.
- Seven resolver arms filled (`.ideation`, `.aiVisualEditor`, `.captionGenerator`, `.hookLibrary`, `.scriptEditor`, `.styleTransfer`, `.imageGenerator`).
- Six new `*SheetHost` private structs — three over `AIWritingViewModel` (Caption, Hook, Script) and three over `AIVisualViewModel` (Visual Editor, Style Transfer, Image Generator). `IdeationDashboardView` owns its own VM so it plugs in directly.
- 5 new pin-tests in `AIToolsMenuTests.swift`.
- Premium gating inherited — `MainTabBarController` already applies `.requiresAura()` at the ChatExplore tab root, so AIToolsMenuView gets the aura gate for free.

## Files Created/Modified
- `ENVI/Features/ChatExplore/AIToolsMenuView.swift` — new (2-column grid + Tool catalog).
- `ENVI/Features/ChatExplore/ChatExploreView.swift` — `ExploreMode` grows `.ai` case; body switch handles three cases.
- `ENVI/Navigation/AppDestinationResolver.swift` — 7 arms + 6 new sheet hosts.
- `ENVITests/AIToolsMenuTests.swift` — new, 5 assertions.
- `project.yml` — registers the new test file.

## Decisions Made
- **Added `.ai` as a sibling mode** in the existing `.explore` ↔ `.chat` toggle rather than a separate toolbar button — matches "the 7 AI features should feel like a toolbelt, not a separate tab" from the plan. The mode-switcher already has the segmented-control UI; reusing it avoids inventing a new chrome element.
- **Grid over list**: 2-column LazyVGrid of cards. 7 tools → 4 rows (1 empty slot in the last row). Visually matches the "toolbelt" framing better than a vertical list, and cards afford subtitle copy that a list row would starve.
- **Card-level `router.present` per tap** — no nested navigation. Each tool opens as a sheet resolved by `AppDestinationSheetResolver`, consistent with the 16-02 pattern.
- **Shared VM classes re-instantiated per sheet**: `AIWritingViewModel` and `AIVisualViewModel` are shared across 3 views each, but each sheet host creates a fresh VM instance for the sheet's lifetime. Reusing a single VM across multiple simultaneous sheets would cause published-state collisions; separate instances keep each presentation cleanly scoped.
- **Icon choices follow the plan exactly**: `lightbulb.max.fill`, `text.bubble.fill`, `bolt.fill`, `doc.text.fill`, `wand.and.stars`, `paintbrush.fill`, `slider.horizontal.3`.
- **Tool ordering**: writing tools (Ideation, Caption, Hook, Script) first, then visual tools (Image, Style, Visual Editor). Reflects the most common creator workflow — ideate + write, then visualize.

## Issues Encountered
- None at build time; all views compile with the `*SheetHost` pattern. One caveat documented below.

## Caveats
- `AIWritingViewModel` and `AIVisualViewModel` appear to be shared VMs across three views each. Each sheet-host instance creates a separate VM, which means state from one tool (e.g. an Image prompt) will NOT persist into another tool's sheet (e.g. Style Transfer). This is intentional — the old inline-sheet pattern never shared VMs either — but worth flagging for a future consolidation (Phase 17/18) if shared state becomes desirable.

## Verification
- `xcodebuild build` — BUILD SUCCEEDED
- `xcodebuild test` — **40 / 40 passing** (35 → 40 with +5 new tests)

## Next Step
Ready for 16-04-PLAN.md (HomeFeed/Library tools menu for BrandKit, Campaigns, Collaboration, Community, Metadata, Repurposing, Search, Admin, Enterprise — 2 gated).
