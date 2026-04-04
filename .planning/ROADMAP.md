# ENVI GSD Roadmap (Phased)

Generated: 2026-04-03 23:46:44Z (UTC)

## Phase 1 — Repo truth + delivery rails (Weeks 1-2)
**Goal:** Align repository, CI, and environment model with actual iOS product.

- Remove or quarantine `.github/workflows/google.yml` (currently template + wrong branch matcher).
- Add iOS CI workflow (`xcodebuild`/simulator tests).
- Define envs: `dev`, `staging`, `prod` with clear config source.
- Create ADR deciding backend path (Firebase Auth + Data Connect + optional API facade).

**Exit criteria**
- PR checks enforce iOS build/test.
- No misleading infrastructure workflow remains active.

## Phase 2 — Real identity + API foundation (Weeks 2-4)
**Goal:** Replace auth/network stubs with production-capable baseline.

- Integrate Firebase Auth (email + Apple Sign-In minimum).
- Replace `APIClient` stub with typed client and auth token path.
- Add `firebase.json` + Data Connect deploy/readme path.
- Lock down public Data Connect operations meant only for seed/demo.

**Exit criteria**
- User can sign in/out on staging with persistent session.
- App performs authenticated network requests beyond mock mode.

## Phase 3 — Media ingest + content backbone (Weeks 4-7)
**Goal:** Turn camera-roll concept into real content pipeline.

- Implement PHAsset ingestion observers and upload queue.
- Implement server-side media record creation + processing status.
- Wire `ContentPieceAssembler` to real endpoints.
- Replace Library + Explore data sources with backend-backed content.

**Exit criteria**
- Imported assets appear as real content entries across app relaunch.

## Phase 4 — AI + publishing minimum loop (Weeks 7-10)
**Goal:** Real creator value loop with Oracle path and first social integration.

- Integrate Oracle endpoint contract for recommendations/chat.
- Add first social OAuth (Instagram or YouTube) with token lifecycle.
- Implement publish/status reconciliation for one channel.
- Feed analytics dashboard with real metric payloads.

**Exit criteria**
- One creator can connect platform, publish, and view real performance metrics.

## Phase 5 — Editor, billing, and launch quality (Weeks 10-14)
**Goal:** Production readiness and monetization.

- Replace key editor placeholders with AVFoundation-based real operations.
- RevenueCat entitlement gates tied to backend/API behavior.
- Add crash reporting + product analytics events + release notes discipline.
- TestFlight pipeline and release checklist.

**Exit criteria**
- External TestFlight candidate with monitored core flow + entitlement checks.

## Deferred phases (post-PMF)
- Teams/roles/workspaces, agency operations, CRM/inbox, marketplace, enterprise features.
