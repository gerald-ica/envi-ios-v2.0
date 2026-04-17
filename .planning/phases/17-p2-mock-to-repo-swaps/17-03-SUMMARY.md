# Phase 17 Plan 03: Education VM Summary

**Tutorial list and achievements grid now flow through `EducationViewModel`
+ `EducationRepository` instead of hardcoded `@State` mocks.**

## Accomplishments

- Created `EducationViewModel`
  (ENVI/Features/Profile/Education/EducationViewModel.swift) following
  the house pattern established in 17-01's `GrowthViewModel` and 17-02's
  `SupportViewModel`: `final class ObservableObject`, `@Published`
  state (`tutorials`, `learningPaths`, `achievements`, `isLoading`,
  `errorMessage`), repo-injected init (defaults to
  `EducationRepositoryProvider.shared.repository`), `@MainActor`
  `loadTutorials()` loading tutorials + learning paths in parallel via
  `async let`, and `loadAchievements()` for the badges grid.
- Refactored `TutorialListView` and `AchievementsView` to consume the
  VM via `@StateObject` and `.task { await viewModel.load…() }`. Both
  views render `ENVILoadingState` on initial load and
  `ENVIErrorBanner` on failure — **no silent mock fallback on error**.
- Added `EducationViewModelTests` with 4 passing cases pinning default
  empty state, `loadTutorials` repo-populated load, `loadAchievements`
  repo-populated load, and error surfacing. Full suite now 56/56.
- `EducationRepository` is no longer ORPHAN — `EducationViewModel` is
  the first consumer. `EducationRepositoryProvider` was already
  registered in the repository file.

## Files Created/Modified

- `ENVI/Features/Profile/Education/EducationViewModel.swift` (new)
- `ENVI/Features/Profile/Education/TutorialListView.swift` (refactored)
- `ENVI/Features/Profile/Education/AchievementsView.swift` (refactored)
- `ENVITests/EducationViewModelTests.swift` (new)
- `ENVI.xcodeproj/project.pbxproj` (4 file refs added)

## Decisions Made

- **Class is not `@MainActor`**, methods are. Same rationale as 17-01
  and 17-02 — required for `@StateObject var vm = EducationViewModel()`
  in a view to synchronously construct the class from a default-arg init.
- **No silent mock fallback on error.** Mirrors the 17-01 / 17-02
  decision. Errors now surface via `errorMessage`.
- **`fetchCoachingTips(context:)` intentionally not wired to the VM yet.**
  No live view consumes coaching tips today; adding the state now would
  be speculative. The protocol method is exercised in the test double so
  it stays in scope for a future consumer.
- **Preview helper** `EducationViewModel.preview()` is wrapped in
  `#if DEBUG` so mocks can hydrate SwiftUI previews without reaching
  production code paths.

## Commit Summary

The plan called for 5 commits (feat / refactor / test / docs /
phase roll-up). Landed as 4 (first bundled the VM and its tests to
match the atomic pattern used by 17-01 and 17-02):

- `feat(17-03): add EducationViewModel + register EducationRepository provider`
  (bundled tests with VM)
- `refactor(17-03): VM-drive TutorialListView + AchievementsView`
- `docs(17-03): plan summary` (this file)
- `docs(17): phase 17 complete — 5 views unmocked, 3 repos wired`
  (phase roll-up, separate commit)

## Next Step

Phase 17 complete. Ready for **Phase 18** (p3-dead-action-fixes).
