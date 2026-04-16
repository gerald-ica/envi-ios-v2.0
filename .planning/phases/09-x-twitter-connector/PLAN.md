---
phase: 09-x-twitter-connector
milestone: v1.1-real-social-connectors
type: execute
domain: ios-swift + firebase-functions-typescript
depends-on: 07-oauth-broker-service
created: 2026-04-16
---

# Phase 9 — X (Twitter) Connector

**Goal:** X OAuth 2.0 PKCE writes + v2 chunked media upload + account lookup + rate-limit–aware retry.

---

## Architecture Decisions

### Decision 1 — Media upload: v2 endpoint, not v1.1

As of late 2024 X introduced `POST https://api.x.com/2/media/upload` with INIT/APPEND/FINALIZE/STATUS parity to v1.1. The v1.1 `upload.twitter.com/1.1/media/upload.json` endpoint was deprecated March 31 2025; full v1.1 shutdown is scheduled June 2025. **Use v2 exclusively.** The v2 endpoint requires OAuth 2.0 user-context with `media.write` scope — no OAuth 1.0a signing required. The OAuth 1.0a Consumer Key (`TTIBKlrthEByJjzk5p8X8NM6b`) is **retained in Secret Manager** for future elevated v1.1 endpoint access if needed before full shutdown, but is not used in Phase 9 flow.

### Decision 2 — OAuth: 2.0 PKCE only

- Client ID: `WC12UFNnY05NU3BDNEtKdHdQUDE6MTpjaQ`
- Scopes: `tweet.read tweet.write users.read media.write offline.access`
- Access token TTL: 2 hours. Refresh token TTL: 6 months. `offline.access` scope activates refresh-token issuance.

### Decision 3 — Proxy pattern

The iOS client never calls X APIs directly. All API calls (OAuth exchange, tweet create, media upload, account lookup) are proxied through Firebase Cloud Functions. This keeps the OAuth 2.0 client secret (`x-oauth2-client-secret`) server-side, consistent with the Phase 6/7 broker architecture.

### Decision 4 — Rate-limit handling

Basic tier limits (2025 docs):
- `POST /2/tweets`: 100 req / 15 min per user, 10,000 req / 24 hr per app
- `POST /2/media/upload` (and sub-commands): 500 req / 15 min per user, 50,000 req / 24 hr per app

Strategy: honor `x-rate-limit-reset` (Unix timestamp) on 429 responses. Retry up to 3 attempts, exponential backoff (base 1s, cap 64s) with ±30% jitter. Final 429 surfaces `XConnectorError.rateLimited(retryAfter: Date)` to iOS via `PublishStatus.failed`. No silent retries on iOS — Cloud Function returns a structured error the client maps to a user-visible CTA ("Try again after HH:MM").

---

## File Map

### iOS

| File | Action | Notes |
|------|--------|-------|
| `ENVI/Core/Connectors/XTwitterConnector.swift` | Create | Main iOS adapter; implements `ProviderOAuthAdapter` from Phase 7 |
| `ENVI/Core/Connectors/XTwitterConnector+Models.swift` | Create | `XAccount`, `XTweetResponse`, `XMediaUploadTicket` value types |
| `ENVI/Core/Connectors/XTwitterConnector+Errors.swift` | Create | `XConnectorError` enum surfaced to UI |

No new SPM dependencies. Uses `AuthenticationServices` (already linked), existing `APIClient`, `SocialOAuthManager`, `PublishingManager`.

### Cloud Functions

| File | Action | Notes |
|------|--------|-------|
| `/functions/src/providers/x.ts` | Create | Provider plugin; registers routes on Phase 7 generic broker |
| `/functions/src/providers/x.media.ts` | Create | Chunked upload sub-module (INIT/APPEND/FINALIZE/STATUS) |
| `/functions/src/providers/x.rate-limit.ts` | Create | `withXRateLimit` HOF; parses `x-rate-limit-reset`, throws `RateLimitError` |
| `/functions/src/providers/x.types.ts` | Create | TypeScript interfaces for all X API request/response shapes |

---

## Sub-Plan Breakdown

### 09-01: `XTwitterConnector` iOS adapter + OAuth 2.0 scopes

Implements Phase 7 `ProviderOAuthAdapter`. Wraps Cloud Function endpoints:
- `POST /oauth/x/start` → `{ authorizationURL, state }`
- Launches `ASWebAuthenticationSession` with scheme `enviapp://oauth-callback/x`
- `POST /oauth/x/callback` with `{ code, state, codeVerifier }` → stored token, returns `PlatformConnection`

`XAccount`:
```swift
struct XAccount: Codable {
    let id: String
    let username: String
    let name: String
    let followerCount: Int
    let profileImageURL: URL?
}
```

Public interface:
```swift
func publishTweet(text: String, mediaPath: URL?, replyToID: String?) async throws -> PublishTicket
func fetchAccount() async throws -> XAccount
```

`FeatureFlags.useMockXConnector: Bool` guards mock path for preview/test.

### 09-02: Cloud Function provider plugin

File: `/functions/src/providers/x.ts`. Registers on Phase 7 `OAuthBroker`. Implements:
- `getAuthorizationURL(state, codeChallenge)` → `https://x.com/i/oauth2/authorize` with `response_type=code`, `client_id=WC12UFNnY05NU3BDNEtKdHdQUDE6MTpjaQ`, `redirect_uri=enviapp://oauth-callback/x`, `scope=tweet.read+tweet.write+users.read+media.write+offline.access`, `state`, `code_challenge`, `code_challenge_method=S256`
- `exchangeCode(code, codeVerifier)` → `POST https://api.x.com/2/oauth2/token` Basic auth (client_id:client_secret base64). Returns `{ access_token, refresh_token, expires_in, scope }`. Stored encrypted in Firestore `users/{uid}/connections/x`.
- `refreshToken(uid)` → same endpoint, `grant_type=refresh_token`. Uses Phase 7 rotation guard.
- `revokeToken(uid)` → `POST https://api.x.com/2/oauth2/revoke`
- `getStatus(uid)` → reads Firestore, returns connection state + scopes

Secret: `x-oauth2-client-secret`.

### 09-03: Tweet create (text) → v2 POST /2/tweets

Additional route: `POST /publish/x/tweet`. Request body:
```json
{
  "text": "...",
  "media": { "media_ids": ["<id>"] },
  "reply": { "in_reply_to_tweet_id": "<id>" }
}
```
Auth: `Authorization: Bearer <user_access_token>`. Response `{ data: { id, text } }`. Map `id` → `PublishTicket.jobID`.

### 09-04: Media upload — v2 chunked INIT/APPEND/FINALIZE/STATUS

File: `/functions/src/providers/x.media.ts`. All calls to `https://api.x.com/2/media/upload`.

**INIT** — `{ "command": "INIT", "media_type": "video/mp4", "total_bytes": <n>, "media_category": "amplify_video" }` → `{ data: { id, media_key, expires_after_secs } }`. Use `id` as `media_id`.

**APPEND** — multipart/form-data: `command=APPEND, media_id=<id>, segment_index=<0-n>, media=<chunk bytes>`. Chunk size: 5 MB. Loop until all bytes sent.

**FINALIZE** — `{ "command": "FINALIZE", "media_id": "<id>" }`. If `processing_info.state == "pending"` or `"in_progress"`, enter STATUS polling loop.

**STATUS** — `GET /2/media/upload?command=STATUS&media_id=<id>`. Poll every `check_after_secs` (default 5s). Terminal: `succeeded` → return `media_id`; `failed` → throw `XConnectorError.mediaProcessingFailed(reason)`.

Media category:
- Video > 140s → `amplify_video`
- Video ≤ 140s → `tweet_video`
- Images → `tweet_image` (no chunking; single POST without `command=INIT`)

iOS sends local media URL to `POST /publish/x/media` which proxies the full chunked flow and returns the stable `media_id`, passed as input to `POST /publish/x/tweet`.

### 09-05: Account lookup + followers count

Route: `GET /oauth/x/account`. Calls `GET https://api.x.com/2/users/me?user.fields=username,name,public_metrics,profile_image_url` with user Bearer token. Maps `public_metrics.followers_count` → `PlatformConnection.followerCount`, `username` → `PlatformConnection.handle`. Called after code exchange and on every `GET /oauth/x/status`.

### 09-06: Rate-limit aware retry

File: `/functions/src/providers/x.rate-limit.ts`. `withXRateLimit<T>(fn, maxRetries = 3): Promise<T>`

- Parse `x-rate-limit-reset`, `x-rate-limit-remaining`, `x-rate-limit-limit` headers.
- On 429: sleep until `reset + 1s` if within budget, else throw `RateLimitError { retryAfter, endpoint }`.
- On 5xx transient: exponential backoff (1→2→4s) with ±30% jitter.
- `RateLimitError` → HTTP 429 response body `{ error: "rate_limited", retryAfter: "<ISO8601>" }`.
- iOS maps to `XConnectorError.rateLimited(retryAfter:)` → `PublishStatus.failed`. UI shows: "X rate limit reached — retry after [time]."

Wrap all calls in `x.ts` and `x.media.ts`.

---

## Data Flow

```
User taps "Post to X"
  → XTwitterConnector.publishTweet(text:mediaPath:replyToID:)
    → if mediaPath != nil:
        POST /publish/x/media
          → INIT → APPEND x N → FINALIZE → poll STATUS
          ← media_id
    → POST /publish/x/tweet { text, media.media_ids, reply }
        ← tweet_id
    → PublishTicket { jobID: tweet_id, status: .posted }
  ← PublishingManager.waitForFinalStatus polls /publish/jobs/{jobID}

Auth:
  ASWebAuthenticationSession
    → enviapp://oauth-callback/x?code=...&state=...
    → GET /oauth/x/callback
      → POST /2/oauth2/token (code exchange)
      → GET /2/users/me (hydrate)
      → Firestore users/{uid}/connections/x (encrypted write)
    ← PlatformConnection
```

---

## Integration Points

| Integration | Where | Notes |
|---|---|---|
| `ProviderOAuthAdapter` | Phase 7 | `XTwitterConnector` conforms |
| `SocialOAuthManager.connect(.x)` | `ENVI/Core/Auth/SocialOAuthManager.swift` | Delegates to `XTwitterConnector` when flag off |
| `PublishingManager.startPublish` | `ENVI/Core/Networking/PublishingManager.swift` | Phase 12 fan-out adds X; Phase 9 uses direct path |
| `PlatformConnection.followerCount` / `handle` | `ENVI/Models/Platform.swift` | Populated by `fetchAccount()` |
| Firestore | `users/{uid}/connections/x` | Phase 6-03 schema |
| Secret Manager | `x-oauth2-client-secret` | IAM-bound to Functions SA |

---

## Open Questions

1. **Tier upgrade trigger:** Basic: 100 posts/15min/user, 10k/24hr app-level. Confirm subscription; Pro ($5k/mo) or PPU if cap hit.
2. **`amplify_video` vs `tweet_video`:** Historically required Amplify program. Test whether Basic can use `amplify_video`, else cap video to 140s `tweet_video`.
3. **Redirect URI:** Register `enviapp://oauth-callback/x` in X developer portal before 09-01 integration test.
4. **`media.write` scope** grantable under current Basic app registration? Confirm via portal.
5. **Phase 7 interface lock:** If signature diverges, `XTwitterConnector` must update before 09-03 wires up.

---

## Build Sequence

- [ ] 09-01: iOS adapter + models + errors; wire into `SocialOAuthManager` behind flag; unit test mock path
- [ ] 09-02: Cloud Function plugin scaffold; OAuth routes; integration test via emulator
- [ ] 09-03: Tweet create route; manual post integration test from staging account
- [ ] 09-04: Media upload module; integration test with 30s MP4
- [ ] 09-05: Account lookup; verify `followerCount`/`handle` hydrate Firestore + iOS
- [ ] 09-06: Rate-limit module; unit test 429 → sleep → retry; verify iOS surfaces error

---

## Verification Checklist

- [ ] `swift build` succeeds, no new SPM deps
- [ ] Mock path: `SocialOAuthManager.connect(.x)` returns valid `PlatformConnection`
- [ ] Real OAuth: tapping "Connect X" launches session, completes PKCE, Firestore doc written
- [ ] `publishTweet(text: "ENVI Phase 9 test")` posts real tweet on staging
- [ ] `publishTweet` with 30s MP4: chunked upload completes, video tweet posts
- [ ] 429 simulation: iOS shows "X rate limit reached" with correct retry time
- [ ] `fetchAccount()` matches live profile
- [ ] `npm test` in `/functions` covers: token exchange, refresh, revoke, tweet create, media INIT/APPEND/FINALIZE, rate-limit logic

---

## Security Notes

- `x-oauth2-client-secret` stays in Functions.
- OAuth 1.0a creds retained in Secret Manager but unused; remove IAM binding if unused 90 days post-Phase 9.
- PKCE `code_verifier` generated iOS-side, only sent at token exchange step, then discarded.
- Rotate `x-oauth2-client-secret` before Phase 9 prod ship (STATE.md security blocker).
