# Phase 17 Plan 02: Support VM Summary

**Support Center now flows through `SupportViewModel` + `SupportRepository`
instead of hardcoded `@State` mocks.**

## Accomplishments

- Created `SupportViewModel` (ENVI/Features/Profile/Support/SupportViewModel.swift)
  following the house pattern established in 17-01's `GrowthViewModel`:
  `final class ObservableObject`, `@Published` state (`tickets`, `faqs`,
  `healthScore`, `isLoading`, `errorMessage`), repo-injected init
  (defaults to `SupportRepositoryProvider.shared.repository`),
  `@MainActor` `loadSupportCenter()` loading tickets + FAQs +
  health score in parallel via `async let`, plus a `submitTicket(...)`
  action that flows through `repository.createTicket(...)`.
- Refactored `SupportCenterView` to consume the VM via `@StateObject` and
  `.task { await viewModel.loadSupportCenter() }`. View renders
  `ENVILoadingState` on initial load and `ENVIErrorBanner` on failure —
  **no silent mock fallback on error**. New-ticket submit button now
  flows through `viewModel.submitTicket(...)` so the repository sees
  writes rather than the old in-view `tickets.insert(ticket, at: 0)`.
- Added `SupportViewModelTests` with 3 passing cases pinning default
  empty state, repo-populated load, and error surfacing.
- `SupportRepository` is no longer ORPHAN — `SupportViewModel` is the
  first consumer. `SupportRepositoryProvider` was already registered
  in the repository file.

## Files Created/Modified

- `ENVI/Features/Profile/Support/SupportViewModel.swift` (new, shipped in 17-02 feat commit)
- `ENVI/Features/Profile/Support/SupportCenterView.swift` (refactored)
- `ENVITests/SupportViewModelTests.swift` (new, shipped alongside the VM)
- `ENVI.xcodeproj/project.pbxproj` (file refs added in the feat commit)

## Decisions Made

- **Class is not `@MainActor`**, methods are. Same rationale as
  `GrowthViewModel` — `@StateObject var vm = SupportViewModel()` in
  a view can't synchronously construct a MainActor-isolated class from
  the default-arg init. Matches `CampaignViewModel` / `BrandKitViewModel`
  / `GrowthViewModel`.
- **No silent mock fallback on error.** Mirrors the 17-01 decision.
  Errors now surface via `errorMessage` rather than being masked by
  a fall-back to `.mockList`.
- **Preview helper** `SupportViewModel.preview()` is wrapped in
  `#if DEBUG` so mock data can hydrate SwiftUI previews without ever
  reaching production code paths.
- **Submit-ticket flow** now waits for the repository's created
  `SupportTicket` rather than constructing one client-side and
  inserting it. The VM handles the insert on success. This keeps the
  real API response (id/createdAt/status) as the source of truth when
  the staging/prod `APISupportRepository` is in use.

## Commit Summary

The plan called for 4 commits. Landed as 3 (the first bundled the VM
and its tests to keep the VM + tests atomic, matching 17-01):

- `feat(17-02): add SupportViewModel + register SupportRepository provider`
  (0783f93 — shipped pre-recovery, bundled tests)
- `refactor(17-02): VM-drive SupportCenterView` (recovery commit)
- `docs(17-02): plan summary` (this file)

## Recovery Note

This plan's `feat(...)` commit landed in a prior session (0783f93) but
the view refactor, test commit, and summary were never produced before
the executor timed out. The recovery session picked up from the clean
tree state and:

1. Verified `SupportViewModel.swift` + `SupportViewModelTests.swift` as
   shipped in the feat commit.
2. Refactored `SupportCenterView.swift` to consume the VM (separate
   `refactor(...)` commit).
3. Wrote this summary (`docs(...)` commit).

No files shipped pre-recovery were modified.

## Next Step

Ready for **17-03-PLAN.md** (EducationViewModel + bind EducationRepository
→ TutorialListView, AchievementsView).
