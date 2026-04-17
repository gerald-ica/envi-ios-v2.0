# Phase 15 Plan 02: Router Integration Summary

**AppRouter threaded through MainTabBarController into 3 SwiftUI tab
roots; 4 inline `.sheet(isPresented:)` call sites migrated to
`router.present(...)` as the proof-of-pattern.**

## Accomplishments
- AppRouter (`.shared`) owned by `MainTabBarController` and injected
  into all 3 tab roots (ForYouGalleryContainerView, ChatExploreView,
  ProfileView) via `.environmentObject(router)`. Two-way sync between
  `router.selectedTab` and `MainTabBarController.currentIndex` via a
  Combine sink + the existing `customTabBar.onTabSelected` callback.
- `ENVI/Navigation/AppDestinationResolver.swift` created with
  `AppDestinationSheetResolver` + `AppDestinationFullScreenResolver`
  structs. 4 concrete arms wired: `.search` → `FeedSearchView`,
  `.contentCalendar` → `ContentCalendarSheetHost`, `.chatHistory` →
  `ChatHistorySheetHost`, `.contentLibrarySettings` →
  `ContentLibrarySettingsView`. Unhandled destinations fall through to
  `PlaceholderSheetView` with a Phase-16 TODO — no `#warning` noise.
- 4 inline `.sheet(isPresented:)` call sites migrated:
  - `ForYouGalleryContainerView` — search (`$showSearch` →
    `.search`) and calendar (`$showCalendar` → `.contentCalendar`).
  - `ChatExploreView` — chat history (`$showHistory` →
    `.chatHistory`) and content-library settings (`$showSettings` →
    `.contentLibrarySettings`).
  - Dead `@State` bool vars + private `CalendarSheet` /
    `ChatHistorySheet` structs deleted (logic moved into resolver
    hosts).
- 2 passing integration tests pin the published-state contract that
  `.sheet(item:)` and the MainTabBarController sink consume.
- Full build green; full `ENVITests` suite (8 router tests +
  ProfileViewModel + FeatureFlags suites) green.

## Files Created/Modified
- `ENVI/Navigation/MainTabBarController.swift` — router ownership +
  `.environmentObject` injection on each tab hosting controller +
  `bindRouter()` Combine sink for programmatic tab switching.
- `ENVI/Navigation/AppDestinationResolver.swift` — new.
- `ENVI/Features/HomeFeed/ForYouGallery/ForYouGalleryContainerView.swift`
  — dropped bool-state sheets + inline CalendarSheet; migrated to
  `router.present`. Preview injected with `AppRouter()`.
- `ENVI/Features/ChatExplore/ChatExploreView.swift` — dropped bool-
  state sheets + inline ChatHistorySheet; migrated to
  `router.present`. Preview injected.
- `ENVI/Features/Profile/ProfileView.swift` — `@EnvironmentObject
  AppRouter` added; router sheet/fullScreenCover modifiers attached.
  Pre-existing bool sheets (AccountManagement, Analytics) stay inline
  for Phase 16. Preview injected.
- `ENVITests/AppRouterIntegrationTests.swift` — new (2 tests).
- `project.yml` + `ENVI.xcodeproj/project.pbxproj` — test file
  registered and project regenerated.

## Decisions Made
- `AppRouter.shared` singleton used inside `MainTabBarController`
  rather than a fresh `AppRouter()` instance — keeps the same router
  reachable from `SceneDelegate`'s URL handler in Plan 15-03 without
  plumbing an extra reference into SceneDelegate.
- `ProfileView` keeps its existing bool-driven sheets for
  AccountManagement + Analytics this plan. They'll migrate in Phase 16
  when Profile sub-section modals (Notifications, Security, Billing,
  Education, Support, Subscription) come online. Migrating them now
  without those sub-section arms populated would be churn.
- `ChatHistorySheet` and `CalendarSheet` logic hoisted into the
  resolver file as private hosts, because the original structs were
  declared `private` inside their tab views and the resolver switch
  needs a call-site it can reach. Pure code movement, no behavior
  change.
- `Placeholder` arm deliberately avoids `#warning` — the Phase-16
  migration plan already tracks the TODO list; unconditional warnings
  would add noise to every build.

## Issues Encountered
- First build after the migration failed (`cannot find
  'AppDestinationSheetResolver' in scope`) because `xcodegen` hadn't
  been re-run after creating the new file. Resolved by running
  `xcodegen generate` — now part of the workflow for every new file
  in `ENVI/`.
- Simulator manual tap-driven verification of the 4 migrated sheets
  was blocked: `simctl` has no tap primitive and `idb` is not
  installed in this environment. Used the documented substitution
  (build + install + launch + verified-no-crash with a captured
  screenshot at `/tmp/envi-15-02.png`). Visual/functional verification
  of tap-through-to-sheet remains blocked by environment; static +
  unit-test coverage is the primary gate. Process PID 61741 observed
  alive in `launchctl list`; no crash or environmentObject-missing
  assertion in the simulator log tail.

## Next Step
Ready for 15-03-PLAN.md (deep-link hook: `enviapp://destination/X`
routes through AppRouter; OAuth `enviapp://oauth-callback/*` path
untouched).
