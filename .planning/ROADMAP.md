# Roadmap: ENVI iOS v2.0

## Milestones

- ✅ **v1.0 Foundation** — Phases 1–5 (shipped 2026-04-06)
- 🚧 **v1.1 Real Social Connectors** — Phases 6–13 (implementation complete, awaiting verification blockers)
- 🚧 **v1.2 Frontend Audit Fixes** — Phases 14–19 (in progress, created 2026-04-17)

---

## Phases

<details>
<summary>✅ v1.0 Foundation (Phases 1–5) — SHIPPED 2026-04-06</summary>

### Phase 1 — Repo truth + delivery rails (Weeks 1-2)

**Goal:** Align repository, CI, and environment model with actual iOS product.

- Removed/quarantined `.github/workflows/google.yml`.
- Added iOS CI workflow (`xcodebuild`/simulator tests).
- Defined envs: `dev`, `staging`, `prod` with clear config source.
- Created ADR deciding backend path (Firebase Auth + Data Connect + optional API facade).

**Exit criteria — met.**

### Phase 2 — Real identity + API foundation (Weeks 2-4)

**Goal:** Replace auth/network stubs with production-capable baseline.

- Integrated Firebase Auth (email + Apple Sign-In + Google).
- Replaced `APIClient` stub with typed client and auth token path.
- Added `firebase.json` + Data Connect deploy/readme path.
- Locked down public Data Connect operations meant only for seed/demo.

**Exit criteria — met.**

### Phase 3 — Media ingest + content backbone (Weeks 4-7)

**Goal:** Turn camera-roll concept into real content pipeline.

- Implemented PHAsset ingestion observers and upload queue.
- Implemented server-side media record creation + processing status.
- Wired `ContentPieceAssembler` to real endpoints.
- Replaced Library + Explore data sources with backend-backed content.

**Exit criteria — met.**

### Phase 4 — AI + publishing minimum loop (Weeks 7-10)

**Goal:** Real creator value loop with Oracle path and first social integration.

- Integrated Oracle endpoint contract for recommendations/chat.
- Added first social OAuth (mock-mode for all 6 platforms) with token-lifecycle scaffolding.
- Implemented publish/status reconciliation scaffolding for one channel.
- Fed analytics dashboard with real metric payloads.

**Exit criteria — met (note: OAuth shipped as mocked scaffolding; real provider wiring is v1.1).**

### Phase 5 — Editor, billing, and launch quality (Weeks 10-14)

**Goal:** Production readiness and monetization.

- Replaced key editor placeholders with AVFoundation-based real operations (crop, filter, speed, rotate).
- RevenueCat entitlement gates tied to backend/API behavior.
- Added crash reporting + product analytics events + release notes discipline.
- TestFlight pipeline and release checklist.

**Exit criteria — met.**

</details>

---

### 🚧 v1.1 Real Social Connectors (In Progress)

**Milestone Goal:** Replace mocked social OAuth and publishing with real, production-capable connectors for all 6 platforms (TikTok Sandbox → Prod, X/Twitter, Facebook, Instagram, Threads, LinkedIn). Every flow brokered through Firebase Cloud Functions with secrets in Google Secret Manager. End-to-end = iOS "Connect" tap → OAuth via `ASWebAuthenticationSession` → server-side code exchange → encrypted token storage → publish dispatcher → status reconciliation → insights read-path.

**Credentials pre-allocated (stored in Secret Manager, NOT in repo):**

| Provider | App/Client ID | Secret Reference |
|---|---|---|
| TikTok (ENVI-SANDBOX) | `sbaw4c49dgx7odxlai` | `tiktok-sandbox-client-secret` |
| X (Twitter) OAuth 1.0a | Consumer Key `TTIBKlrthEByJjzk5p8X8NM6b` | `x-oauth1-consumer-secret`, `x-oauth1-access-token-secret`, `x-bearer-token` |
| X (Twitter) OAuth 2.0 | Client ID `WC12UFNnY05NU3BDNEtKdHdQUDE6MTpjaQ` | `x-oauth2-client-secret` |
| Meta (Facebook) | App ID `1233228574968466` | `meta-app-secret` |
| Meta (Envi Threads app group) | App ID `1649869446444171` | `envi-threads-app-secret` |
| Threads | App ID `1604969460421980` | `threads-app-secret` |
| Instagram (Graph) | App ID `1811522229543951` | `instagram-app-secret` + `instagram-client-token` |
| LinkedIn | Client ID `86geh6d7rzwu11` | `linkedin-primary-client-secret` |

> **SECURITY NOTE (blocker before ship):** The credentials above were shared in plaintext in the planning conversation on 2026-04-16. Rotate every secret in each provider's dev console **before** going live. The Phase 6 deliverable includes a written rotation checklist and first rotation.

**Bundle ID in scope:** `com.weareinformal.envi.staging` (sandbox) → `com.weareinformal.envi` (prod, TBD).

#### Phase 6: connector-foundation

**Goal:** Build the Firebase backend shell and iOS OAuth session abstraction that every connector depends on.

**Depends on:** v1.0 complete
**Research:** Likely — Firebase Functions 2nd-gen deploy patterns, Google Secret Manager IAM, `ASWebAuthenticationSession` prefersEphemeralWebBrowserSession trade-offs.
**Research topics:**
- Firebase Functions 2nd gen vs 1st gen (Node 20 runtime, secret binding, concurrency)
- Secret Manager IAM binding from Functions service account
- Firestore security rules for per-user token documents
- iOS `ASWebAuthenticationSession` deep-link callback vs Universal Link (sandbox providers often require explicit redirect URIs; Universal Links easier for prod)
- URL scheme collision strategy (`enviapp://oauth-callback/{provider}`)
- Sandbox↔prod Firebase project separation

**Plans:**
- [ ] 06-01: Firebase Cloud Functions project bootstrap (`/functions` TypeScript, 2nd gen, Node 20)
- [ ] 06-02: Secret Manager provisioning script + seed rotation of all 8 provider secrets
- [ ] 06-03: Firestore schema for `users/{uid}/connections/{provider}` (encrypted token fields, scopes, expiry, revokedAt)
- [ ] 06-04: iOS `OAuthSession` protocol + `ASWebAuthenticationSession` adapter + URL scheme registration (Info.plist `CFBundleURLTypes`)
- [ ] 06-05: Env plumbing — `ENVI_CONNECTOR_ENV={sandbox|prod}`, xcconfig + Cloud Functions runtime config
- [ ] 06-06: Bundle ID registered as allowed redirect in all 6 provider dev consoles (sandbox)
- [ ] 06-07: Security: token field encryption via Firebase App Check + Cloud KMS envelope encryption

#### Phase 7: oauth-broker-service

**Goal:** Generic, reusable OAuth 2.0 broker Cloud Function that every connector plugs into. Replace `SocialOAuthManager.useMockOAuth = true` with real API calls.

**Depends on:** Phase 6
**Research:** Likely — PKCE code_verifier storage (Redis/Firestore/signed cookie), state CSRF defenses, refresh-token rotation best practices, revocation propagation.
**Research topics:**
- PKCE S256 verifier round-trip through `ASWebAuthenticationSession`
- State/nonce storage TTL in Firestore vs Memorystore
- Refresh-token rotation (detect reuse → force reauth)
- Revocation webhook endpoints per provider
- Rate-limit backoff + jitter

**Plans:**
- [ ] 07-01: `POST /oauth/:provider/start` → returns authorization URL + state token
- [ ] 07-02: `GET /oauth/:provider/callback` → code exchange, encrypt+store tokens, redirect to app via custom scheme
- [ ] 07-03: `POST /oauth/:provider/refresh` → refresh-token exchange + rotation detection
- [ ] 07-04: `POST /oauth/:provider/disconnect` → provider revocation + Firestore delete
- [ ] 07-05: `GET /oauth/:provider/status` → connection state + scopes
- [ ] 07-06: Replace `SocialOAuthManager.useMockOAuth` gate — keep mock mode behind FeatureFlag for UI/preview tests
- [ ] 07-07: ENVITests for OAuth round-trip against local Functions emulator

#### Phase 8: tiktok-sandbox-connector

**Goal:** First real end-to-end connector. Wire the ENVI-SANDBOX credentials, implement Login Kit + Content Posting API, prove the Phase 6+7 architecture works.

**Depends on:** Phase 7
**Research:** Likely — TikTok Login Kit v2 scope format, Content Posting API chunked upload, sandbox user allowlist constraints (only approved testers can auth), Display API for video list.
**Research topics:**
- TikTok scopes: `user.info.basic`, `video.list`, `video.publish`, `video.upload`
- Sandbox: max 10 test users, sandbox-only endpoints
- Content Posting API: `init` → chunked `upload` → `publish` flow
- Sandbox → Prod promotion (app review requirements)
- Video format constraints (mp4, H.264, max 500MB, 15s–10min)

**Plans:**
- [ ] 08-01: TikTok `TikTokConnector` iOS adapter + scopes
- [ ] 08-02: Cloud Function provider plugin for TikTok (extends generic broker)
- [ ] 08-03: Content Posting API: video upload (init + chunked + publish)
- [ ] 08-04: User profile + video list read (Display API)
- [ ] 08-05: Sandbox tester allowlist UX — clear error when non-whitelisted user attempts auth
- [ ] 08-06: Integration test against TikTok sandbox tier (publish a test video)
- [ ] 08-07: Sandbox→Prod promotion checklist doc

#### Phase 9: x-twitter-connector

**Goal:** X (Twitter) OAuth 2.0 PKCE writes + v1.1 chunked media upload (still required for video).

**Depends on:** Phase 7
**Research:** Likely — X API v2 writes (tweets, media attachment), v1.1 media/upload chunked endpoint (INIT/APPEND/FINALIZE/STATUS), bearer token vs user-context tokens, scope strings (`tweet.read`, `tweet.write`, `users.read`, `media.write`, `offline.access`).
**Research topics:**
- OAuth 2.0 Client ID `WC12UFNnY05NU3BDNEtKdHdQUDE6MTpjaQ` vs legacy OAuth 1.0a consumer creds — use 2.0 for user auth, 1.0a retained only if we need elevated v1.1 endpoints
- Media upload chunked flow for video (segment_index, category=tweet_video)
- Reply/quote-tweet endpoints
- Rate limits (Basic tier: 3 posts/15min/user — may force usage upgrade)

**Plans:**
- [ ] 09-01: `XTwitterConnector` iOS adapter + OAuth 2.0 scopes
- [ ] 09-02: Cloud Function provider plugin for X
- [ ] 09-03: Tweet create (text) → v2 POST /2/tweets
- [ ] 09-04: Media upload (chunked INIT/APPEND/FINALIZE via v1.1 + attach via v2)
- [ ] 09-05: Account lookup + followers count for `PlatformConnection`
- [ ] 09-06: Rate-limit aware retry

#### Phase 10: meta-family-connector

**Goal:** Facebook + Instagram + Threads under a shared Meta Graph broker. Three distinct App IDs, shared code path, per-platform publish adapters.

**Depends on:** Phase 7
**Research:** Likely — Threads API is very new (2024/2025), IG Graph requires Business/Creator account linked to a FB Page, FB Login for Business required for pages.
**Research topics:**
- App IDs: Envi-Threads-parent `1649869446444171` (Graph), Meta FB `1233228574968466`, Threads-standalone `1604969460421980`, IG `1811522229543951`
- Which App ID drives which Graph endpoint (clarify in research phase — may be able to consolidate)
- IG Content Publishing API: single-image, carousel, reel
- Threads API posting + media
- FB Page publish via `/page-id/feed` + `/page-id/videos`
- FB Login for Business (required as of 2024 for Pages)
- Page/Account selection UX (user may manage multiple Pages)
- Long-lived access tokens + refresh cadence (60-day IG/FB)

**Plans:**
- [ ] 10-01: Meta Graph broker plugin (shared token exchange for all 3 Meta apps)
- [ ] 10-02: FB Login for Business + Page selection UI
- [ ] 10-03: `FacebookConnector` iOS adapter + Page feed/video publish
- [ ] 10-04: IG Business/Creator account detection + error path when user has personal-only account
- [ ] 10-05: `InstagramConnector` iOS adapter + Content Publishing (single, carousel, reel)
- [ ] 10-06: `ThreadsConnector` iOS adapter + Threads publish
- [ ] 10-07: Long-lived token refresh cron (60-day)
- [ ] 10-08: Consolidate or document the 3 App ID separation (research-driven decision)

#### Phase 11: linkedin-connector

**Goal:** LinkedIn OAuth 2.0 + Posts API (successor to UGC Posts, moved 2023), member + company page contexts.

**Depends on:** Phase 7
**Research:** Likely — UGC Posts API → Posts API migration, 3-step image/video asset upload (register → upload → attach).
**Research topics:**
- Scopes: `r_liteprofile`, `w_member_social`, `r_organization_social`, `w_organization_social`
- Posts API endpoints
- Image/video asset upload 3-step flow
- Company page admin scope flow

**Plans:**
- [ ] 11-01: `LinkedInConnector` iOS adapter + scopes
- [ ] 11-02: Cloud Function provider plugin for LinkedIn
- [ ] 11-03: Posts API text + image + video publish
- [ ] 11-04: Member vs Organization author URN handling
- [ ] 11-05: Company page selector UI

#### Phase 12: publish-lifecycle-hardening

**Goal:** Turn per-connector publish calls into a real multi-platform dispatcher. Replace `PublishingManager` backend stubs. Add retry/DLQ, refresh-token cron, revocation handling, polished Connected Accounts UI.

**Depends on:** Phases 8, 9, 10, 11
**Research:** Unlikely — internal patterns + minor Cloud Scheduler docs.
**Research topics:** Cloud Scheduler + Pub/Sub trigger pattern for token refresh cron.

**Plans:**
- [ ] 12-01: Cloud Function `publish/jobs` dispatcher (fan-out to N providers)
- [ ] 12-02: Firestore job state machine (queued → processing → posted/failed) with per-provider status
- [ ] 12-03: Retry with exponential backoff + DLQ for permanent failures
- [ ] 12-04: Cloud Scheduler cron: refresh tokens 24h before expiry
- [ ] 12-05: Provider webhook receivers (where supported) for status reconciliation
- [ ] 12-06: iOS Connected Accounts UI polish — per-platform last sync, reconnect CTA when expired
- [ ] 12-07: TelemetryManager events for connect/disconnect/refresh/publish per platform

#### Phase 13: analytics-insights-readpath

**Goal:** Wire each platform's insights endpoints into existing Analytics repositories, unmock the KPI/engagement/benchmark dashboards with real data.

**Depends on:** Phase 12
**Research:** Likely — insights shapes and rate limits vary dramatically per platform.
**Research topics:**
- TikTok Display API insights (video views, likes, shares, comments)
- IG Insights (impressions, reach, engagement by content type)
- LinkedIn Analytics API (organic/paid breakdown)
- X v2 analytics (impressions, profile visits — note: post-2023 changes)
- Threads insights (new, limited)
- Nightly batch sync vs on-demand with cache

**Plans:**
- [ ] 13-01: Nightly sync Cloud Function per platform
- [ ] 13-02: `AnalyticsRepository` real-data adapter (replace mock data sources)
- [ ] 13-03: `AdvancedAnalyticsRepository` cohort/retention adapter
- [ ] 13-04: `BenchmarkRepository` cross-platform comparison adapter
- [ ] 13-05: KPI card unmock — `Profile/Analytics` views show live data
- [ ] 13-06: Rate-limit aware per-platform throttle + cache TTL policy

---

### 🚧 v1.2 Frontend Audit Fixes (In Progress)

**Milestone Goal:** Close the gaps identified in the 2026-04-17 Frontend Audit. v1.1 shipped the backend and repository layer but left the frontend with ~60 orphan views, 14 unrouted modal groups, Phase 13 analytics silently mocked behind a disabled feature flag, and several production views displaying hardcoded mock data. v1.2 systematically wires the frontend to the work already done.

**Source:** `Claude Files/ENVI Frontend Audit - 2026-04-17.md` (Obsidian vault). 19-item prioritized fix list, P0 → P4.

#### Phase 14: p0-analytics-unmock-profile-bind

**Goal:** Ship the two P0 items — Phase 13 analytics actually serves live data, and the Profile tab stops showing `User.mock`.

**Depends on:** v1.1 complete
**Research:** Unlikely — `AccountRepository` exists, `FeatureFlags.connectorsInsightsLive` already defined, SPM link is mechanical.
**Plans:** TBD (3 expected)

Plans:
- [x] 14-01: Link `FirebaseFirestore` SPM product to ENVI target (resolves v1.1 STATE blocker #7)
- [x] 14-02: Flip `FeatureFlags.connectorsInsightsLive` default to `true` in prod config + verify `AnalyticsRepositoryProvider.resolve()` returns Firestore-backed repo
- [x] 14-03: Bind `AccountRepository` to `ProfileViewModel`; remove `User.mock` from production path

#### Phase 15: p1-routing-layer

**Goal:** Build the missing routing abstraction. `NavigationCoordinator.swift` today is protocol-only; replace with `AppDestination` enum + router so Phase 16 can wire orphan modals from one central place.

**Depends on:** Phase 14
**Research:** Unlikely — standard SwiftUI `NavigationStack` + `navigationDestination(for:)` pattern.
**Plans:** TBD (3 expected)

Plans:
- [x] 15-01: `AppDestination` enum covering all reachable + formerly-orphan destinations
- [x] 15-02: Central router object + `NavigationCoordinator` real implementation; replace ad-hoc `.sheet(isPresented:)` call sites in the 3 live tabs
- [x] 15-03: Deep-link scheme hook (`enviapp://…`) so same router handles OAuth callbacks and future Universal Links

#### Phase 16: p1-publishing-tab-modal-entry-points-aifeatures

**Goal:** Make the 14 orphan modal groups + 7 orphan AIFeatures views reachable. Promote Publishing from "2-file fragment" to a real 4th tab.

**Depends on:** Phase 15
**Research:** Unlikely — all target views + VMs + repos already exist.
**Plans:** TBD (4 expected)

Plans:
- [ ] 16-01: Publishing tab — add as 4th `MainTabBarController` entry; container hosts `ScheduleQueueView` + `LinkedInAuthorPickerView` + placeholder for recurring-post rules
- [ ] 16-02: Profile/Settings entry points for Agency, Teams, Commerce, Experiments, Security, Notifications modals
- [ ] 16-03: ChatExplore — wire 7 AIFeatures views (Ideation, AIVisualEditor, CaptionGenerator, HookLibrary, ScriptEditor, StyleTransfer, ImageGenerator) via a new mode/menu in `ChatExploreView`
- [ ] 16-04: HomeFeed/Library entry points for BrandKit, Campaigns, Collaboration, Community, Metadata, Repurposing, Search, Admin, Enterprise modals

#### Phase 17: p2-mock-to-repo-swaps

**Goal:** Convert 5 views that hold hardcoded mock data in `@State` defaults into repo-driven ViewModels. Lowest-friction wins — the repos already exist.

**Depends on:** Phase 14 (for baseline repo pattern), Phase 15 (so new VMs can be presented)
**Research:** Unlikely — pattern already established (ContentViewModel, CampaignViewModel, etc.).
**Plans:** TBD (3 expected)

Plans:
- [ ] 17-01: `GrowthViewModel` + bind `GrowthRepository` → `GrowthDashboardView`, `ReferralView`
- [ ] 17-02: `SupportViewModel` + bind `SupportRepository` → `SupportCenterView`
- [ ] 17-03: `EducationViewModel` + bind `EducationRepository` → `TutorialListView`, `AchievementsView`

#### Phase 18: p3-dead-action-fixes

**Goal:** Fix the 4 confirmed dead UI actions on already-reachable surfaces.

**Depends on:** Phase 14
**Research:** Unlikely — targeted fixes with well-defined scope.
**Plans:** TBD (3 expected)

Plans:
- [ ] 18-01: `FeedDetailView.swift:107` bookmark — wire to `ContentRepository` bookmark mutation
- [ ] 18-02: `ContentLibrarySettingsView.swift:247` CONNECT rows (YouTube / X / LinkedIn) — route through `SocialOAuthManager`, same path `ConnectedAccountsViewModel` uses
- [ ] 18-03: `TemplateTabView.swift:231-232` `onDuplicate` / `onHide` — bind to `VideoTemplateRepository` + local hide list

#### Phase 19: p4-hygiene

**Goal:** Anti-pattern cleanup + missing test coverage + brand consistency.

**Depends on:** Phase 16 (so test targets match the final reachable surface)
**Research:** Unlikely — refactor + tests.
**Plans:** TBD (5 expected)

Plans:
- [ ] 19-01: Refactor repo-in-view anti-pattern — `SystemHealthView`, `SSOConfigView`, `ContractManagerView` get real ViewModels
- [ ] 19-02: Standardize `AdvancedAnalyticsRepositoryProvider` and `BenchmarkRepositoryProvider` to use `RepositoryProvider.shared.X` pattern
- [ ] 19-03: Delete or merge orphan `LibraryDAMViewModel.swift`; gate `EnhancedChatViewModel` dev mocks behind real `#if DEBUG`
- [ ] 19-04: ViewModel test coverage — at least one XCTest per live tab VM (ProfileViewModel, EnhancedChatViewModel, ForYouGalleryViewModel, new PublishingViewModel)
- [ ] 19-05: Unify ENVI wordmark asset — splash and signup currently use different stencil variants

---

## Progress

**Execution Order:**
Phases execute in numeric order within each milestone.

| Phase | Milestone | Plans | Status | Completed |
|-------|-----------|-------|--------|-----------|
| 1. Repo truth + delivery rails | v1.0 | ✓ | Complete | 2026-04-06 |
| 2. Real identity + API foundation | v1.0 | ✓ | Complete | 2026-04-06 |
| 3. Media ingest + content backbone | v1.0 | ✓ | Complete | 2026-04-06 |
| 4. AI + publishing minimum loop | v1.0 | ✓ | Complete | 2026-04-06 |
| 5. Editor, billing, and launch quality | v1.0 | ✓ | Complete | 2026-04-06 |
| 6. connector-foundation | v1.1 | 7/7 | Implemented | 2026-04-16 |
| 7. oauth-broker-service | v1.1 | 7/7 | Implemented | 2026-04-16 |
| 8. tiktok-sandbox-connector | v1.1 | 7/7 | Implemented | 2026-04-16 |
| 9. x-twitter-connector | v1.1 | 6/6 | Implemented | 2026-04-16 |
| 10. meta-family-connector | v1.1 | 8/8 | Implemented | 2026-04-16 |
| 11. linkedin-connector | v1.1 | 5/5 | Implemented | 2026-04-16 |
| 12. publish-lifecycle-hardening | v1.1 | 7/7 | Implemented | 2026-04-16 |
| 13. analytics-insights-readpath | v1.1 | 6/6 | Implemented | 2026-04-16 |
| 14. p0-analytics-unmock-profile-bind | v1.2 | 3/3 | Complete | 2026-04-17 |
| 15. p1-routing-layer | v1.2 | 3/3 | Complete | 2026-04-17 |
| 16. p1-publishing-tab-modal-entry-points-aifeatures | v1.2 | 0/4 | Not started | - |
| 17. p2-mock-to-repo-swaps | v1.2 | 0/3 | Not started | - |
| 18. p3-dead-action-fixes | v1.2 | 0/3 | Not started | - |
| 19. p4-hygiene | v1.2 | 0/5 | Not started | - |
