---
phase: 10-meta-family-connector
milestone: v1.1 Real Social Connectors
type: execute
depends-on: 07-oauth-broker-service
app-ids:
  meta-fb: "1233228574968466"
  envi-threads-parent: "1649869446444171"
  threads-standalone: "1604969460421980"
  instagram-graph: "1811522229543951"
  instagram-client-token: "3bb10460a0360e4adcdfc98609ae0cb0"
---

# Phase 10 — Meta Family Connector

**Goal:** Shared MetaGraphConnector base brokering OAuth + token lifecycle for Facebook Pages, Instagram Business/Creator, and Threads under 3 distinct App IDs. Per-platform publish adapters, Cloud Function meta plugin, PageSelectorView modal, 50-day refresh cron, `SocialPlatform.facebook` enum addition.

**API hosts:**
- FB + IG Graph: `https://graph.facebook.com/v21.0`
- Threads: `https://graph.threads.net/v1.0` (**different host**)

**Key constraints:**
- IG Content Publishing requires Business/Creator account linked to FB Page
- FB Login for Business required for Pages (2024+)
- Long-lived tokens: 60-day expiry; refresh via `fb_exchange_token` grant before expiry or user must reauth
- `w_member_social` self-serve; `w_organization_social` requires MDP approval (not applicable here; LinkedIn-specific — Meta has its own review)
- Page tokens are per-Page + don't expire; stored separately from user tokens

---

## Tasks

### Task 1 — `SocialPlatform.facebook` enum + 11 switch sites

Add `case facebook = "Facebook"` between `.instagram` and `.tiktok`. Add arms to switches in:

1. `ENVI/Models/Platform.swift` (iconName → `"f.square"`, brandColor → `#1877F2`, 2 switches)
2. `ENVI/Core/Auth/SocialOAuthManager.swift` (mockHandle, mockScopes → `["pages_show_list","pages_manage_posts","pages_read_engagement"]`)
3. `ENVI/Features/Modals/Export/ExportComposer.swift`
4. `ENVI/Features/Modals/Editor/EditorViewController.swift`
5. `ENVI/Features/Auth/OnboardingViewModel.swift`
6. `ENVI/Models/ContentPiece.swift`
7. `ENVI/Models/CommunityModels.swift`
8. `ENVI/Models/AgencyModels.swift`
9. `ENVI/Features/Modals/Search/AdvancedSearchView.swift`
10. `ENVI/Features/HomeFeed/Library/LibraryViewModel.swift`

Add `FeatureFlags.canConnectFacebook: Bool = false` (FB requires App Review before prod).

**Decision:** Facebook is a first-class case (not sub-feature of `.meta`). `SocialOAuthManager` routes by `apiSlug`; shared code lives in `MetaGraphConnector` + `meta.ts`, not in the enum.

### Task 2 — `MetaGraphConnector.swift` base class

`ENVI/Core/Connectors/MetaGraphConnector.swift` — open class, `ObservableObject`:

```swift
internal enum MetaPlatform {
    case facebook(appID: String)
    case instagram(appID: String, clientToken: String)
    case threads(appID: String)
}

open class MetaGraphConnector: ObservableObject {
    let metaPlatform: MetaPlatform
    @Published var connection: PlatformConnection?
    var baseGraphURL: URL { /* graph.facebook.com default; Threads overrides */ }
    func connect(presentationAnchor: ASPresentationAnchor) async throws -> PlatformConnection
    func disconnect() async throws
    func refreshToken() async throws -> PlatformConnection
}
```

No secrets embedded. App IDs are public identifiers.

### Task 3 — `FacebookConnector.swift`

Subclasses MetaGraphConnector with `.facebook(appID: "1233228574968466")`.

Scopes: `pages_show_list`, `pages_manage_posts`, `pages_read_engagement`, `public_profile`.

Post-OAuth Page selection:
- Broker calls `GET /me/accounts` via `GET /meta/pages` CF route → returns `[MetaPage]`
- PageSelectorView (Task 7) → user picks Page
- Firestore stores `selectedPageId`, per-Page access token encrypted

Publish:
```swift
enum FacebookMediaType: String { case text, photo, video }
func publishPost(caption: String, mediaURL: URL?, mediaType: FacebookMediaType) async throws -> PublishTicket
```
Delegates to broker `POST /publish/jobs` with `platform: "facebook"`. Broker calls `POST /{pageId}/feed` or `/videos` with Page access token.

### Task 4 — `InstagramConnector.swift`

Subclasses with `.instagram(appID: "1811522229543951", clientToken: "3bb10460a0360e4adcdfc98609ae0cb0")`.

Client token is safe to ship in iOS binary (app-level, not user secret).

Scopes: `instagram_basic`, `instagram_content_publish`, `pages_read_engagement`, `pages_show_list`.

Account-type detection (server-side):
- Broker `GET /{ig-user-id}?fields=account_type,username,media_count`
- If `PERSONAL`: store `accountTypeError = "personal_account"`, iOS throws `InstagramConnectorError.personalAccount`

Publish (all server-side via broker):
```swift
enum IGMediaType: String { case image, video, reel }
struct IGCarouselItem { let mediaURL: URL; let mediaType: IGMediaType }
enum InstagramConnectorError: Error { case personalAccount, noLinkedPage, containerCreationFailed, publishTimeout }

func publishSingleMedia(caption: String, mediaURL: URL, mediaType: IGMediaType) async throws -> PublishTicket
func publishCarousel(caption: String, mediaItems: [IGCarouselItem]) async throws -> PublishTicket  // max 10
func publishReel(caption: String, videoURL: URL) async throws -> PublishTicket
```

Broker flow: POST `/{ig-user-id}/media` (container) → poll `status_code` until FINISHED (1/min, max 5) → POST `/{ig-user-id}/media_publish`.

### Task 5 — `ThreadsConnector.swift`

Subclasses with `.threads(appID: "1604969460421980")`.

**CRITICAL:** Override `baseGraphURL` to `"https://graph.threads.net/v1.0"`.

Scopes: `threads_basic`, `threads_content_publish`, `threads_manage_replies`.

Text limit: 500 chars (enforce client-side, throw `textTooLong`).

```swift
enum ThreadsMediaType: String { case image, video }
struct ThreadsCarouselItem { let mediaURL: URL; let mediaType: ThreadsMediaType }
enum ThreadsConnectorError: Error { case textTooLong(Int), carouselTooFewItems, carouselTooManyItems }

func publishText(text: String) async throws -> PublishTicket
func publishMedia(text: String?, mediaURL: URL, mediaType: ThreadsMediaType) async throws -> PublishTicket
func publishCarousel(text: String?, items: [ThreadsCarouselItem]) async throws -> PublishTicket  // 2-20 items
```

Broker flow: POST `/{threads-user-id}/threads` (media_type=TEXT/IMAGE/VIDEO/CAROUSEL) → wait ~30s → POST `/{threads-user-id}/threads_publish`.

### Task 6 — `/functions/src/providers/meta.ts`

Single plugin, branches on `MetaSubPlatform = "facebook" | "instagram" | "threads"`.

```typescript
class MetaProvider implements OAuthProvider {
  constructor(subPlatform: MetaSubPlatform)
  getAuthorizationURL(state, codeVerifier): string
  exchangeCode(code, codeVerifier): Promise<TokenSet>
  refreshToken(uid, platform): Promise<{needsReauth?: boolean, tokens?: TokenSet}>
  getPages(uid): Promise<MetaPage[]>  // FB-only; GET /me/accounts
  detectIGAccountType(uid): Promise<{accountType: "BUSINESS"|"MEDIA_CREATOR"|"PERSONAL", username, mediaCount}>
  publishFacebookPost(uid, pageId, payload): Promise<string>
  publishInstagramMedia(uid, payload): Promise<string>
  publishThreadsPost(uid, payload): Promise<string>
}
```

**Secret Manager lookups** (not hardcoded):
- FB: `meta-app-secret`
- IG: `instagram-app-secret`
- Threads: `threads-app-secret`

**Auth URLs:**
- FB/IG: `https://www.facebook.com/dialog/oauth` with respective `client_id`
- Threads: `https://threads.net/oauth/authorize` with client_id=`1604969460421980`

**Token exchange:**
- FB/IG: POST `https://graph.facebook.com/oauth/access_token` (short-lived) → exchange for long-lived via `fb_exchange_token` grant → store `expiresAt = now + 60d`
- Threads: POST `https://graph.threads.net/oauth/access_token` → exchange for long-lived → `expiresAt = now + 60d`

**Refresh:** If expired, return `{needsReauth: true}`. If valid, GET `/oauth/access_token?grant_type=fb_exchange_token&...` → reset `expiresAt`.

Routes registered in `functions/src/index.ts`:
- `GET /meta/pages` → `MetaProvider("facebook").getPages`
- `POST /meta/ig-account-type` → `MetaProvider("instagram").detectIGAccountType`

### Task 7 — `PageSelectorView.swift` (SwiftUI)

`ENVI/Features/Connectors/Meta/PageSelectorView.swift` + `PageSelectorViewModel.swift`.

Sheet presented after FB OAuth, before connection finalized:
- Title: "Choose a Facebook Page"
- List of `MetaPageItem` with checkmark selection
- "Continue" button → `POST /oauth/facebook/select-page` with `pageId`
- Loading skeleton + error retry state
- "I don't have a Page" link → `https://www.facebook.com/pages/create`

### Task 8 — `InstagramAccountTypeErrorView.swift`

Full-screen error view when `InstagramConnectorError.personalAccount` or `.noLinkedPage`:
- `.personalAccount`: "Professional Instagram Account Required" + "Learn How to Switch" link to `https://help.instagram.com/502981923235522`
- `.noLinkedPage`: "Link Your Instagram to a Facebook Page" + link to `https://help.instagram.com/176235449218188`
- "Try a Different Account" → re-trigger OAuth

### Task 9 — `refreshMetaTokens.ts` cron

`functions/src/crons/refreshMetaTokens.ts` — `onSchedule("every 50 days")`.

Query Firestore for Meta connections expiring in ≤15 days. For each:
- Call `MetaProvider(subPlatform).refreshToken(uid, platform)`
- Success: update `expiresAt = now + 60d`, `lastRefreshedAt`
- `needsReauth: true`: set `tokenStatus = "expired"`, FCM push: "Your [Platform] connection needs renewal"

Concurrency cap 10 to respect Graph API rate limits.

**Note:** Phase 12 adds a global cron — open question whether to merge or keep separate.

### Task 10 — App ID strategy doc

`.planning/phases/10-meta-family-connector/10-08-appid-strategy.md`:

**Decision:** Keep all 4 App IDs separate. Each is a distinct Meta dev app with separately approved permissions. Merging = reapply for all permissions under one app = more App Review risk. Complexity absorbed in `meta.ts` alone.

App ID roles:
- `1649869446444171` (Envi-Threads-parent): Graph app owning Threads app group; Secret Manager key discriminator for Threads; NOT OAuth `client_id`
- `1233228574968466` (FB): OAuth `client_id` for FB; secret `meta-app-secret`
- `1604969460421980` (Threads standalone): OAuth `client_id` for Threads at `threads.net/oauth/authorize`; secret `threads-app-secret`
- `1811522229543951` (IG Graph): OAuth `client_id` for IG; secret `instagram-app-secret`; client token ships in iOS binary

---

## Verification

- [ ] `swift build` — 0 exhaustive-switch errors
- [ ] `npm run build && npm test` in /functions — passes
- [ ] Firebase emulator: `refreshMetaTokens` cron fires against mock data
- [ ] No secrets in any `.swift` file (App IDs + client token only)
- [ ] `FeatureFlags.canConnectFacebook == false`
- [ ] `ThreadsConnector.baseGraphURL` returns `graph.threads.net` path
- [ ] `SocialPlatform.facebook` present in all 11 switch sites (grep verify)

## Open Questions

1. Phase 12 global refresh cron: merge `refreshMetaTokens` or keep separate?
2. Role of `1649869446444171` — confirm with Meta support (currently Secret Manager discriminator only)
3. `pages_manage_posts` requires FB App Review — gate behind `canConnectFacebook` flag until approved
