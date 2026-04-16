---
phase: 11-linkedin-connector
milestone: v1.1-real-social-connectors
type: execute
depends-on: 07-oauth-broker-service
client-id: 86geh6d7rzwu11
secret-ref: linkedin-primary-client-secret
---

# Phase 11 — LinkedIn Connector

**Goal:** LinkedIn OAuth 2.0 (3-legged) + Posts API (successor to deprecated UGC Posts, June 2023). Member + company-page author contexts. 3-step image upload + 4-step video multipart upload. SwiftUI author picker.

---

## API Reference (verified 2026-04-16)

### OAuth
- Auth: `GET https://www.linkedin.com/oauth/v2/authorization`
- Token: `POST https://www.linkedin.com/oauth/v2/accessToken` (form-urlencoded)
- Access token TTL: **60 days** (5184000s). No refresh tokens unless specifically enabled.
- No PKCE — state-only CSRF.
- No programmatic revocation endpoint — tokens expire naturally.

### Scopes
| Scope | Gate |
|---|---|
| `r_liteprofile` | Self-serve |
| `w_member_social` | Self-serve |
| `r_organization_social` | **MDP approval required** |
| `w_organization_social` | **MDP approval required** |

Marketing Developer Platform approval: email form, 1–5 business days. Blocks company-page features.

### Posts API (NOT ugcPosts — legacy post June 2023)
```
POST https://api.linkedin.com/rest/posts
Headers:
  Authorization: Bearer {token}
  Linkedin-Version: 202505        # YYYYMM; pin + review quarterly
  X-Restli-Protocol-Version: 2.0.0
  Content-Type: application/json
Response: 201 Created; post URN in header `x-restli-id`
```

Body shape:
```json
{
  "author": "{authorUrn}",
  "commentary": "{caption}",
  "visibility": "PUBLIC",
  "distribution": {
    "feedDistribution": "MAIN_FEED",
    "targetEntities": [],
    "thirdPartyDistributionChannels": []
  },
  "lifecycleState": "PUBLISHED",
  "isReshareDisabledByAuthor": false
}
```

Image/video add `"content": { "media": { "id": "{assetUrn}" } }`.

### Image upload (3-step)
1. `POST /rest/images?action=initializeUpload` with `{"initializeUploadRequest": {"owner": authorUrn}}` → `{uploadUrl, image: "urn:li:image:{id}", uploadUrlExpiresAt}`
2. `PUT {uploadUrl}` with raw bytes, `Content-Type: application/octet-stream`
3. Attach `urn:li:image:{id}` in post `content.media.id`

### Video upload (4-step + poll)
1. `POST /rest/videos?action=initializeUpload` with `{owner, fileSizeBytes, uploadCaptions: false, uploadThumbnail: false}` → `{video: "urn:li:video:{id}", uploadInstructions: [{uploadUrl, firstByte, lastByte}], uploadToken, uploadUrlsExpireAt}` (4MB parts)
2. `PUT {part.uploadUrl}` for each part, collect ETag headers in order
3. `POST /rest/videos?action=finalizeUpload` with `{finalizeUploadRequest: {video, uploadToken: "", uploadedPartIds: [etags]}}`
4. Poll `GET /rest/videos/{encodedUrn}` — states: `WAITING_UPLOAD → PROCESSING → AVAILABLE | PROCESSING_FAILED`; 2s backoff, 12 attempts max

Constraints: MP4 only, 3s–30min, 75KB–500MB.

### Company Pages
- `GET /rest/organizationAcls?q=roleAssignee&role=ADMINISTRATOR&state=APPROVED&count=100` → `elements[].organization` = array of org URNs
- `GET /rest/organizationsLookup?ids=List({id1},{id2})` → `localizedName`, `logoV2.cropped` (non-admin variant; no extra scope needed)

---

## Files to Create

### iOS
- `ENVI/Core/Connectors/LinkedInConnector.swift`:
  ```swift
  final class LinkedInConnector {
      static let shared = LinkedInConnector()
      static let memberScopes = ["r_liteprofile", "w_member_social"]
      static let orgScopes    = ["r_organization_social", "w_organization_social"]
      func connect() async throws -> PlatformConnection
      func publishPost(content: String, mediaPath: URL?, asOrganization: String?) async throws -> PublishTicket
      func fetchAdminOrganizations() async throws -> [LinkedInOrganization]
  }
  struct LinkedInOrganization: Identifiable, Codable {
      let id: String
      let urn: String
      let localizedName: String
      let logoImageUrn: String?
  }
  ```
  Two-phase connect: member scopes first, then org scopes upgrade on demand.
- `ENVI/Features/Publishing/LinkedInAuthorPickerView.swift` + `ViewModel`
- `docs/runbooks/linkedin-oauth-setup.md`

### Cloud Functions
- `/functions/src/providers/linkedin.ts` — OAuth plugin, `getAuthUrl`, `handleCallback`, `fetchMemberProfile`, `revokeToken` (logs warning, no endpoint), `fetchAdminOrganizations`
- `/functions/src/providers/linkedin-publish.ts` — `publishTextPost`, `publishImagePost` (3-step), `publishVideoPost` (4-step + poll)
- `/functions/src/publish/linkedin-dispatch.ts` — author URN resolution, member/org fork
- Test files: `linkedin.test.ts`, `linkedin-publish.test.ts`

---

## Sub-Plans

### 11-01  iOS adapter + scopes
Registers `enviapp://oauth-callback/linkedin` (Phase 6 base scheme covers). Two-phase connect. Mock path preserves existing `SocialOAuthManager.mockHandle` pattern.

Telemetry events: `linkedinConnectStarted/Completed/Failed`, `linkedinPublishStarted(authorType)`, `linkedinPublishCompleted(postUrn)`, `linkedinPublishFailed(error)`.

### 11-02  Cloud Function provider plugin
```typescript
export const linkedInProvider: OAuthProviderConfig = {
  provider: "linkedin",
  clientId: "86geh6d7rzwu11",
  authUrl: "https://www.linkedin.com/oauth/v2/authorization",
  tokenUrl: "https://www.linkedin.com/oauth/v2/accessToken",
  tokenGrantType: "authorization_code",
  scopes: ["r_liteprofile", "w_member_social"],
  redirectUri: process.env.LINKEDIN_REDIRECT_URI,
};
```

Secret loaded at runtime from Secret Manager: `linkedin-primary-client-secret`.

After token exchange: `GET /v2/me` → `personUrn = "urn:li:person:{id}"`, handle = `{firstName} {lastName}`.

Common headers constant:
```typescript
const LINKEDIN_API_HEADERS = {
  "Linkedin-Version": "202505",   // pin; TODO review 2027-04-01 (LinkedIn sunsets after ~12 months)
  "X-Restli-Protocol-Version": "2.0.0",
  "Content-Type": "application/json",
};
```

### 11-03  Posts API — text/image/video

**Text:**
```typescript
publishTextPost(accessToken, authorUrn, caption): Promise<string>
// POST /rest/posts with no content field; returns x-restli-id header
```

**Image:**
```typescript
publishImagePost(accessToken, authorUrn, caption, imageBuffer, mimeType): Promise<string>
// 1. initializeImageUpload → {uploadUrl, imageUrn, uploadUrlExpiresAt}
// 2. PUT uploadUrl with bytes (no Authorization; pre-signed)
// 3. createPost with content.media.id = imageUrn
```

**Video:**
```typescript
publishVideoPost(accessToken, authorUrn, caption, videoBuffer, fileSizeBytes): Promise<string>
// 1. initializeVideoUpload → {videoUrn, uploadInstructions[], uploadToken}
// 2. uploadVideoParts — PUT each part, collect ETags (preserve order)
// 3. finalizeVideoUpload with uploadedPartIds: [etags]
// 4. pollVideoStatus until AVAILABLE (2s × 12 attempts)
// 5. createPost with content.media.id = videoUrn
```

Error handling: if `uploadUrlExpiresAt < now+60s`, re-initialize once. On 409 Conflict from POST /rest/posts, retry once after 1s. Validate JPEG/PNG (images) and MP4 (video) before upload.

### 11-04  Author URN resolution

`/functions/src/publish/linkedin-dispatch.ts`:
```typescript
dispatchLinkedInPost(uid, payload: {
  caption: string,
  mediaType: "none"|"image"|"video",
  mediaStoragePath?: string,
  authorType: "member"|"organization",
  organizationUrn?: string
})
```

Flow:
1. Load token record (fail if missing/expired)
2. `resolveAuthorUrn`:
   - member → `tokenRecord.personUrn`
   - organization → validate `organizationUrn` in `tokenRecord.adminOrgUrns` cache
3. Download media from Cloud Storage if present
4. Route to `publishTextPost` / `publishImagePost` / `publishVideoPost`
5. Write result to Firestore publish job doc (Phase 12)

If member tries org post without `w_organization_social` scope: throw `ConnectorError.insufficientScopes` guiding reconnect.

### 11-05  LinkedInAuthorPickerView

`ENVI/Features/Publishing/LinkedInAuthorPickerView.swift` + `ViewModel`:
- Radio-style selector
- Row: `[avatar/logo] [displayName] [subtitle: Personal/Company Page] [checkmark]`
- If `w_organization_social` scope absent: show only member option + locked upgrade row
- Confirm → closure → dismiss

---

## Verification

- [ ] `swift build` 0 warnings on new files
- [ ] ENVITests/LinkedInConnectorTests pass in mock mode
- [ ] `/functions` build + tests green
- [ ] `Linkedin-Version: 202505` in all CF HTTP calls
- [ ] grep /functions for `ugcPosts` → 0 hits
- [ ] No client secret in iOS binary or functions source (grep literal value)
- [ ] Runbook docs MDP approval prerequisite + secret rotation
- [ ] `LinkedInAuthorPickerView` renders in Xcode preview

## Open Questions

1. MDP approval turnaround — blocks company-page features. Ship member-only first?
2. Org logo URL resolution (logoV2 is digitalmediaAsset URN, not direct URL) — defer to Phase 13
3. Deprecation review cadence for `Linkedin-Version` pin

## Key gotchas

- `ugcPosts` legacy post June 2023 — **must** use `/rest/posts`
- Org scopes gated behind MDP approval (hard blocker)
- No programmatic revocation endpoint — doc this limitation
- `Linkedin-Version` must be non-sunset YYYYMM (202504 and earlier already sunset as of 2026-04)
- `organizationAcls?q=roleAssignee` returns URNs only; `organizationsLookup` batch needed for names
- ETags from video part PUTs: preserve order, LinkedIn returns unquoted strings
