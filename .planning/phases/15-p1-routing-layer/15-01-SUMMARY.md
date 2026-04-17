# Phase 15 Plan 01: AppDestination + AppRouter Summary

**Central route registry + ObservableObject router shipped; no existing call sites touched — 6 XCTests pin behavior.**

## Accomplishments
- `AppDestination` enum with 35 cases covering 14 orphan modal groups
  (Admin, Agency, BrandKit, Campaigns + campaignDetail(id:), Collaboration,
  Commerce, Community, Enterprise, Experiments, Metadata, Publishing,
  Repurposing, Search, Teams), 7 AIFeatures views, 6 Profile sub-sections
  (Notifications, Security, Billing, Education, Support, Subscription),
  5 existing live destinations (chatHistory, contentLibrarySettings,
  exportSheet, mediaPicker, phPicker, contentCalendar), and full-screen
  contentEditor(contentID:). Pure value type — no SwiftUI import.
- `AppRouter` `@MainActor` `ObservableObject` with `sheet`/`fullScreen`/
  `pushStack`/`selectedTab` published state + `present(_:preferring:)`/
  `dismiss()`/`replace(_:)`/`selectTab(_:)` API. Sheet-over-sheet deadlock
  handled via dismiss + re-present on next main-actor tick. Static
  `shared` singleton provided for SceneDelegate but SwiftUI usage is
  `@EnvironmentObject`-first.
- 6 passing XCTests pin `present` routing (sheet vs fullScreen), `dismiss`
  clearing, `replace` async swap, `selectTab` clearing, and destination
  identity stability.

## Files Created/Modified
- `ENVI/Navigation/AppDestination.swift` - new (35 cases)
- `ENVI/Navigation/AppRouter.swift` - new
- `ENVITests/AppRouterTests.swift` - new (6 tests)
- `project.yml` - registered AppRouterTests.swift in ENVITests target
- `ENVI.xcodeproj/project.pbxproj` - regenerated via `xcodegen`

## Decisions Made
- `@MainActor` on AppRouter, since SwiftUI observation must run on main.
- Static `shared` singleton kept alongside instance pattern — singleton
  unblocks SceneDelegate URL handling (no SwiftUI environment there);
  instance + `@EnvironmentObject` is the preferred path inside SwiftUI.
- Destination IDs computed as `caseName` for simple cases and
  `caseName:payload` for payload-bearing cases so `.sheet(item:)` can
  safely key off them.
- Sheet-over-sheet quirk mitigated via `Task { @MainActor in … }` — the
  canonical SwiftUI workaround, not a real race condition.
- `pushStack` declared but unused in this plan — Phase 16 will wire
  NavigationStack.
- `contentEditor(contentID:)` is the only case defaulting to
  `.fullScreenCover`; everything else prefers `.sheet`.

## Issues Encountered
None. Build green on first try, tests green on first run.

## Next Step
Ready for 15-02-PLAN.md (wire router into 3 live tabs via
`.environmentObject` + migrate existing `.sheet(isPresented:)` call
sites opportunistically).
