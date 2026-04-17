# Phase 18: p3-dead-action-fixes — COMPLETE

**Status:** 3/3 plans shipped — 2026-04-17
**Milestone:** v1.2 Frontend Audit Fixes (Phase 5 of 6)

## Goal

Fix the 4 confirmed dead UI actions on already-reachable surfaces
identified by the Frontend Audit Wave 2. These were all buttons users
could tap today, on screens already wired into routing, that did
literally nothing (empty closure or TODO-only comment).

## Outcome

**4 dead actions now fire real mutations. Each is pinned by at least
one contract test.**

| # | Surface | Before | After | Repo / Store |
|---|---|---|---|---|
| 1 | `FeedDetailView:107` bookmark button | `Button(action: {})` | Optimistic flip → `ContentRepository.setBookmarked(contentID:bookmarked:)` → rollback + toast on throw | `ContentRepository` |
| 2 | `ContentLibrarySettingsView:247` YouTube CONNECT | `Button {} label: { Text("CONNECT") }` | `SocialOAuthManager.connect(platform: .youtube)` | `SocialOAuthManager` |
| 3 | `ContentLibrarySettingsView:247` X CONNECT | same no-op | `SocialOAuthManager.connect(platform: .x)` | same |
| 4 | `ContentLibrarySettingsView:247` LinkedIn CONNECT | same no-op | `SocialOAuthManager.connect(platform: .linkedin)` | same |
| 5 | `TemplateTabView:231` onDuplicate | `{ /* TODO: Find similar content */ }` | `Task { await viewModel.duplicate(populated) }` → `VideoTemplateRepository.duplicate(templateID:)` → prepend clone | `VideoTemplateRepository` |
| 6 | `TemplateTabView:232` onHide | `{ /* TODO: Hide template */ }` | `viewModel.hide(populated)` → persist `hiddenTemplateIDs` to UserDefaults | `UserDefaultsManager` |

(The audit counted Duplicate + Hide as one pair; rows 5 + 6 both pin
distinct handlers — the more honest count is 6 dead handlers, or 4
distinct buttons per the original plan title.)

## Plans Shipped

- **18-01** — Bookmark wiring. Added `setBookmarked(contentID:bookmarked:)`
  to `ContentRepository` + implementations (Mock: in-memory
  `Set<UUID>`; API: `PUT /content/:id/bookmark`). `FeedDetailView`
  got `@State isBookmarked` + `toggleBookmark()` with optimistic UI
  + 2-second rollback toast. 3 XCTests. See
  [18-01-SUMMARY.md](18-01-SUMMARY.md).
- **18-02** — CONNECT rows. Replaced three no-op buttons with the
  same `SocialOAuthManager.connect(platform:)` path
  `ConnectedAccountsViewModel` already uses. Added per-row
  `connectingPlatform: SocialPlatform?` + inline error surfacing.
  YouTube kept in scope (plan documented a skip-if-absent fallback
  but `SocialPlatform.youtube` already existed so no deferral). 4
  XCTests. See [18-02-SUMMARY.md](18-02-SUMMARY.md).
- **18-03** — Duplicate + Hide + phase roll-up. Added
  `duplicate(templateID:)` to `VideoTemplateRepository` + both
  conformers, `hiddenTemplateIDs: Set<String>` to
  `UserDefaultsManager`, `hide`/`unhideAll`/`duplicate` +
  `visibleTemplates` to `TemplateTabViewModel`. Wired both context-
  menu callbacks at both TemplateTabView call sites (For You grid +
  category row). 4 XCTests. See [18-03-SUMMARY.md](18-03-SUMMARY.md).

## Architectural Decisions (applied across all 3 plans)

- **Optimistic UI with rollback.** Used for the bookmark flow,
  where the user expects iOS-native latency. A blocking spinner or
  ghost-state flip would feel laggy against local-mock latency.
  Connect flows use a spinner label flip instead because the OAuth
  round-trip is genuinely long (web sheet + provider redirect).
- **Default-arg dependency injection, not VM extraction.** The dead-
  action fixes are surgical — we injected the repo /
  `SocialOAuthManager` / `UserDefaultsManager` via default-arg
  properties so production call-sites stay unchanged and tests get a
  clean seam. Creating 3 new ViewModels for these fixes would have
  been scope drift.
- **Hide is local-only; bookmarks and connects are server-synced.**
  Hide is a UX preference (per-device). Bookmarks and social
  connections are account state that must survive reinstall. The
  store matches the concern.
- **Subclass-based test spies, not protocol extraction.**
  `SocialOAuthManager` is intentionally non-final (Phase 08/09
  connector test harnesses already subclass it). Reusing the seam
  avoids a disruptive protocol extraction.

## Tests Added

- `FeedDetailBookmarkTests` — 3 tests
- `ContentLibrarySettingsConnectTests` — 4 tests
- `TemplateTabActionsTests` — 4 tests

Each suite pins the audit finding directly — a regression on any of
the 4 dead actions will fail an assertion, not silently re-ship.

Xcode test bundle grew **56 → 67 passing** (+11). Baseline was the
Phase 17 exit state.

## Commit Ledger

13 atomic commits across the 3 plans:

```
18-01: 49ce70f feat(18-01): add setBookmarked to ContentRepository + bookmark store to mock
18-01: 79cbe61 feat(18-01): wire FeedDetailView bookmark button with optimistic UI
18-01: 87c559c test(18-01): pin bookmark optimistic-update + rollback contract
18-01: 7a489d3 docs(18-01): plan summary

18-02: 41af783 feat(18-02): wire CONNECT rows in ContentLibrarySettingsView to SocialOAuthManager
18-02: f067269 test(18-02): pin connect-row state machine
18-02: c424588 docs(18-02): plan summary

18-03: de1544e feat(18-03): add duplicate + hide to TemplateTabViewModel + VideoTemplateRepository
18-03: b33bd77 feat(18-03): wire onDuplicate + onHide in TemplateTabView
18-03: d1ec45a test(18-03): pin duplicate + hide behavior
18-03: <pending> docs(18-03): plan summary

18:    <pending> docs(18): phase 18 complete — 4 dead actions fixed
```

## Verification

- Zero `Button(action: {})` or TODO-only closures remain in the 3
  files this phase touched (FeedDetailView, ContentLibrarySettingsView,
  TemplateTabView).
- `xcodebuild -scheme ENVI -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` → `** BUILD SUCCEEDED **`.
- `xcodebuild test` → **67 passed, 0 failed**.

## Deferred

- **Bookmark icon state doesn't propagate back to the parent feed
  grid.** When a user bookmarks from the detail sheet, the parent
  `ForYouGalleryViewModel` doesn't see the update. In practice the
  detail sheet is the only place the bookmark icon is visible today,
  so this doesn't visually regress. When the feed list adds its own
  bookmark indicator (plausible v1.3 surface), it can subscribe to
  a shared `@Published bookmarkedIDs: Set<UUID>` on a future
  `BookmarksViewModel`.
- **Duplicate clones are session-local on the Lynx path.** The
  `TemplateCatalogClient` actor deep-copies in memory since the
  server manifest is read-only (ETag-driven GET). If a "My
  Duplicated Templates" server-synced collection ships, the
  implementation spot is the one `duplicate(templateID:)` method.
- **No "show hidden templates" UI toggle yet.** `unhideAll()` is
  wired and pinned but no surface exposes it. Straightforward add
  when a user asks.

## Next Phase

**Phase 19 — p4-hygiene.** The last v1.2 phase. Cleans up the 3
remaining repo-in-view anti-pattern surfaces (SystemHealth,
SSOConfig, ContractManager), standardizes the remaining two
non-canonical repo providers (AdvancedAnalytics, Benchmark), deletes
dead VMs, and adds test coverage + the wordmark consolidation.
