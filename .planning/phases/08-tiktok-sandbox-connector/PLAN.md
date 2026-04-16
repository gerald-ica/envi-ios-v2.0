---
phase: 08-tiktok-sandbox-connector
milestone: v1.1-real-social-connectors
type: execute
depends-on: 07-oauth-broker-service
credentials:
  client-key: sbaw4c49dgx7odxlai   # public
  secret-ref: tiktok-sandbox-client-secret   # Secret Manager only
---

# Phase 8 — TikTok Sandbox Connector

**Goal:** First real end-to-end connector. Prove Phase 6+7 architecture with ENVI-SANDBOX credentials. Exit: fixture video publishes to sandbox tester's TikTok inbox from iOS simulator.

---

## Architecture Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Video source | `FILE_UPLOAD` | No public CDN required in sandbox |
| Publish mode | Inbox (`/inbox/video/init/`) | Sandbox mandates inbox flow; also gives tester review step (App Review compatible) |
| iOS OAuth | `ASWebAuthenticationSession` via Phase 6 `OAuthSession` | Already established |
| Token storage | Phase 6 Firestore `users/{uid}/connections/tiktok` | Broker-owned |
| PKCE | Required (S256) | Mandated by TikTok |
| Chunk size | 10 MB | Within TikTok and iOS URLSession ceilings |
| Status polling | Cloud Function-side | iOS battery-friendly; iOS observes Firestore |

---

## TikTok API Reference (verified 2026-04-16)

### Login Kit v2
- Auth URL: `https://www.tiktok.com/v2/auth/authorize/`
- Token: `POST https://open.tiktokapis.com/v2/oauth/token/`
- Refresh: same, `grant_type=refresh_token` (may return new refresh_token — persist if different)
- Revoke: `POST https://open.tiktokapis.com/v2/oauth/revoke/`
- Access TTL: 86400s. Refresh TTL: 31536000s.
- Scopes (comma-separated): `user.info.basic,video.list,video.upload,video.publish`
- Redirect URI: `enviapp://oauth-callback/tiktok`

### Display API
- `GET https://open.tiktokapis.com/v2/user/info/` (scope `user.info.basic`) — fields: `open_id,union_id,display_name,avatar_url,follower_count,video_count`
- `POST https://open.tiktokapis.com/v2/video/list/` (scope `video.list`) — body `{cursor, max_count}`, cursor-based pagination

### Content Posting API (inbox — sandbox-compatible)
1. **Init:** `POST https://open.tiktokapis.com/v2/post/publish/inbox/video/init/` — body `{source_info: {source: "FILE_UPLOAD", video_size, chunk_size, total_chunk_count}}` → `{publish_id, upload_url}` (1h TTL)
2. **Upload:** PUT chunks to `upload_url`; headers `Content-Type: video/mp4`, `Content-Length`, `Content-Range: bytes {first}-{last}/{total}`
3. **Status:** `POST https://open.tiktokapis.com/v2/post/publish/status/fetch/` — body `{publish_id}`; states `PROCESSING_UPLOAD → SEND_TO_USER_INBOX → PUBLISH_COMPLETE | FAILED`; rate limit 30 req/min/user

**Video constraints:** MP4/MOV, H.264, ≤500 MB, 15s–10min, ≥720p recommended.

**Sandbox:** max 10 target users; list propagation up to 1h.

---

## Files to Create

### iOS
- `ENVI/Core/Connectors/TikTokConnector.swift` — `actor`, implements `ConnectorProtocol` from Phase 6/7
- `ENVI/Core/Connectors/TikTokModels.swift` — `TikTokVideo`, `TikTokUserInfo`, `TikTokPublishStatus`, `TikTokPrivacyLevel`, `TikTokConnectorError`
- `ENVI/Features/Auth/TikTokSandboxErrorView.swift` — sandbox-not-whitelisted sheet
- `ENVITests/Connectors/TikTokConnectorTests.swift` (unit)
- `ENVITests/Connectors/TikTokIntegrationTests.swift` (skipped unless `ENVI_RUN_TIKTOK_INTEGRATION=1`)
- `ENVITests/Fixtures/test-video.mp4` (15s, 720p, ≤5MB)

### Cloud Functions
- `/functions/src/providers/tiktok.ts` — implements Phase 7 `ProviderOAuthAdapter`; pulls secret from Secret Manager `tiktok-sandbox-client-secret`
- `/functions/src/providers/tiktok.publish.ts` — inbox upload init + status poll + Firestore write
- `/functions/src/providers/tiktok.display.ts` — `getUserInfo`, `listVideos`
- `/functions/src/providers/__tests__/tiktok.test.ts`

---

## Files to Modify

- `ENVI/Core/Auth/SocialOAuthManager.swift` — when `platform == .tiktok && !useMockOAuth && FeatureFlags.useTikTokConnector`, delegate to `TikTokConnector.shared`
- `ENVI/Core/Config/FeatureFlags.swift` — add `var useTikTokConnector: Bool` (default false DEBUG, true release)
- `ENVI/Core/Networking/PublishingManager.swift` — `// TODO(phase-12): route through dispatcher` comment; no code change yet
- `ENVI/Resources/Info.plist` — verify `enviapp` URL scheme (should exist from Phase 6-04)
- `/functions/src/providers/index.ts` — `registry.register('tiktok', tikTokAdapter)`

---

## Sub-Plans

### 08-01  TikTokConnector iOS adapter

```swift
actor TikTokConnector {
    static let shared = TikTokConnector()
    func connect() async throws -> PlatformConnection
    func refreshConnection() async throws -> PlatformConnection
    func publishVideo(at fileURL: URL, caption: String, privacy: TikTokPrivacyLevel) async throws -> PublishTicket
    func listVideos(cursor: Int64?, maxCount: Int) async throws -> (videos: [TikTokVideo], hasMore: Bool, nextCursor: Int64?)
}

enum TikTokConnectorError: LocalizedError {
    case sandboxUserNotAllowed
    case uploadURLExpired
    case videoTooLarge(bytes: Int)
    case videoDurationOutOfRange
    case publishFailed(reason: String)
    case tokenRefreshRequired
}
```

Does NOT own token storage. Calls broker Cloud Function endpoints via `APIClient`.

### 08-02  Cloud Function provider plugin

Implements `ProviderOAuthAdapter`. Constants:
```typescript
const TIKTOK_AUTH_URL = 'https://www.tiktok.com/v2/auth/authorize/';
const TIKTOK_TOKEN_URL = 'https://open.tiktokapis.com/v2/oauth/token/';
const TIKTOK_REVOKE_URL = 'https://open.tiktokapis.com/v2/oauth/revoke/';
const SCOPES = 'user.info.basic,video.list,video.upload,video.publish';
const CLIENT_KEY = 'sbaw4c49dgx7odxlai';
```

PKCE: `buildAuthURL` receives `code_challenge` from broker; `exchangeCode` sends `code_verifier`.

Refresh rotation: compare returned `refresh_token` to stored; if different, overwrite + log warning.

### 08-03  Content Posting API — inbox upload

**iOS flow:**
1. Validate file (MP4/MOV, ≤500MB, 15s–10min, from `AVURLAsset`)
2. POST `/connectors/tiktok/publish/init` → `{publishID, uploadURL, chunkSize}`
3. Read 10MB chunks; PUT to `uploadURL` with `Content-Range` via raw `URLSession.upload(for:from:)` (no Auth header)
4. POST `/connectors/tiktok/publish/complete` with `publishID`
5. Firestore snapshot listener on `users/{uid}/connections/tiktok/publishes/{publishID}` → status updates
6. Return `PublishTicket(jobID: publishID, status: .queued)` immediately

**Cloud Function:**
- `initUpload(userToken, videoSizeBytes)` → TikTok init, returns `{publishID, uploadURL}`
- `pollUntilComplete(userToken, publishID)` → exponential backoff (5s → 60s, 10min timeout); writes final status to Firestore
- Rate limits: 6 req/min init, 30 req/min status

### 08-04  Display API read-path

Map `display_name` → `PlatformConnection.handle`, `follower_count` → `followerCount`. Store `open_id` in Firestore.

Video fields: `id,title,cover_image_url,create_time,duration,view_count,like_count,comment_count,share_count`.

### 08-05  Sandbox allowlist UX

Detection: broker `/oauth/tiktok/callback` maps any auth error in staging env to `TIKTOK_SANDBOX_USER_NOT_ALLOWED`. iOS maps to `TikTokConnectorError.sandboxUserNotAllowed` → presents `TikTokSandboxErrorView` (only in staging).

Content:
- Title: "TikTok account not approved"
- Body: "Your TikTok account isn't yet approved for our sandbox. Contact support to be added as a tester."
- CTA: "Contact Support" → `mailto:support@weareinformal.com?subject=TikTok+Sandbox+Access`

### 08-06  Integration test

```swift
func testEndToEndSandboxPublish() async throws {
    try XCTSkipUnless(ProcessInfo.processInfo.environment["ENVI_RUN_TIKTOK_INTEGRATION"] == "1", ...)
    let connection = try await TikTokConnector.shared.refreshConnection()
    XCTAssertTrue(connection.isConnected)
    let fixtureURL = Bundle(for: type(of: self)).url(forResource: "test-video", withExtension: "mp4")!
    let ticket = try await TikTokConnector.shared.publishVideo(at: fixtureURL, caption: "[ENVI Test] \(Date())", privacy: .onlyMe)
    let finalStatus = try await PublishingManager.shared.waitForFinalStatus(jobID: ticket.jobID, maxAttempts: 12)
    XCTAssertEqual(finalStatus, .posted)
    let (videos, _, _) = try await TikTokConnector.shared.listVideos(cursor: nil, maxCount: 5)
    XCTAssertTrue(videos.contains { $0.title?.contains("ENVI Test") == true })
}
```

### 08-07  Promotion checklist

`/docs/tiktok-production-promotion.md`:
- Rotate `tiktok-sandbox-client-secret` per Phase 6-02
- Create production TikTok app (or promote sandbox)
- Register production redirect URI
- Demo video per scope (5 videos, ≤50MB each)
- Scope justification doc for App Review
- Bundle ID `com.weareinformal.envi` registered as allowed
- Post-approval: delete sandbox target users, archive sandbox app

---

## Verification

- [ ] `xcodebuild test -scheme ENVI` passes (unit only)
- [ ] `npm test` in /functions passes
- [ ] Manual integration test → `PublishStatus.posted` + video visible in sandbox tester inbox
- [ ] `TikTokSandboxErrorView` displayed when non-allowlisted account auths in staging
- [ ] Phase 8 committed

---

## Open Questions

1. Exact TikTok error code for sandbox user rejection — must capture empirically during 08-05
2. `video.upload`-only sufficient for App Review, or is `video.publish` required?
3. Sandbox progression to `PUBLISH_COMPLETE` vs stopping at `SEND_TO_USER_INBOX` — affects 08-06 assertion
4. Phase 7 `ProviderOAuthAdapter` final signature
5. Phase 12 `publishJobs` collection vs Phase 8's `publishes` subcollection
