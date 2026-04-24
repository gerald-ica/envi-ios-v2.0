# APIs & networking

**Last updated:** 2026-04-23 UTC

## REST (`APIClient.swift`)

| Item | Value |
|------|--------|
| **Base URL** | `AppConfig.apiBaseURL` by default; connector traffic uses `AppConfig.connectorFunctionsBaseURL` |
| **Implementation** | Real `URLSession` client with JSON encode/decode and Firebase ID-token auth |
| **Retry policy** | 3 attempts; retries `408`, `429`, `500`, `502`, `503`, `504` |
| **Errors** | `invalidURL`, `networkError`, `decodingError`, `unauthorized`, `httpError`, `firebaseNotConfigured`, `missingAuthToken`, `retryExhausted` |

## Content assembly queue (`ContentPieceAssembler.swift`)

**Product behavior:** Queue `PHAsset` local identifiers → upload via `ContentAssemblyTransport` → backend AI → receive `ContentPiece` for World Explorer / library surfaces.

**Current behavior:** Real client-side queue orchestration exists in `ContentPieceAssembler`. The default transport is `APIContentAssemblyTransport()`, per-item retries run up to 3 attempts, and delegate callbacks/completions are fired for success/failure.

## Connector auth / broker layer

- `SocialOAuthManager` drives the real OAuth broker flow:
  - `POST /oauth/{provider}/start`
  - `ASWebAuthenticationSession`
  - `GET /oauth/{provider}/status`
- Provider-specific connector adapters exist for X, TikTok, LinkedIn, and Meta-family surfaces.
- Connector traffic uses a dedicated `APIClient` pointed at `AppConfig.connectorFunctionsBaseURL`, not the legacy app API host.

## USM networking

- `USMSyncActor` talks to:
  - `GET /api/v1/users/{user_id}/self-model`
  - `PUT /api/v1/users/{user_id}/self-model`
  - `POST /api/v1/users/{user_id}/self-model/recompute`
- `USMRecomputeClient` powers the 4-step USM onboarding flow.
- **Current caveat:** `OnboardingCoordinator.swift` still seeds that flow with a hardcoded debug user + local JWT signer for staging smoke tests. The networking layer is merged, but the auth bootstrap is not yet production-complete.

## GraphQL (Firebase Data Connect)

Not called from iOS today. Operations live under `dataconnect/example/queries.gql`. See [Firebase Data Connect](Firebase-Data-Connect).

## Third-party SDKs (network-capable)

| SDK | Use |
|-----|-----|
| **RevenueCat** | App Store purchases, customer info — not “ENVI REST” |
| **SDWebImage** | Image URLs when used |

## Security note

Do **not** commit production secrets into the wiki. The checked-in `ENVI/Resources/GoogleService-Info.plist` is client configuration for the staging iOS app, not a server-side secret, but backend credentials and signing material still belong in Secret Manager / runtime config only.

---

Append new endpoints here when `APIClient` is implemented; log changes in `docs/WIKI_CHANGELOG.md`.
