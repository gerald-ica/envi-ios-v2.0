---
phase: 07-oauth-broker-service
milestone: v1.1 Real Social Connectors
type: execute
depends-on: 06-connector-foundation
status: ready-to-execute
---

# Phase 7 — OAuth Broker Service

## Objective

Implement a generic, provider-agnostic OAuth 2.0 broker as Firebase Cloud Functions. Every platform connector (Phases 8–11) registers one `ProviderOAuthAdapter` plugin. Replace `SocialOAuthManager.useMockOAuth = true` with real end-to-end flows. Keep mock path alive behind `FeatureFlags.connectorsUseMockOAuth` for SwiftUI previews and unit tests.

---

## Patterns & Conventions (load-bearing from existing codebase)

- Mock-gate pattern: `SocialOAuthManager.useMockOAuth` at `ENVI/Core/Auth/SocialOAuthManager.swift:5`. Phase 7 replaces this static Bool with `FeatureFlags.shared.connectorsUseMockOAuth`, preserving the existing `if Self.useMockOAuth` branch shape.
- `APIClient` at `ENVI/Core/Networking/APIClient.swift` already attaches Firebase ID tokens as `Bearer` headers and handles retry with exponential backoff. All new iOS→Functions calls go through this client unchanged.
- `AppEnvironment` at `ENVI/Core/Config/AppEnvironment.swift` drives `AppConfig.apiBaseURL`. The Functions emulator URL is injected via `ENVI_API_BASE_URL` env var in test schemes — no new env plumbing required.
- `FeatureFlags` at `ENVI/Core/Config/FeatureFlags.swift` is `@MainActor @Observable`, reads Firebase Remote Config when linked, falls back to `#if DEBUG` defaults. New flag follows the same pattern as `templateCatalogSource`.
- Firestore token schema: `users/{uid}/connections/{provider}` established in Phase 6-03. Phase 7 reads/writes this collection from Functions only — never from iOS.

---

## Architecture Decision

**Chosen approach: single shared Cloud Function module with a plugin registry.**

One set of HTTP-triggered Cloud Functions handles all providers. Each provider registers an adapter at module load time. The functions never contain provider-specific logic — they call the registered adapter and handle the generic token lifecycle (PKCE, state, encryption, rotation). This keeps Phases 8–11 as additive files only: register a new adapter, done.

Trade-off accepted: a mis-registered adapter panics at startup rather than at request time. That is the correct behaviour — fail fast at deploy, not at a user's OAuth attempt.

PKCE state is stored in Firestore (`oauth_pending/{stateToken}`) rather than Memorystore (Redis) because the project already has a Firestore dependency, and 10-minute PKCE windows don't require sub-millisecond read latency. This avoids provisioning a VPC + Memorystore instance for Phase 7.

---

## File Structure

### Cloud Functions — `/functions/src/oauth/`

```
functions/src/oauth/
  adapter.ts          # ProviderOAuthAdapter interface (the plugin contract)
  registry.ts         # adapter Map + register/resolve helpers
  start.ts            # POST /oauth/:provider/start              (07-01)
  callback.ts         # GET  /oauth/:provider/callback           (07-02)
  refresh.ts          # POST /oauth/:provider/refresh            (07-03)
  disconnect.ts       # POST /oauth/:provider/disconnect         (07-04)
  status.ts           # GET  /oauth/:provider/status             (07-05)
  pkce.ts             # PKCE S256 helpers (generate, verify)
  state.ts            # State JWT sign/verify + Firestore TTL ops
  tokenStore.ts       # Firestore read/write for users/{uid}/connections/{provider}
  errors.ts           # typed OAuthBrokerError enum used across all handlers
  index.ts            # re-exports all five HTTP functions for Functions framework
```

Downstream connector adapters (Phases 8–11) live in sibling directories:
```
functions/src/connectors/
  tiktok/adapter.ts   # implements ProviderOAuthAdapter, calls registry.register()
  x/adapter.ts
  meta/adapter.ts     # shared by facebook, instagram, threads
  linkedin/adapter.ts
```

### iOS — files to create or modify

```
ENVI/Core/Config/FeatureFlags.swift                    # add connectorsUseMockOAuth flag
ENVI/Core/Auth/SocialOAuthManager.swift                # replace useMockOAuth gate
ENVI/Core/Auth/OAuthWebSession.swift                   # new: ASWebAuthenticationSession driver
```

---

## Component Design

### `adapter.ts` — `ProviderOAuthAdapter` interface

The contract every connector must satisfy.

```typescript
interface ProviderOAuthAdapter {
  readonly provider: string;
  readonly defaultScopes: string[];

  buildAuthUrl(params: {
    state: string;
    codeChallenge: string;
    redirectUri: string;
    scopes?: string[];
  }): string;

  exchangeCode(params: {
    code: string;
    codeVerifier: string;
    redirectUri: string;
  }): Promise<RawTokenSet>;

  refresh(params: { refreshToken: string }): Promise<RawTokenSet>;
  revoke(params: { accessToken: string; refreshToken?: string }): Promise<void>;
  fetchUserProfile(accessToken: string): Promise<ProviderProfile>;
}
```

### `pkce.ts`, `state.ts`, `tokenStore.ts`

- PKCE: `generateVerifier()` (43–128 char URL-safe random), `deriveChallenge(v)` (SHA-256→base64url), `storeVerifier(uid, provider, verifier, redirectUrl) → StateToken`, `consumeVerifier(stateToken) → PendingOAuth` (transactional read-delete).
- State JWT: HS256 signed, secret from Secret Manager `oauth-state-signing-key`, claims `{ uid, provider, nonce, iat, exp: iat+600 }`. stateToken also = Firestore doc ID for `oauth_pending/{stateToken}` — double verification.
- `tokenStore.ts`: reads/writes `users/{uid}/connections/{provider}`. All token fields KMS-envelope-encrypted (Phase 6-07). Refresh-token rotation: store previous `refreshToken` hash in subcollection `users/{uid}/connections/{provider}/rotationHistory/{hash}` for 30 days. Reuse → delete connection + write `securityEvents` doc + HTTP 401 `REFRESH_TOKEN_REUSE`.

### `errors.ts`

```typescript
enum OAuthBrokerErrorCode {
  PROVIDER_NOT_REGISTERED, STATE_EXPIRED, STATE_MISMATCH,
  CODE_EXCHANGE_FAILED, REFRESH_TOKEN_REUSE, REVOCATION_FAILED,
  ENCRYPTION_ERROR, UNAUTHENTICATED
}
```

Provider-specific error detail logged server-side only.

---

## Sub-Plan Specifications

### 07-01: `POST /oauth/:provider/start`
Auth: Firebase ID token.
1. Resolve adapter; 404 if unregistered.
2. Generate PKCE + S256 challenge.
3. Sign state JWT (uid, provider, nonce).
4. Write `oauth_pending/{stateToken}` with `{ codeVerifier, uid, provider, redirectUrl, expiresAt }`.
5. Call `adapter.buildAuthUrl(...)`.
6. Return `{ authorizationUrl, stateToken }`.

### 07-02: `GET /oauth/:provider/callback`
No auth header (CSRF via state JWT).
1. Extract `code`, `state`.
2. Verify state JWT.
3. `consumeVerifier(stateToken)` (tx read-delete).
4. `adapter.exchangeCode(...)`.
5. KMS-encrypt, write `users/{uid}/connections/{provider}`.
6. `adapter.fetchUserProfile(...)`.
7. 302 → `enviapp://oauth-callback/{provider}?status=success`.
On failure: 302 → `enviapp://oauth-callback/{provider}?status=error&code={code}`.

### 07-03: `POST /oauth/:provider/refresh`
Auth required. Load enc refresh token → hash check vs `rotationHistory` (abort on reuse) → `adapter.refresh(...)` → store old hash + new tokens → return updated status.

### 07-04: `POST /oauth/:provider/disconnect`
Auth required. Load tokens → `adapter.revoke(...)` (best-effort) → delete Firestore doc + subcollections → 204.

### 07-05: `GET /oauth/:provider/status`
Auth required. Read doc → if missing/revoked return `{ isConnected: false }` → if expires within 5 min attempt silent refresh → return `OAuthStatusResponse`.

---

## iOS Changes

### `FeatureFlags.swift`
Add:
```swift
public var connectorsUseMockOAuth: Bool = {
  #if DEBUG
  return true
  #else
  return false
  #endif
}()
```
Add to `applyRemoteConfigValues`: read Remote Config key `"connectorsUseMockOAuth"`.

### `SocialOAuthManager.swift`
Remove `static var useMockOAuth: Bool = true`.
Replace every `if Self.useMockOAuth` with `if FeatureFlags.shared.connectorsUseMockOAuth`.
Real path:
```
1. POST /oauth/{provider}/start → { authorizationUrl, stateToken }
2. OAuthWebSession opens authorizationUrl
3. Session resolves on enviapp://oauth-callback/{provider}?status=...
4. If error: throw OAuthError.connectionFailed(platform)
5. GET /oauth/{provider}/status → build PlatformConnection
```

### `OAuthWebSession.swift` (new)
Actor wrapping `ASWebAuthenticationSession`. `prefersEphemeralWebBrowserSession = false`. Maps `canceledLogin` → `OAuthError.userCancelled(platform)` (new case). MainActor-required. Injectable for tests.

---

## Data Flow (connect happy path)

```
iOS: SocialOAuthManager.connect(platform:)
  → POST /oauth/{provider}/start  (Firebase ID token)
      Functions: verify → PKCE → state JWT → oauth_pending/{stateToken} → adapter.buildAuthUrl
      ← { authorizationUrl, stateToken }
  → OAuthWebSession opens URL
      User auths at provider
      Provider → GET /oauth/{provider}/callback?code=...&state=...
        Functions: verify state → consumeVerifier (tx) → exchangeCode
                 → fetchUserProfile → KMS encrypt → write connection doc
                 → 302 → enviapp://oauth-callback/{provider}?status=success
      Session resolves
  → GET /oauth/{provider}/status  (Firebase ID token)
      Functions: read → check expiry → OAuthStatusResponse
      ← { isConnected, handle, followerCount, tokenExpiresAt, scopes }
```

---

## Build Sequence

### 07-01
- [ ] `functions/src/oauth/errors.ts`
- [ ] `adapter.ts` (interface + `RawTokenSet`, `ProviderProfile`)
- [ ] `registry.ts`
- [ ] `pkce.ts`
- [ ] `state.ts` (JWT sign/verify, Secret Manager key fetch)
- [ ] `start.ts`
- [ ] `index.ts` (export `oauthStart`)
- [ ] Deploy to emulator, curl smoke test

### 07-02
- [ ] `tokenStore.ts` (KMS encrypt/decrypt + Firestore CRUD)
- [ ] `callback.ts`
- [ ] `OAuthWebSession.swift`
- [ ] `SocialOAuthManager.connect()` real path
- [ ] End-to-end test with StubAdapter

### 07-03
- [ ] `refresh.ts`, rotation history subcollection
- [ ] Verify iOS `refreshToken()` real path

### 07-04
- [ ] `disconnect.ts`
- [ ] Verify iOS `disconnect()` real path

### 07-05
- [ ] `status.ts` with inline silent refresh
- [ ] Verify iOS `connectionStatus()` real path

### 07-06
- [ ] `connectorsUseMockOAuth` added to FeatureFlags
- [ ] Remove `useMockOAuth` static; substitute FeatureFlag calls everywhere
- [ ] Add `userCancelled` case to `OAuthError`
- [ ] Preview macros set `connectorsUseMockOAuth = true`

### 07-07
- [ ] Firebase emulator config in `firebase.json`
- [ ] `ENVITests/OAuth/OAuthBrokerTests.swift` (round-trip via StubAdapter)
- [ ] `OAuthRefreshRotationTests.swift` (reuse detection)
- [ ] `SocialOAuthManagerTests.swift` (mocked URLSession + OAuthWebSession)
- [ ] CI: add emulator startup to test job

---

## Error Handling

| Scenario | Function | iOS |
|---|---|---|
| Provider not registered | 404 PROVIDER_NOT_REGISTERED | connectionFailed |
| State JWT invalid | 302 err STATE_EXPIRED | connectionFailed |
| Code exchange 4xx | 302 err CODE_EXCHANGE_FAILED | connectionFailed |
| Refresh token reuse | 401 REFRESH_TOKEN_REUSE | tokenExpired → reauth |
| User cancels session | canceledLogin | userCancelled (new) |
| KMS failure | 500 ENCRYPTION_ERROR | connectionFailed |
| Revocation fails on disconnect | log + 204 | success |

No tokens ever in logs.

---

## Security Considerations

1. Client secrets never leave Functions.
2. PKCE S256 mandatory.
3. State JWT + Firestore doc double-check.
4. Refresh rotation detection, 30-day hash window.
5. KMS envelope encryption on token fields (Phase 6-07).
6. `oauth_pending` TTL policy (Phase 6-03).
7. Firebase App Check enforced on all 5 HTTP Functions.
8. **Blocker: all 8 provider secrets were exposed in plaintext 2026-04-16. Phase 6-02 rotation must complete before Phase 7 deploys to any non-local environment.**

---

## Open Questions

1. `ASWebAuthenticationSession` presentation anchor API on iOS 26 — verify before writing `OAuthWebSession.swift`.
2. `oauth-state-signing-key` dual-key overlap window needed for zero-downtime rotation.
3. Meta may require HTTPS redirect (not custom scheme) — may need `postCallbackRedirect` field on pending doc; confirm in Phase 10 research.
4. CI test runs should force `connectorsUseMockOAuth = true` via xcconfig override — document in 07-07.

---

## Verification Checklist

- [ ] `cd functions && npm run build` zero errors
- [ ] All 5 HTTP functions on local emulator reachable
- [ ] Full connect round-trip passes against StubAdapter
- [ ] Refresh reuse triggers security event + deletion
- [ ] `useMockOAuth` static removed, FeatureFlag substituted
- [ ] SwiftUI previews render
- [ ] All `ENVITests/OAuth/*` pass in CI
- [ ] No tokens in any log output
- [ ] ROADMAP.md + STATE.md updated for Phase 7 complete
