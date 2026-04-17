# Phase 16: Publishing Tab + Modal Entry Points + AIFeatures Summary

**23 orphan surfaces now routable via AppRouter. Frontend reachability gap closed.**

## Plan-by-plan

### 16-01 — Publishing 4th tab (3 surfaces wired via router + 1 tab promotion)
- `PublishingTabView` created — hosts `ScheduleQueueView` as primary surface, attaches `.sheet(item: $router.sheet)`.
- `MainTabBarController` re-registered with 4 tabs: `[ForYou, ChatExplore, Publishing, Profile]` (Profile stays rightmost).
- `ENVITabBar` widened 164 → 210pt (new `pillWidth` static); `paperplane.fill` chosen as the tab glyph.
- 3 resolver arms filled: `.schedulePost`, `.publishResults`, `.linkedInAuthorPicker` (each via a private sheet host).
- 4 pin tests passing.

### 16-02 — Profile/Settings entry points (6 surfaces)
- 3 new router-driven sub-groups in `ProfileView.settingsSection`: Creator Business (Agency/Teams/Commerce), Analytics (Experiments), Account (Security/Notifications).
- 6 resolver arms filled (`.agency`, `.teams`, `.commerce`, `.experiments`, `.security`, `.notifications`) — 5 per-view sheet hosts for VM-hungry views + direct wrapping for `MarketplaceView`.
- New `SettingsEntryRow` helper model at file scope.
- 8 pin tests passing.

### 16-03 — AIFeatures into ChatExplore (7 surfaces)
- `AIToolsMenuView` created — 2-column grid with 7 cards (icon + title + subtitle per tool).
- `ExploreMode` extended with `.ai` — `ChatExploreView` gains a third mode in its mode-switcher with the same transition style as `.explore`/`.chat`.
- 7 resolver arms filled: `.ideation` (owns its VM) + 6 `*SheetHost` structs grouped by shared VM (3 over `AIWritingViewModel`, 3 over `AIVisualViewModel`).
- Premium gating inherited from the tab's existing `.requiresAura()`.
- 5 pin tests passing.

### 16-04 — Library Tools Menu (9 surfaces, 2 gated)
- `LibraryToolsMenu` — sectioned (Content / Campaigns & Teams / Advanced) grid-of-cards, matching 16-03's visual language.
- `LibraryView.toolsFAB` stacked above the existing upload FAB — fires `router.present(.libraryTools)`.
- `FeatureFlags.showAdminTools: Bool = false` added; `visibleSections(showAdminTools:)` filters Admin + Enterprise out by default.
- 9 resolver arms filled: `.libraryTools`, `.brandKit`, `.campaigns`, `.collaboration`, `.community`, `.metadata`, `.repurposing`, `.admin`, `.enterprise`.
- 6 pin tests passing.

## Combined Test Coverage

| Step | Test count |
|---|---|
| Baseline (end of Phase 15) | 23 |
| After 16-01 | 27 (+4) |
| After 16-02 | 35 (+8) |
| After 16-03 | 40 (+5) |
| After 16-04 | **46 (+6)** |

## Net Orphan Surfaces Wired (23 target — met)

| Plan | Surfaces | Notes |
|---|---:|---|
| 16-01 | 1 tab + 3 modals | Publishing tab promoted + 3 publishing sheets |
| 16-02 | 6 modals | Agency, Teams, Commerce, Experiments, Security, Notifications |
| 16-03 | 7 modals | Ideation, Caption, Hook, Script, Image, Style, Visual Editor |
| 16-04 | 9 modals | BrandKit, Campaigns, Collaboration, Community, Metadata, Repurposing, Search, Admin (gated), Enterprise (gated) |
| **Total** | **23 modal surfaces + 1 tab promotion** | Phase-16 audit target reached |

## AppDestination growth

35 cases (end of Phase 15) → **39 cases** after Phase 16.
Four new: `.schedulePost`, `.publishResults`, `.linkedInAuthorPicker`, `.libraryTools`. Existing cases (`.agency`, `.teams`, `.admin`, `.enterprise` etc.) now all have resolver arms.

## Pattern notes for future phases
- **Sheet host pattern** now canonical for any view that needs a fresh `@StateObject` VM per presentation — `AgencySheetHost`, `TeamsSheetHost`, `CaptionGeneratorSheetHost`, etc. Phase 17+ should reuse this shape.
- **Admin gating** established via a simple bool on `FeatureFlags` and a declarative `adminGatedDestinations: Set` on the menu. When the role system lands (Phase 17+?), swap the flag check for a role-based predicate without touching the menu shape.
- Each router-present call writes to the shared `AppRouter.shared` singleton (via `@EnvironmentObject`); the sheet is materialized by whichever currently-active tab root has the `.sheet(item: $router.sheet)` attachment. All 4 tab roots now attach the resolver, so any destination is reachable from any tab.

## Simulator Screenshot
`./screenshots/16-01-four-tab-tab-bar.png` — 4-icon tab bar verified on iPhone 17 Pro.

## Next Step
Ready for Phase 17 (p2-mock-to-repo-swaps). Growth / Referral / Support / Tutorial / Achievements views still hold hardcoded mocks despite matching repos existing.
