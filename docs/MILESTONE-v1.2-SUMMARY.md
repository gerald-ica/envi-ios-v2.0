---
title: ENVI Milestone v1.2 — Implementation Complete
date: 2026-04-17
project: envi-ios-v2
type: milestone-summary
status: implementation-complete
---

# ENVI Milestone v1.2 — Implementation Complete

**Frontend Audit Fixes shipped in one session. 6 phases, 21 plans, 68 commits, 201 passing tests.**

---

## At a Glance

| Metric | Start (2026-04-17 morning) | End (2026-04-17 evening) |
|---|---|---|
| Live tabs | 3 | **4** (Publishing added) |
| Reachable modal surfaces | 4 wired + 60 orphan | **27 wired** + ~60 surfaced via resolver |
| Views rendering hardcoded mocks | 6 | **0** (production paths) |
| Dead UI actions | 4 confirmed | **0** (all wired) |
| Analytics data source | Mock (flag off) | **Firestore live** (flag on + SPM linked) |
| ViewModel tests | 0 | **50+ across every live-tab VM** |
| Total passing tests | ~30 (pre-existing) | **201** |
| `NavigationCoordinator.swift` | Protocols only | Full `AppDestination` + `AppRouter` + deep-link |

---

## The 6 Phases

### Phase 14 — P0: Analytics Unmock + Profile Bind *(9 commits)*
Linked `FirebaseFirestore` + `FirebaseRemoteConfig` SPM products (resolved v1.1 STATE blocker #7). Flipped `FeatureFlags.connectorsInsightsLive` default `false → true` and pinned all 3 Analytics providers with 7 XCTests. Bound `ProfileViewModel` to the real auth user via `AuthManager+CurrentUser` bridge; `User.mock` confined to Preview/Debug. Phase 13's "per-platform unmock" commit now actually serves live data.

### Phase 15 — P1: Routing Layer *(12 commits)*
Built the missing abstraction: `AppDestination` enum (39 cases, `Identifiable`/`Hashable`), `AppRouter` `ObservableObject` (sheet/fullScreen/push/tab state), `AppDestinationResolver` struct, `DeepLinkRouter` URL parser. Router threaded through `MainTabBarController` via `.environmentObject`. 4 existing `.sheet(isPresented: $bool)` call sites migrated as proof-of-pattern. Deep-link hook respects the existing `enviapp://oauth-callback` path untouched. 23 pin tests.

### Phase 16 — P1: Publishing Tab + 23 Modal Entry Points + AIFeatures *(18 commits)*
Publishing promoted from 2-file fragment to **4th tab** in `MainTabBarController`. `ENVITabBar` widened 164→210pt for 4 icons. 6 Profile/Settings entry points (Agency, Teams, Commerce, Experiments, Security, Notifications). 7 AIFeatures surfaced via new `AIToolsMenuView` in ChatExplore (Ideation, AIVisualEditor, CaptionGenerator, HookLibrary, ScriptEditor, StyleTransfer, ImageGenerator). `LibraryToolsMenu` with 9 content-adjacent modals (2 admin-gated behind `FeatureFlags.showAdminTools`). Total: **23 previously-orphaned surfaces now user-reachable.**

### Phase 17 — P2: Mock-to-Repo Swaps *(8 commits, 1 recovery)*
Three ViewModels created + three ORPHAN repositories wired: `GrowthViewModel` (drives `GrowthDashboardView` + `ReferralView`), `SupportViewModel` (drives `SupportCenterView`), `EducationViewModel` (drives `TutorialListView` + `AchievementsView`). All 5 views now fetch from repos instead of `@State` mocks; mocks retained only in Preview/Debug helpers. 10 pin tests.

### Phase 18 — P3: Dead Action Fixes *(12 commits)*
Four confirmed dead actions wired:
- `FeedDetailView:107` bookmark — optimistic UI + rollback via `ContentRepository.setBookmarked`
- `ContentLibrarySettingsView:247` CONNECT rows — YouTube + X + LinkedIn all route through `SocialOAuthManager` (YouTube retained in scope since `SocialPlatform.youtube` already existed)
- `TemplateTabView:231-232` `onDuplicate` / `onHide` — repo call + UserDefaults-backed hide list

11 pin tests covering optimistic update, rollback, connect state machine, and persistence across VM instances.

### Phase 19 — P4: Hygiene *(18 commits)*
Closed out the milestone:
- 3 views refactored off the repo-in-view anti-pattern (`SystemHealthView`, `SSOConfigView`, `ContractManagerView`) — each got a real VM.
- `Repositories` facade added over Analytics/Advanced/Benchmark providers (additive, zero ABI break). `BenchmarkViewModel` gained dev-env mock fallback.
- `EnhancedChatViewModel` mock threads properly `#if DEBUG`-gated.
- `LibraryDAMViewModel` documented as intentional (4 views bind to it — audit was wrong about it being orphan).
- **23 pre-existing test files un-rotted** and re-enabled in Xcode bundle; 7 deferred with documented FIXMEs.
- Baseline VM test coverage added for `EnhancedChatViewModel`, `ForYouGalleryViewModel`, `SchedulingViewModel`; `ProfileViewModel` coverage extended.
- `ENVIWordmark` canonical component unifies the brand wordmark across Splash + SignIn.

---

## What the Audit Predicted vs What Shipped

| Audit Finding (2026-04-17 morning) | Shipped (2026-04-17 evening) |
|---|---|
| `NavigationCoordinator.swift` is a skeleton | Full `AppDestination` enum + `AppRouter` + `DeepLinkRouter` |
| `MainTabBarController` exposes only 3 tabs | 4 tabs with Publishing as 4th |
| Phase 13 analytics silently disabled by default | Flag default flipped + Firestore SPM linked |
| 14 of 18 modal groups unrouted | All 14 modal groups reachable through resolver |
| 7 AIFeatures orphaned | Surfaced via `AIToolsMenuView` in ChatExplore |
| 5 views mock-locked in production paths | All 5 repo-driven; mocks Preview/Debug only |
| `ProfileViewModel` uses `User.mock` | Bound to real auth user with loading/error states |
| 4 confirmed dead actions | All 4 wired with pinned tests |
| 3 views violating repo-in-view anti-pattern | All 3 refactored to VMs |
| 0 ViewModel tests | ~50 tests across every live-tab VM |

**Every P0 through P4 item from the audit's prioritized fix list was addressed.**

---

## Plan-vs-Reality Divergences (Honest Record)

Three places where the executors chose differently from the plan text — all documented in per-plan SUMMARY files and retained here for the milestone record:

1. **14-03 bind target**: audit said "bind `AccountRepository` to `ProfileViewModel`." Reality: `AccountRepository` is session/export/consent oriented — no current-user fetch. Shipped `AuthManager+CurrentUser` bridge instead. Caveat: only identity fields (uid, email, displayName, photoURL) map; dateOfBirth/location/stats still need a future Firestore profile-fetch repo.

2. **16-02/04 enum naming**: plans referenced `.agencyDashboard`, `.adminDashboard`, `.enterpriseDashboard`. Phase 15's enum used shorter names (`.agency`, `.admin`, `.enterprise`). Used existing names to avoid duplicating id space.

3. **19-02/03 pattern choices**: 19-02 plan asked for a forced rename to `RepositoryProvider.shared.X` — existing pattern was already canonical, so shipped an additive `Repositories` facade instead (same goal, no ABI break). 19-03 plan asked to delete `LibraryDAMViewModel` — 4 views bind to it, so retained with clarifying header.

---

## Deferred to v1.3

- **7 test files still deferred** with FIXMEs: Swift 6 `@MainActor` concurrency drift (SocialOAuthManagerTests), device-lane Vision/espresso dependencies (VisionAnalysisEngine, VisionPerformance, EmbeddingIndex, SimilarityEngine), simulator timing flake (TemplateTabPerformanceTests), and one possible real regression — `DimensionReducerTests` UMAP silhouette dropped from 0.5 to 0.075 (worth triage).
- **Partial Profile data**: `AuthManager+CurrentUser` maps only identity fields. Full profile (DOB, location, stats, rich connected platforms) needs a dedicated Firestore fetch path.
- **`ProfileViewModel.connectPlatform` / `.disconnectPlatform`**: test coverage blocked by `SocialOAuthManager.shared` singleton (no swap seam). Either introduce an injectable OAuth interface or accept the coverage gap.
- **v1.1 human-gated blockers**: 6 of the 7 remain (secret rotation, redirect URIs, FB/LinkedIn App Review, TikTok tester allowlist, oauth-state-signing-key). Blocker #7 (Firestore SPM link) was resolved in Phase 14-01.
- **ProfileView's `AccountManagement` + `Analytics` sheets**: left on `.sheet(isPresented: $bool)` pattern per 15-02/16-02 plan scope. Opportunistic migration whenever those surfaces next change.

---

## Commit Summary

**68 implementation commits** in this session, milestone v1.2. Range: `cf8aa6d..8726f2e`.

Plan-level commit discipline held: each task = one commit; each plan = one `feat`/`refactor` + one `test` + one `docs` summary commit. Phase roll-ups + milestone marker add ~8 more docs commits on top.

---

## What's Next

1. **Human verification**: walk the simulator, tap through the 4-tab bar, exercise a few of the newly-routed modal groups, confirm real analytics data renders in Profile → Analytics (requires a test account with connected platforms).
2. **CI verification**: run the full Xcode test suite in CI to confirm the 201/201 number holds outside the local dev environment.
3. **Archive milestone**: `/gsd:complete-milestone` when verification is done. Moves the v1.2 plans to `.planning/milestones/v1.2-ROADMAP.md` and clears STATE for v1.3.
4. **v1.3 scoping**: primary candidates are (a) the 7 deferred test files, (b) full profile fetch, (c) the remaining v1.1 human-gated ops blockers, (d) the DimensionReducer UMAP regression triage.

---

## Source Artifacts

- Audit report: `[[ENVI Frontend Audit - 2026-04-17]]`
- Simulator screenshots: `[[Claude Files/ENVI Audit Screenshots 2026-04-17/]]`
- 4-tab bar evidence: `.planning/phases/16-p1-publishing-tab-modal-entry-points-aifeatures/screenshots/16-01-four-tab-tab-bar.png`
- Per-phase SUMMARY.md files: `.planning/phases/1{4,5,6,7,8,9}-*/SUMMARY.md`
- Per-plan SUMMARY.md files: `.planning/phases/*/*-SUMMARY.md` (~21 files)
- Updated ROADMAP: `.planning/ROADMAP.md`
- Updated STATE: `.planning/STATE.md`
