# Phase 17: p2-mock-to-repo-swaps — COMPLETE

**Status:** 3/3 plans shipped — 2026-04-17
**Milestone:** v1.2 Frontend Audit Fixes (Phase 4 of 6)

## Goal

Convert 5 views that hold hardcoded mock data in `@State` defaults into
repo-driven ViewModels. Lowest-friction wins — the repos already exist.

## Outcome

**5 previously-mocked views now repo-driven. 3 repositories no longer
ORPHAN.**

| View | Before | After | Repo |
|---|---|---|---|
| `GrowthDashboardView` | `GrowthMetric.mockList` / `ViralLoop.mockList` / `ShareableAsset.mockList` in `@State` | `@StateObject GrowthViewModel` via `loadDashboard()` | `GrowthRepository` |
| `ReferralView` | `ReferralProgram.mock` / `ReferralInvite.mockList` in `@State` | `@StateObject GrowthViewModel` via `loadReferrals()` | `GrowthRepository` |
| `SupportCenterView` | `SupportTicket.mockList` / `FAQArticle.mockList` in `@State` | `@StateObject SupportViewModel` via `loadSupportCenter()` | `SupportRepository` |
| `TutorialListView` | `Tutorial.mock` / `LearningPath.mock` in `@State` | `@StateObject EducationViewModel` via `loadTutorials()` | `EducationRepository` |
| `AchievementsView` | `AchievementBadge.mock` in `@State` | `@StateObject EducationViewModel` via `loadAchievements()` | `EducationRepository` |

## Plans Shipped

- **17-01** — `GrowthViewModel` + bind `GrowthRepository` →
  `GrowthDashboardView`, `ReferralView`. `async let` parallel load of
  metrics/loops/assets and program/invites. `sendInvite(email:)` action
  flows through `GrowthRepository.sendInvite(...)`. 3 XCTests. See
  [17-01-SUMMARY.md](17-01-SUMMARY.md).
- **17-02** — `SupportViewModel` + bind `SupportRepository` →
  `SupportCenterView`. `async let` parallel load of tickets/FAQs/
  health score. `submitTicket(...)` flows through
  `SupportRepository.createTicket(...)` so the repo sees writes. 3
  XCTests. Recovered from a partial state mid-plan (see
  [17-02-SUMMARY.md](17-02-SUMMARY.md)).
- **17-03** — `EducationViewModel` + bind `EducationRepository` →
  `TutorialListView`, `AchievementsView`. `loadTutorials()` parallel
  fetch of tutorials + learning paths; `loadAchievements()` for the
  badges grid. Coaching tips protocol method intentionally left wired
  only in the test double (no live consumer yet). 4 XCTests. See
  [17-03-SUMMARY.md](17-03-SUMMARY.md).

## Architectural Decisions (applied across all 3 plans)

- **VM class is non-`@MainActor`; methods are.** Matches the
  `CampaignViewModel` / `BrandKitViewModel` precedent. Required
  because `@StateObject var vm = XYZViewModel()` in a view needs to
  synchronously construct the class from a default-arg init, which
  a MainActor-isolated class can't do.
- **No silent mock fallback on error.** Views render `ENVIErrorBanner`
  with the VM's `errorMessage` rather than re-populating with mock
  data. This was the audit's core concern with the old
  mock-in-`@State` pattern — errors masked by fallback data.
- **`#if DEBUG` `preview()` helper.** Each VM exposes a static
  `preview()` factory that pre-populates from the model-level
  `.mock` / `.mockList` statics. SwiftUI previews use this; it's
  wrapped in `#if DEBUG` so it cannot reach production builds.
- **Dev env still sees mocks via the provider, not via VM fallback.**
  `XRepositoryProvider.shared.repository` returns the `MockX`
  implementation in `.dev` and the `APIX` implementation in
  `.staging` / `.prod`. The mock path is a valid data source; the
  VM treats it the same as the API path.

## Tests Added

- `GrowthViewModelTests` — 3 tests
- `SupportViewModelTests` — 3 tests
- `EducationViewModelTests` — 4 tests

Each suite pins: (1) default state is empty (no silent mock
preload), (2) repo-populated load flows through the VM correctly,
(3) repo errors surface via `errorMessage` and do NOT fall back
to mocks.

Xcode test bundle grew 46 -> 56 passing tests.

## Commit Ledger

12 atomic commits across the 3 plans:

```
17-01: bcde19d feat(17-01): add GrowthViewModel + register GrowthRepository provider
17-01: 64f3107 refactor(17-01): VM-drive GrowthDashboardView + ReferralView, remove mock @State
17-01: 5758f84 docs(17-01): plan summary

17-02: 0783f93 feat(17-02): add SupportViewModel + register SupportRepository provider
17-02: df7bedf refactor(17-02): VM-drive SupportCenterView         [recovery]
17-02: 8f76bf9 docs(17-02): plan summary                            [recovery]

17-03: 6270027 feat(17-03): add EducationViewModel + register EducationRepository provider
17-03: 1e49b75 refactor(17-03): VM-drive TutorialListView + AchievementsView
17-03: b178850 docs(17-03): plan summary

17:    <pending> docs(17): phase 17 complete — 5 views unmocked, 3 repos wired
```

Note: 17-02's view refactor and summary landed in a recovery session
after a prior executor timed out between the feat commit and the
refactor commit. No prior commits were rewritten.

## Verification

- grep for production mock usage in ENVI/Features/ returns only doc
  comments and `#if DEBUG` `preview()` helpers. Zero production matches.
- `xcodebuild -scheme ENVI -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` succeeds clean.
- `xcodebuild test` -> **56 passed, 0 failed**.

## Deferred

- `EducationRepository.fetchCoachingTips(context:)` is not yet wired
  to a view consumer. The protocol method exists in `EducationRepository`
  and is exercised by the test double, but no live surface renders
  coaching tips today. A later phase can pull it into the VM when a
  consumer ships.
- Support "reply to ticket" and "mark FAQ helpful" actions
  (`replyToTicket` / `markHelpful` on the repository) are reachable
  via the repo but not yet wired to UI affordances in
  `SupportCenterView`. The current view shows tickets and FAQs but
  does not present reply or helpful buttons. Future phase if needed.

## Next Phase

**Phase 18 — p3-dead-action-fixes.** Fix the 4 confirmed dead UI
actions on already-reachable surfaces (FeedDetailView bookmark,
ContentLibrarySettings CONNECT rows, TemplateTab duplicate/hide).
