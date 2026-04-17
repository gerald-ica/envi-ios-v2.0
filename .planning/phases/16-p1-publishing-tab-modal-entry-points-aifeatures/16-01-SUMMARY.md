# Phase 16 Plan 01: Publishing Tab Summary

**Promoted Publishing from a 2-file orphan to the 4th live tab backed by the full `ScheduleQueueView` + `SchedulingViewModel` stack.**

## Accomplishments
- `PublishingTabView` created — thin router-aware wrapper around `ScheduleQueueView`, hosts the tab's navigation stack and the `.sheet(item:)` / `.fullScreenCover(item:)` resolver attachments.
- `MainTabBarController` re-registered with 4 entries: `[ForYou, ChatExplore, Publishing, Profile]`. Publishing slots at index 2 so Profile stays rightmost.
- `ENVITabBar` widened from 164 → 210pt (pillWidth static) to accommodate a 4th icon at the same ~54pt per-slot rhythm. `paperplane.fill` picked as the Publishing glyph.
- Tab-bar width constraint in `MainTabBarController.setupTabBar()` now reads `ENVITabBar.pillWidth` instead of the old magic number.
- 3 resolver arms filled (`.schedulePost`, `.publishResults`, `.linkedInAuthorPicker`) — each wrapped in a dedicated private sheet host so the live `ScheduleQueueView` compose/reconciliation sheets keep working unchanged.
- 4 new tests pass in the Xcode test bundle.
- Simulator screenshot captured — see `./screenshots/16-01-four-tab-tab-bar.png`.

## Files Created/Modified
- `ENVI/Features/Publishing/PublishingTabView.swift` — new tab container.
- `ENVI/Navigation/MainTabBarController.swift` — 4-tab registration, width constraint uses `ENVITabBar.pillWidth`.
- `ENVI/Components/ENVITabBar.swift` — 4-icon layout, `pillWidth = 210`, `pillHeight = 64` statics.
- `ENVI/Navigation/AppDestination.swift` — added `.schedulePost`, `.publishResults`, `.linkedInAuthorPicker` (+ their `id` arms).
- `ENVI/Navigation/AppDestinationResolver.swift` — 3 new sheet hosts (`SchedulePostSheetHost`, `PublishResultsSheetHost`, `LinkedInAuthorPickerSheetHost`).
- `ENVITests/PublishingTabTests.swift` — new, 4 assertions.
- `project.yml` — `PublishingTabTests.swift` added to the ENVITests sources list.

## Decisions Made
- Publishing tab icon: `paperplane.fill` (17pt SF Symbol), non-persistent disc — matches the "action" visual weight of the ChatExplore logo instead of the persistent disc of the Profile avatar.
- Pill width: **210pt** (from 164) — documented as `ENVITabBar.pillWidth`. 4 equal-width stack slots of ~52.5pt preserve the existing 45pt active-disc hit target without visual clipping.
- Publishing placed at index 2 (before Profile) — matches iOS convention that identity/profile lives rightmost.
- `PublishResultsSheetHost` shows an explicit empty state when there is no completed/failed post yet, rather than fabricating a dummy `ScheduledPost` payload to feed into `PublishResultsView`.
- `LinkedInAuthorPickerSheetHost` wires a no-op `onSelect` — when the picker is reached via the generic router path (not a compose flow), selection is discarded. The compose-flow path that writes the selection back into a post is future work (Phase 17+).
- `PublishingTabView` does NOT call `.requiresAura()` — the Publishing tab is core product functionality (queue monitoring), not premium-gated like ChatExplore. Precedent: For You / Gallery also omits the aura gate.

## Issues Encountered
- None. Build + test pass first compile.

## Verification
- `xcodebuild build` — BUILD SUCCEEDED
- `xcodebuild test` — 27 / 27 passing (23 baseline from Phase 15 + 4 new)
- App installed + launched on `iPhone 17 Pro` simulator, PID 69080 alive after screenshot.
- Screenshot: `screenshots/16-01-four-tab-tab-bar.png` — 4-icon pill visible.

## Next Step
Ready for 16-02-PLAN.md (Profile/Settings entry points for Agency, Teams, Commerce, Experiments, Security, Notifications).
