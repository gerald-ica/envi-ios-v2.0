# Phase 16 Plan 02: Profile/Settings Entry Points Summary

**Wired 6 previously-orphan Profile-adjacent modals (Agency, Teams, Commerce, Experiments, Security, Notifications) into ProfileView via 3 new router-driven groups.**

## Accomplishments
- Added 3 new Settings sub-groups in `ProfileView.settingsSection`:
  - **CREATOR BUSINESS** — Agency, Teams, Commerce
  - **ANALYTICS** — Experiments
  - **ACCOUNT** — Security, Notifications
- Each row taps through `router.present(.destination)` — no inline `.sheet(isPresented:)` bools introduced.
- Existing `SETTINGS` group (Account Settings, View Analytics) untouched; extracted into `baseSettingsGroup` for readability.
- 6 resolver arms filled in `AppDestinationResolver.AppDestinationSheetResolver` — each wrapped in a dedicated private sheet host (`AgencySheetHost`, `TeamsSheetHost`, `ExperimentsSheetHost`, `SecuritySheetHost`, `NotificationsSheetHost`) that owns its `@StateObject` VM, plus the simpler `MarketplaceView` which already owns its own VM.
- 8 new pin-tests, all passing.

## Files Created/Modified
- `ENVI/Features/Profile/ProfileView.swift` — 3 new router-driven groups + `SettingsEntryRow` model (file-scope).
- `ENVI/Navigation/AppDestinationResolver.swift` — 6 arms filled + 5 new private sheet hosts.
- `ENVITests/Phase16Plan02SettingsEntryPointsTests.swift` — new, 8 assertions.
- `project.yml` — registers the new test file in the ENVITests bundle.

## Decisions Made
- **Used existing enum case names** `.agency` / `.teams` etc. instead of the plan's referenced `.agencyDashboard` / `.teams` / etc. The enum inherited from Phase 15-01 only has `.agency`, `.teams`, `.commerce`, `.experiments`, `.security`, `.notifications` — adding parallel `*Dashboard` variants would double the id space without benefit. The destination-to-view mapping happens in the resolver, where the `Dashboard`-ness lives naturally.
- **Row-group styling**: reused the existing Settings card chrome (18pt corner radius, `ENVITheme.surfaceLow`, 1pt textLight-8% stroke) so the 3 new groups visually match the base Settings card. No new design primitives introduced.
- **Host ownership of VMs**: each sheet host uses `@StateObject` to own the VM for the sheet's lifetime. This matches the "each view owns its VM" precedent the plan calls out and avoids leaking VMs between sheet presentations.
- **SF Symbols**: `briefcase.fill`, `person.3.fill`, `bag.fill`, `flask.fill`, `lock.shield.fill`, `bell.fill` — matching the plan's suggestions exactly.

## Issues Encountered
- First build failed because `AgencyDashboardView`, `TeamMemberView`, `ExperimentListView`, `AuditLogView`, and `NotificationListView` all require `@ObservedObject viewModel` args. Solution: introduce one `*SheetHost` per view, each holding the VM via `@StateObject`. `MarketplaceView` already owns its own `@StateObject CommerceViewModel` so it plugs in directly.

## Verification
- `xcodebuild build` — BUILD SUCCEEDED
- `xcodebuild test` — **35 / 35 passing** (was 27 after 16-01 → now 27 + 8 = 35)

## Next Step
Ready for 16-03-PLAN.md (AIFeatures wiring into ChatExploreView — 7 views).
