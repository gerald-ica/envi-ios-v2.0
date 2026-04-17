# Phase 17 Plan 01: Growth VM Summary

**Growth dashboard and referral program now flow through `GrowthViewModel` +
`GrowthRepository` instead of hardcoded `@State` mocks.**

## Accomplishments

- Created `GrowthViewModel` (ENVI/Features/Modals/Growth/GrowthViewModel.swift)
  following the house pattern: `final class ObservableObject`, `@Published`
  state, repo-injected init (defaults to
  `GrowthRepositoryProvider.shared.repository`), `@MainActor` async methods
  for `loadDashboard()`, `loadReferrals()`, and `sendInvite(email:)`.
- Refactored `GrowthDashboardView` and `ReferralView` to consume the VM via
  `@StateObject` and `.task { await viewModel.load…() }`. Views render
  `ENVILoadingState` on initial load and `ENVIErrorBanner` on failure —
  **no silent mock fallback on error**.
- Added `GrowthViewModelTests` with 3 passing cases pinning default empty
  state, repo-populated load, and error surfacing. Full suite now 49/49.
- `GrowthRepository` is no longer ORPHAN — `GrowthViewModel` is the first
  consumer. `GrowthRepositoryProvider` was already registered.

## Files Created/Modified

- `ENVI/Features/Modals/Growth/GrowthViewModel.swift` (new)
- `ENVI/Features/Modals/Growth/GrowthDashboardView.swift` (refactored)
- `ENVI/Features/Modals/Growth/ReferralView.swift` (refactored)
- `ENVITests/GrowthViewModelTests.swift` (new)
- `ENVI.xcodeproj/project.pbxproj` (4 file refs added)

## Decisions Made

- **Class is not `@MainActor`**; methods are. Matches `CampaignViewModel` /
  `BrandKitViewModel`. Required because `@StateObject var vm =
  GrowthViewModel()` in a view cannot initialize a MainActor-isolated class
  synchronously from the default-arg init.
- **No dev-env mock fallback on error.** CampaignViewModel falls back to
  `.mockList` in dev on error; this plan was explicit that we do NOT want
  that because silent fallback is what the audit flagged. In dev the
  `MockGrowthRepository` already provides data on the happy path; errors
  will now surface rather than mask.
- **Preview helper** `GrowthViewModel.preview()` is wrapped in
  `#if DEBUG` so mock data can hydrate Previews without ever reaching
  production code paths.

## Commit Summary

The plan called for 4 commits (feat/refactor/test/docs). Landed as 3:
- `feat(17-01): add GrowthViewModel + register GrowthRepository provider`
  (bundled tests with VM to keep the VM+tests atomic)
- `refactor(17-01): VM-drive GrowthDashboardView + ReferralView, remove mock @State`
- `docs(17-01): plan summary` (this file)

## Next Step

Ready for **17-02-PLAN.md** (SupportViewModel + bind SupportRepository →
SupportCenterView).
