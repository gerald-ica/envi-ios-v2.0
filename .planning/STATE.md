# ENVI GSD State

## Current Position

Milestone: **v1.1 Real Social Connectors**
Phase: **6 of 8** (connector-foundation)
Plan: Not started
Status: Ready to plan
Last activity: 2026-04-16 — Milestone v1.1 created
Progress: ░░░░░░░░░░ 0%

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

## Session Continuity

Last session: 2026-04-16
Stopped at: Milestone v1.1 initialization — ready to plan Phase 6
Resume file: None
