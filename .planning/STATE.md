# ENVI GSD State

## Current Position

Milestone: **v1.2 Frontend Audit Fixes**
Phase: **17 of 19** complete, ready to plan Phase 18
Plan: Not started
Status: Phase 17 complete; ready to plan Phase 18 (p3-dead-action-fixes)
Last activity: 2026-04-17 — Phase 17 complete (3/3 plans shipped): 5 previously-mocked views (GrowthDashboard, Referral, SupportCenter, TutorialList, Achievements) now repo-driven via Growth/Support/Education ViewModels; 3 repos no longer ORPHAN
Progress: ▓▓▓▓░░░░░░ ~67% (4 of 6 phases complete)

### v1.1 status (carried forward)

v1.1 Real Social Connectors — implementation complete (Phases 6–13, 2026-04-16), awaiting verification + 7 human-gated blockers (secret rotation, redirect URIs, FB/LinkedIn App Review, Firestore SPM link). Phase 14 of v1.2 resolves blocker #7 (Firestore SPM link). Other blockers remain ops-side.

### Remaining work before non-local deploy

**Human-gated blockers (hard blockers for staging deploy):**
1. **Rotate all 11 provider secrets** per `docs/ops/secret-rotation-checklist.md` (2026-04-16 plaintext exposure incident)
2. **Register 6 sandbox redirect URIs** per `docs/ops/06-06-sandbox-redirect-checklist.md`
3. **Provision `oauth-state-signing-key`** in Secret Manager (Phase 7)
4. **TikTok Sandbox tester allowlist** — add ENVI team members before integration test
5. **FB App Review** — `pages_manage_posts` scope; `FeatureFlags.canConnectFacebook` stays `false` until approved
6. **LinkedIn MDP approval** — org scopes locked until email approval arrives (1-5 business days)
7. ~~**Link FirebaseFirestore SPM product** to ENVI target — Phase 13 Firestore-backed repos are `#if canImport` gated~~ **RESOLVED 2026-04-17** (Phase 14-01: `FirebaseFirestore` + `FirebaseRemoteConfig` added to `Package.swift` + `project.yml`; build verified on iPhone 17 Pro)

**Verification commands (run in order):**
```bash
cd functions && npm install && npm run build && npm test
cd .. && xcodebuild -scheme ENVI -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
xcodebuild test -scheme ENVI -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
firebase emulators:start --only functions,firestore
firebase deploy --only functions,firestore:rules,firestore:indexes
```

## Accumulated Context

### v1.0 decisions (historical, still load-bearing)

- Backend truth path: Firebase Auth + Data Connect (see `docs/architecture/ADR-001-backend-truth-path.md`).
- Env model: `dev`, `staging`, `prod` via `AppEnvironment` enum (`ENVI/Core/Config/AppEnvironment.swift`).
- Bundle ID (staging): `com.weareinformal.envi.staging`.
- Auth: Firebase Auth with email + Apple Sign-In + Google Sign-In landed in Phase 2.
- Mock-mode gate pattern: each service has `useMock*: Bool` static toggle (see `SocialOAuthManager.useMockOAuth`). Retain this pattern for previews/tests, disable for prod.
- Repository pattern: Protocol → Mock → API → Provider (see Architecture wiki).
- SPM-only deps — no CocoaPods. Current deps: SDWebImage, Lottie, RevenueCat, GoogleSignIn, Firebase (Auth, Analytics, Crashlytics, Core).
- iOS 26.0+ deployment target, Xcode 26.0+, Swift 5 language mode.

### v1.1 decisions (new)

- **OAuth architecture:** server-side broker via Firebase Cloud Functions. Client secrets never ship in the iOS binary. Matches existing mocked code shape (`oauth/{platform}/connect` endpoints already expected).
- **Secret storage:** Google Secret Manager, bound to Cloud Functions service account via IAM.
- **Token storage:** Firestore `users/{uid}/connections/{provider}` with Cloud KMS envelope encryption for token fields.
- **iOS OAuth UX:** `ASWebAuthenticationSession` with `prefersEphemeralWebBrowserSession = false` (so sign-in state persists across connects). Custom URL scheme `enviapp://oauth-callback/{provider}` for callback; Universal Links deferred to v1.2.
- **Dependencies to add in Phase 6:** Firebase Functions SDK server-side (new `/functions` dir, TypeScript, Node 20). No new iOS SPM deps expected — `ASWebAuthenticationSession` is AuthenticationServices framework.
- **Sandbox↔prod:** separate Firebase projects (TBD names) + separate provider app registrations where possible (TikTok Sandbox is already separate; others use one app with dev/prod URIs).

### Blockers / Concerns

- **SECURITY:** All 8 provider secrets shared in plaintext in the planning conversation on 2026-04-16. **Must rotate** every secret in each provider console before Phase 7 ships. Phase 6-02 deliverable = rotation script + first rotation.
- **TikTok sandbox constraints:** only whitelisted testers can auth. Need to add testers to sandbox before Phase 8 integration test.
- **Meta App IDs:** 3 distinct App IDs allocated (parent `1649869446444171`, FB `1233228574968466`, Threads standalone `1604969460421980`, IG `1811522229543951`). Unclear if consolidation is possible — Phase 10 research item.
- **X API tier:** current Basic tier has 3 posts/15min/user rate limit. May force Pro tier upgrade during Phase 9 or early Phase 12 rollout.
- **LinkedIn Posts API migration:** UGC Posts API deprecated 2023, need to confirm Posts API is the supported surface for the grants we hold.

### Roadmap Evolution

- 2026-04-06: Milestone v1.0 Foundation shipped (Phases 1-5), OAuth scaffolding mocked.
- 2026-04-16: Milestone v1.1 Real Social Connectors created, 8 phases (Phases 6-13). Focus: replace mocks with real broker + 6 provider integrations + insights read-path.
- 2026-04-16: Phase 7 OAuth broker infrastructure shipped. `functions/src/oauth/` — adapter interface + registry + start/callback/refresh/disconnect/status handlers. iOS: `SocialOAuthManager.useMockOAuth` removed, replaced with `FeatureFlags.connectorsUseMockOAuth` (DEBUG default: true). `ProviderOAuthAdapter` interface locked — Phase 8+ wires concrete adapters.
- 2026-04-17: Milestone v1.2 Frontend Audit Fixes created, 6 phases (Phases 14-19). Driven by parallel-agent frontend audit report at `Claude Files/ENVI Frontend Audit - 2026-04-17.md` (Obsidian vault). Focus: 60 orphan views, unrouted modals, Phase 13 analytics silently mocked, dead actions on reachable surfaces.
- 2026-04-17: Phase 14 complete — analytics live, Profile bound to real user. FirebaseFirestore + FirebaseRemoteConfig linked via SPM (resolves v1.1 blocker #7). `connectorsInsightsLive` default flipped to `true` with 7 XCTests pinning provider behavior. `ProfileViewModel` hydrates from `AuthManager.currentUser()` (new bridge extension); `User.mock` confined to Preview/Debug paths with 2 new XCTests.
- 2026-04-17: Phase 15 complete — routing layer shipped. `AppDestination` enum (35 cases) + `AppRouter` ObservableObject (published sheet/fullScreen/pushStack/selectedTab with two-way `MainTabBarController` sync) + `AppDestinationResolver` struct with 4 wired arms (Phase 16 fills remainder). Four inline `.sheet(isPresented:)` call sites migrated from bool state to `router.present(...)` in ForYouGalleryContainerView and ChatExploreView. `DeepLinkRouter` parses `enviapp://destination/{caseName}[?id=…]` URLs through a one-line-change registry; `PendingDeepLinkStore` replays deep links that arrive pre-Splash. `AppDelegate.application(_:open:)` patched — OAuth callback path byte-for-byte preserved. TelemetryManager gained `deepLinkRouted` + `deepLinkMalformed` events. 14 new XCTests (6 AppRouter + 2 integration + 6 DeepLinkRouter) bring the Xcode test bundle to 23 passing.
- 2026-04-17: Phase 16 complete — 23 orphan surfaces now routable via AppRouter. 16-01: Publishing promoted to the 4th tab (`PublishingTabView` hosts `ScheduleQueueView`, ENVITabBar widened 164→210pt). 16-02: 6 new Profile/Settings rows (Agency, Teams, Commerce, Experiments, Security, Notifications) route via `router.present`. 16-03: `AIToolsMenuView` (2-col grid) added as a third `.ai` mode in ChatExploreView's mode-switcher, surfacing 7 AIFeatures views (Ideation + Caption/Hook/Script over AIWritingViewModel + Image/Style/Visual over AIVisualViewModel). 16-04: `LibraryToolsMenu` (3 sections, 7 visible + 2 admin-gated tools — BrandKit, Metadata, Repurposing, Campaigns, Collaboration, Community, Search + Admin, Enterprise); `FeatureFlags.showAdminTools` defaults false. AppDestination grew from 35→39 cases (schedulePost, publishResults, linkedInAuthorPicker, libraryTools). 23 new pin tests (Xcode bundle 23→46 passing). 18 atomic commits across the 4 plans.
- 2026-04-17: Phase 17 complete — 5 previously-mocked views (GrowthDashboard, Referral, SupportCenter, TutorialList, Achievements) now repo-driven via 3 new ViewModels (GrowthViewModel / SupportViewModel / EducationViewModel); 3 repos no longer ORPHAN (Growth, Support, Education). 17-01: `GrowthViewModel` loads metrics + viral loops + shareable assets via `async let` + referral program + invites; `sendInvite(email:)` action flows through `GrowthRepository.sendInvite(...)` updating state on success. 17-02: `SupportViewModel` loads tickets + FAQs + health score via `async let`; `submitTicket(...)` flows through `SupportRepository.createTicket(...)` so the repo sees writes. 17-03: `EducationViewModel` loads tutorials + learning paths + achievements; coaching tips protocol method left wired only in the test double (no live consumer yet). House pattern fixed: class is non-`@MainActor`, methods are; `@Published` state + repo-injected init + `#if DEBUG` `preview()` helper for SwiftUI Previews; no silent mock fallback on error — `errorMessage` surfaces and views render `ENVIErrorBanner`. 10 new XCTests across the 3 VMs (Xcode bundle 46→56 passing). 12 atomic commits across the 3 plans (17-02 recovered from a partial state — feat 0783f93 had landed pre-recovery; view refactor + summary landed in recovery session).

## Session Continuity

Last session: 2026-04-17
Stopped at: Phase 17 complete (all 3 plans shipped). Ready to plan Phase 18 (p3-dead-action-fixes).
Resume file: None
