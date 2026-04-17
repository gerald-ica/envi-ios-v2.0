# Phase 16 Plan 04: Library Tools Menu Summary

**Closed the remaining 9 orphan content-adjacent modal groups via a single LibraryToolsMenu reachable from LibraryView, with Admin + Enterprise hidden behind a FeatureFlags gate.**

## Accomplishments
- `LibraryToolsMenu` created — sectioned 2-column grid (Content / Campaigns & Teams / Advanced) with 7 visible-by-default tools and 2 admin-gated tools.
- `FeatureFlags.showAdminTools: Bool = false` added — documented in the same comment style as `connectorsInsightsLive`. Admin + Enterprise rows hidden from the menu unless the flag is flipped true.
- `LibraryView` grew a `toolsFAB` (wrench SF Symbol, 44pt) stacked above the existing `uploadFAB`. Taps fire `router.present(.libraryTools)`.
- New `.libraryTools` AppDestination case.
- 9 resolver arms filled — `.libraryTools` (the menu itself) + `.brandKit`, `.campaigns`, `.collaboration`, `.community`, `.metadata`, `.repurposing`, `.admin`, `.enterprise`. Six per-view sheet hosts cover the ones that need a `@StateObject` VM; Admin + Enterprise views own their repo wiring internally so they wrap directly in `NavigationStack`.
- 6 new pin-tests in `LibraryToolsMenuTests.swift`, all passing.

## Files Created/Modified
- `ENVI/Features/HomeFeed/Library/LibraryToolsMenu.swift` — new menu view + static catalog.
- `ENVI/Features/HomeFeed/Library/LibraryView.swift` — injects `@EnvironmentObject AppRouter`, stacks a secondary `toolsFAB` above `uploadFAB`.
- `ENVI/Core/Config/FeatureFlags.swift` — `showAdminTools` flag added.
- `ENVI/Navigation/AppDestination.swift` — `.libraryTools` case + id arm.
- `ENVI/Navigation/AppDestinationResolver.swift` — 9 arms + 6 new sheet hosts (BrandKit/Campaigns/Collaboration/Community/Metadata/Repurposing).
- `ENVITests/LibraryToolsMenuTests.swift` — new, 6 assertions.
- `project.yml` — registers the new test file.
- `.planning/ROADMAP.md` — all 4 Phase 16 plan checkboxes ticked; progress row updated to `4/4 | Complete | 2026-04-17`.
- `.planning/STATE.md` — current position updated to Phase 16 complete + Roadmap Evolution entry.
- `.planning/phases/16-p1-publishing-tab-modal-entry-points-aifeatures/SUMMARY.md` — phase-level roll-up.

## Decisions Made
- **Used existing AppDestination cases** `.admin` / `.enterprise` instead of the plan's proposed `.adminDashboard` / `.enterpriseDashboard`. Same reasoning as 16-02 — the enum already has these cases from Phase 15-01's Wave 1 enumeration; adding parallel `*Dashboard` duplicates would double the id space without benefit.
- **Search entry kept in the menu catalog** under "Advanced" even though it's already wired at the feed level (Phase 15-02) — the Library surface is a natural second entry point.
- **Floating secondary FAB** for the menu entry rather than modifying `MainAppHeader`'s signature. Adding an `onTools` callback to `MainAppHeader` would have rippled into every caller (LibraryView + ForYouGalleryContainerView). A standalone FAB is strictly additive.
- **Admin gating lives in `LibraryToolsMenu.visibleSections(showAdminTools:)`** — a static helper — so the unit test can assert visibility rules without instantiating the view. `adminGatedDestinations` is the single source of truth for which destinations are gated.
- **Admin + Enterprise views don't need `@StateObject` hosts** because `SystemHealthView` and `ContractManagerView` own their repo access directly (the existing repo-in-view pattern the roadmap's Phase 19-01 item tracks for eventual cleanup). Wrapping them in `NavigationStack` at the resolver is sufficient.

## Issues Encountered
- None; build succeeded first compile after the 6 SheetHost structs were added for the VM-hungry views.

## Verification
- `xcodebuild build` — BUILD SUCCEEDED
- `xcodebuild test` — **46 / 46 passing** (40 → 46 with +6 new tests)
- All 4 Phase 16 ROADMAP plan checkboxes ticked; STATE + ROADMAP reflect phase completion.

## Next Step
Ready for Phase 17 (p2-mock-to-repo-swaps). Growth / Referral / Support / Tutorial / Achievements views still hold hardcoded mocks despite matching repos existing.
