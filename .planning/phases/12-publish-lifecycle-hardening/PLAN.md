---
phase: 12-publish-lifecycle-hardening
milestone: v1.1 Real Social Connectors
type: plan
depends-on: phases 8, 9, 10, 11
status: not-started
created: 2026-04-16
---

# Phase 12 — Publish Lifecycle Hardening

**Goal:** Turn per-connector publish calls into a real multi-platform dispatcher. Replace `PublishingManager` backend stubs. Add retry/DLQ, refresh-token cron, revocation handling, polished Connected Accounts UI.

---

## Patterns and Conventions (Load-Bearing)

| Pattern | Source |
|---|---|
| Mock-mode gate `static var useMock*: Bool` | `SocialOAuthManager.useMockOAuth` — keep; disable via `FeatureFlag.realOAuth` |
| Repository protocol → Mock → API → Provider | `ENVI/Core/Data/Repositories/` |
| `APIClient.shared.request(endpoint:method:body:requiresAuth:)` | All iOS→Firebase calls |
| `TelemetryManager.shared.track(_:parameters:)` | `TelemetryManager.swift:99` |
| `SocialPlatform.apiSlug` (lowercased rawValue) | `Platform.swift:16` |
| `PlatformConnection` + `isTokenExpiringSoon` | `Platform.swift:42` — needs `revokedAt` + `lastSyncAt` |
| Cloud Functions: TypeScript, 2nd gen, Node 20 | STATE.md |
| Token storage: Firestore `users/{uid}/connections/{provider}` | STATE.md — Cloud KMS envelope encryption |

---

## Sub-Plans

### 12-01  Cloud Function `publish/jobs` Dispatcher

**File:** `functions/src/publish/dispatch.ts` — Firebase Callable (`onCall`, 2nd gen).

**Request:**
```ts
{
  caption: string;
  platforms: string[];     // SocialPlatform.apiSlug values
  mediaRefs: string[];     // Cloud Storage object paths
  scheduledAt?: string;    // ISO 8601, optional
}
```

**Responsibilities:**
1. Assert `context.auth.uid` — reject with `UNAUTHENTICATED`.
2. Validate `platforms[]` against known slugs — reject unknowns with `INVALID_ARGUMENT`.
3. Create `publish_jobs/{jobId}` Firestore doc (12-02 schema).
4. If `scheduledAt` absent or within 30s, publish one Pub/Sub message per platform to `envi-publish-{platform}` with `{ jobId, uid, platform, caption, mediaRefs }`.
5. If scheduled future, write `queued` only — scheduled-dispatch cron fans out later.
6. Return `{ jobId, status: "queued" }` immediately.

**iOS — `ENVI/Core/Networking/PublishingManager.swift`:**
- `PublishStartRequest` gains `mediaRefs: [String]`.
- `startPublish(caption:platforms:scheduledAt:)` gains `mediaRefs: [String]`.
- `PublishStatus` gains `.partial`.
- `waitForFinalStatus` treats `.partial` as terminal.
- `PublishStatusResponse` gains `platformStatuses: [String: ProviderPublishStatus]?`.

---

### 12-02  Firestore Job State Machine

**Collection:** `publish_jobs/{jobId}`

**Schema:**
```
uid:          string
caption:      string
mediaRefs:    string[]
scheduledAt:  Timestamp | null
createdAt:    Timestamp
status:       "queued" | "processing" | "posted" | "partial" | "failed"
platforms:
  [platform]:
    status:          "queued" | "processing" | "posted" | "failed" | "dlq"
    providerPostId:  string | null
    error:           string | null   // sanitized code, not raw API body
    attempts:        number
    lastAttemptAt:   Timestamp | null
    postedAt:        Timestamp | null
```

**Top-level status derivation:**
- All `posted` → `posted`
- All `failed`/`dlq` → `failed`
- Mix of `posted` + `failed`/`dlq` → `partial`
- Any `queued`/`processing` → `processing`

**State machine:**
```
[queued] → [processing] → [posted]
                │
                ↓
            [failed]  ← all exhausted
                │
                ↓
            per-provider [dlq]
```

**Security rules:** `publish_jobs/{jobId}` — client read when `request.auth.uid == resource.data.uid`; no client writes; writes only from Functions service account.

---

### 12-03  Retry + Backoff + DLQ

**Files:**
- `functions/src/publish/providerWorker.ts` (base)
- `functions/src/publish/workers/{tiktok,x,instagram,threads,facebook,linkedin}Worker.ts`
- `functions/src/publish/replayDLQ.ts` (ops callable)

Each worker: `onMessagePublished` subscribed to `envi-publish-{platform}`.

**Retry logic (base):**
- Read `platforms[platform].attempts` from Firestore (not Pub/Sub delivery count — idempotent).
- `attempt = storedAttempts + 1`
- Backoff: attempt 1 → 5s, 2 → 25s, 3 → 125s.
- Transient failure: write `status: "processing"`, increment `attempts`, set `lastAttemptAt`, throw → Pub/Sub retries.
- Success: write `status: "posted"`, `providerPostId`, `postedAt`. Re-derive job status.
- `attempts >= 3`: write `status: "dlq"`, `error: <code>`. Mirror to `publish_dlq/{jobId}/platforms/{platform}`. Re-derive.

**Idempotency guard:** check `platforms[platform].status` before processing — if `posted`, ack and return.

**X rate-limit:** read `x-rate-limit-remaining`; if 0, schedule retry at `x-rate-limit-reset` Unix timestamp. Emit `publish_provider_failure` with `error: "rate_limited"`.

**DLQ replay:** `replayDLQ({ jobId, platform })` resets `status: "queued"`, `attempts: 0`, republishes Pub/Sub.

---

### 12-04  Refresh-Token Cron

**File:** `functions/src/crons/refreshTokens.ts` — Cloud Scheduler → Pub/Sub → `onMessagePublished`. Schedule: `0 2 * * *`.

**Logic:**
1. Collection group query: `connections` where `tokenExpiresAt <= now + 24h AND isConnected == true AND revokedAt == null`.
2. Call Phase 7 `POST /oauth/{provider}/refresh` server-to-server (admin SDK).
3. Success: update `tokenExpiresAt` (Meta: `now + 60d` explicitly), `lastRefreshedAt`. Emit `oauth_refresh_success`.
4. Failure: increment `refreshFailureCount`. If `>= 3`, write `revokedAt`. Emit `oauth_refresh_failure`.

---

### 12-05  Webhook Receivers

**Files:** `functions/src/webhooks/instagram.ts`, `facebook.ts`, `README.md`.

**IG/FB (onRequest):**
- GET → return `hub.challenge` for verification.
- POST → parse `entry[].changes[]`, extract `status`. Match `providerPostId` against `publish_jobs`. Write `posted`/`failed` + re-derive.

**TikTok/X/LinkedIn:** No webhook — rely on client polling + Phase 13 nightly sync. Document in README.

---

### 12-06  iOS Connected Accounts UI Polish

**`Platform.swift` changes:**
- Add `revokedAt: Date?` to `PlatformConnection`.
- Add `lastSyncAt: Date?` to `PlatformConnection`.
- `isTokenExpiringSoon` unchanged.

**New files:**
- `ENVI/Features/Profile/Settings/ConnectedAccountsView.swift`
- `ENVI/Features/Profile/Settings/ConnectedAccountsViewModel.swift`

ViewModel: `@Published var connections: [PlatformConnection]`, actions `connect/disconnect/reconnect/refresh` delegating to `SocialOAuthManager`, fire telemetry, reload.

**Pill row states (priority order):**
1. `revokedAt != nil` → red `RECONNECT` (tappable → connect).
2. `isTokenExpiringSoon && revokedAt == nil` → amber `EXPIRING SOON` (tappable → refresh).
3. `isConnected && !isTokenExpiringSoon` → green `CONNECTED` (tappable → disconnect confirm).
4. `!isConnected` → surface `CONNECT` (tappable → connect).

**`SettingsView.swift`:** add `NavigationLink { ConnectedAccountsView() } label: { settingsRow(icon: "link", title: "Connected Accounts") }`.

**`ConnectedPlatformsView.swift`:** update compact pill to show `lastSyncAt` subtitle.

**Previews:** add `static var previewFixtures: [PlatformConnection]` covering all 4 badge states. Use `SocialOAuthManager.useMockOAuth` for offline previews.

---

### 12-07  TelemetryManager Events

Add to `Event` enum after `platformDisconnected`:
```swift
// OAuth Lifecycle — Phase 12
case oauthConnectSuccess  = "oauth_connect_success"
case oauthConnectFailure  = "oauth_connect_failure"
case oauthDisconnect      = "oauth_disconnect"
case oauthRefreshSuccess  = "oauth_refresh_success"
case oauthRefreshFailure  = "oauth_refresh_failure"
// Publish Dispatcher — Phase 12
case publishDispatch         = "publish_dispatch"
case publishProviderSuccess  = "publish_provider_success"
case publishProviderFailure  = "publish_provider_failure"
```

Convenience methods:
```swift
func trackOAuth(_ event: Event, platform: String, error: String? = nil)
func trackPublishProvider(_ event: Event, jobID: String, platform: String, attempt: Int, error: String? = nil)
```

Call sites: `SocialOAuthManager.connect/disconnect/refreshToken`, `PublishingManager.startPublish`, per-platform Cloud Function workers (server-side).

**No-PII rule:** never log handles, tokens, captions, media URIs.

---

## File Structure

```
functions/src/
  publish/
    dispatch.ts          # 12-01
    replayDLQ.ts         # 12-03
    providerWorker.ts    # 12-03
    workers/
      {tiktok,x,instagram,threads,facebook,linkedin}Worker.ts  # 12-03
  crons/
    refreshTokens.ts     # 12-04
  webhooks/
    instagram.ts         # 12-05
    facebook.ts          # 12-05
    README.md            # gap doc

ENVI/
  Models/Platform.swift                           # +revokedAt, +lastSyncAt
  Core/Networking/PublishingManager.swift         # +mediaRefs, +partial
  Core/Telemetry/TelemetryManager.swift           # +8 events + 2 methods
  Features/Profile/
    ConnectedPlatformsView.swift                  # +lastSyncAt subtitle
    SettingsView.swift                            # +nav row
    Settings/
      ConnectedAccountsView.swift                 # new
      ConnectedAccountsViewModel.swift            # new
```

---

## Build Sequence

### A. Backend core (12-01, 12-02)
- [ ] Scaffold `dispatch.ts`
- [ ] Define Firestore schema + security rules
- [ ] Add `mediaRefs` + `.partial` to iOS `PublishingManager`
- [ ] Emulator smoke test: 1 dispatch → Firestore doc + N Pub/Sub msgs

### B. Workers (12-03)
- [ ] `providerWorker.ts` base (retry, backoff, DLQ, idempotency)
- [ ] `instagramWorker.ts` end-to-end reference
- [ ] Remaining 5 workers
- [ ] Integration test: 2 platforms, simulate failure, confirm `dlq` after attempt 3

### C. Cron + webhooks (12-04, 12-05)
- [ ] `refreshTokens.ts` cron — seed expiring token, confirm refresh
- [ ] IG + FB webhook receivers — register in Meta dev console
- [ ] `webhooks/README.md` gap document

### D. iOS UI (12-06)
- [ ] `PlatformConnection` + `revokedAt`/`lastSyncAt`
- [ ] `ConnectedAccountsViewModel`
- [ ] `ConnectedAccountsView` with 4 badge states
- [ ] Nav row in `SettingsView`
- [ ] `ConnectedPlatformsView` `lastSyncAt` subtitle

### E. Telemetry (12-07)
- [ ] 8 Event cases + 2 convenience methods
- [ ] Call sites wired
- [ ] Zero-PII audit

### F. Integration + cleanup
- [ ] E2E: publish to 3 platforms → workers → iOS reflects terminal state
- [ ] Token expiry → cron refreshes → UI clears badge
- [ ] 3 failures → `revokedAt` → RECONNECT appears
- [ ] DLQ entry queryable; `replayDLQ` resets + re-enqueues
- [ ] Flip `useMockOAuth` default to `false`; gate via `FeatureFlag.realOAuth`

---

## Critical Details

- **Scheduled posts:** separate Cloud Scheduler cron every 5 min queries `status=="queued" AND scheduledAt<=now` and fans out Pub/Sub.
- **Meta token refresh:** Meta doesn't return new `expires_in` on refresh — explicitly set `tokenExpiresAt = now + 60d` after successful exchange.
- **Error sanitization:** Firestore `error` field uses sanitized codes (`rate_limited`, `media_rejected`, `auth_expired`, `unknown`). Raw API bodies stay in Cloud Function logs only.
- **Firestore write contention:** top-level `status` derivation uses a Firestore Transaction to read all per-platform statuses atomically before writing — prevents races when two workers complete simultaneously.
- **Disconnect confirmation:** `ConnectedAccountsView` shows a destructive confirmation sheet before calling `disconnect`, matching `ENVICustomerCenterView` pattern.
