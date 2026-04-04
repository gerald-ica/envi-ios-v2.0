# ENVI GSD Project Plan

Generated: 2026-04-03 23:46:44Z (UTC)

## Inputs reviewed
- `/Users/gerald/Downloads/ENVI_Product_Strategy_and_1000_Feature_Backlog.md`
- `/Users/gerald/Downloads/ENVI_iOS_Developer_Handoff_AgilityIO (1).pdf`
- Current repository + GitHub state (`gerald-ica/envi-ios-v2.0`)

## Problem statement
ENVI has a high-quality iOS UX shell and differentiated 3D explorer, but production-critical layers remain incomplete: auth, backend API, media assembly, social integrations, analytics truth, and CI/CD alignment. The repo also has GitOps drift (non-applicable GKE workflow, no iOS CI baseline, no deployment truth for backend components).

## Product objective (next 90 days)
Ship a production-ready **Phase 0/1** foundation where one creator can:
1. Authenticate with real identity.
2. Ingest/upload media and get real `ContentPiece` records.
3. Use non-mock AI recommendations/chat (Oracle integration path).
4. Export and/or publish through at least one real platform integration.
5. See real analytics for connected account(s).
6. Pay through entitlements/paywall and remain subscribed across sessions.

## Scope boundaries
### In-scope now (P0/P1)
- FND, MED, ANA, AI (minimum), PUB (minimum), BILL, OPS, SEC baseline
- iOS CI + staging/prod environment separation
- Data Connect/Firebase alignment and real API path

### Deferred (post-PMF)
- Full agency/multi-client operations
- Marketplace/UGC exchange
- Enterprise SSO/SCIM/procurement
- Broad API ecosystem and deep automation builder

## Success criteria
- No critical user path depends on static mock data.
- CI gates PRs with iOS build + tests.
- Staging backend is deployable from versioned config.
- At least one end-to-end happy path (onboarding -> ingest -> AI suggestion -> export/publish -> analytics) is testable and observable.

## Architecture decisions
- Backend source of truth: `docs/architecture/ADR-001-backend-truth-path.md`
