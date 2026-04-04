# ADR-001: Backend Truth Path (Firebase Auth + Data Connect + API Facade)

Date: 2026-04-04  
Status: Accepted

## Context

ENVI currently ships with strong UI foundations but has incomplete production backend flows:

- `APIClient` is mostly placeholder.
- Data Connect exists in repo, but deployment and auth boundaries are not fully operationalized.
- Authentication and server-side orchestration are required for media, publishing, and analytics.

The team needs a single backend source of truth to avoid split ownership and mock drift.

## Decision

Adopt a hybrid backend architecture with clear responsibilities:

1. **Identity**: Firebase Authentication is the canonical auth provider for iOS clients.
2. **Data model and transactional reads/writes**: Firebase Data Connect (PostgreSQL) is the primary data layer.
3. **Orchestrated external operations** (social publishing, token refresh, AI/oracle proxying, and webhooks): implemented behind a thin server API facade.

## Why this path

- Aligns with existing repository investments (`dataconnect/`) and iOS roadmap requirements.
- Keeps iOS client simple and typed while preventing direct client-side access to sensitive third-party operations.
- Supports progressive hardening: quick startup with managed Firebase capabilities plus controlled server-side expansion.

## Consequences

### Positive

- One auth model across app and backend.
- Shared typed schema through Data Connect.
- Safer integration boundaries for social/AI vendor credentials.
- Easier environment promotion (`dev` -> `staging` -> `prod`) through config and schema management.

### Trade-offs

- Requires maintaining both Data Connect config and an API facade service.
- Team must enforce strict separation between client-permitted operations and backend-only operations.

## Implementation boundaries

- iOS app may call:
  - authenticated API facade endpoints
  - approved Data Connect operations intended for client access
- iOS app must **not** directly call third-party social publish endpoints or hold provider secrets.
- Backend facade owns:
  - OAuth token lifecycle
  - publish/status reconciliation
  - oracle aggregation/proxy
  - webhook handling and retries

## Follow-up tasks

- `ENVI-T005`: versioned deploy path (`firebase.json` + Data Connect docs)
- `ENVI-T006`: Firebase Auth integration in iOS
- `ENVI-T007`: typed API client implementation
- `ENVI-T008`: secure public Data Connect operations and remove unsafe defaults
