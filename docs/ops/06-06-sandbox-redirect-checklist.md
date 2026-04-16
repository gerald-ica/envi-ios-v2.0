# Sandbox OAuth Redirect URI Registration Checklist

**Phase:** 06-06
**Goal:** Register `enviapp://oauth-callback/{provider}` with every provider's developer console so the `ASWebAuthenticationSession` callback round-trip completes.

This is a **human-gated** deliverable. The broker will not complete a code exchange until each redirect URI below is saved in the provider's console. Tick the box only after the provider console UI confirms save success (most show a toast or require a "Save changes" button press).

## Bundle ID in scope

`com.weareinformal.envi.staging`

## Callback URL scheme (from `ENVI/Resources/Info.plist`)

- Scheme: `enviapp`
- Host: `oauth-callback`
- Path: `/{provider}` where `{provider}` is the `SocialPlatform.apiSlug`.

## Per-provider registration

| # | Provider | Sandbox URI to register | Console location | Notes | Done |
|---|---|---|---|---|---|
| 1 | **TikTok (ENVI-SANDBOX)** | `enviapp://oauth-callback/tiktok` | TikTok Developer Portal → App `sbaw4c49dgx7odxlai` → Login Kit → **Redirect URI** | Sandbox tab. Also add yourself under **Sandbox → Target Users** — only whitelisted accounts can complete auth. | [ ] |
| 2 | **X (Twitter)** | `enviapp://oauth-callback/x` | X Developer Portal → Project → App → **User authentication settings** → Edit → **Callback URI / Redirect URL** | For OAuth 2.0 flow with Client ID `WC12UFNnY05NU3BDNEtKdHdQUDE6MTpjaQ`. OAuth 1.0a retains its own callback field in the same pane. | [ ] |
| 3 | **Facebook (Meta)** | `enviapp://oauth-callback/facebook` | Meta for Developers → App `1233228574968466` → **Facebook Login for Business** → **Settings** → **Valid OAuth Redirect URIs** + **Advanced → iOS → Bundle ID** (`com.weareinformal.envi.staging`) | Meta validates BOTH the redirect URI and the bundle ID. Add both or the app will fail to exchange. | [ ] |
| 4 | **Instagram** | `enviapp://oauth-callback/instagram` | Meta for Developers → App `1811522229543951` → **Instagram Graph API** → **Basic Display** → **Valid OAuth Redirect URIs** | Confirm the app has an Instagram Business or Creator test account attached. Personal accounts will not work in sandbox. | [ ] |
| 5 | **Threads** | `enviapp://oauth-callback/threads` | Meta for Developers → App `1604969460421980` → **Threads API** → **Redirect URIs** | Threads API is still gated; confirm app is approved for `threads_basic` + `threads_content_publish`. Fall back to Envi-Threads parent app `1649869446444171` if standalone app isn't approved yet. | [ ] |
| 6 | **LinkedIn** | `enviapp://oauth-callback/linkedin` | LinkedIn Developer Portal → App `86geh6d7rzwu11` → **Auth** tab → **Authorized redirect URLs for your app** | Requires full URL including the `enviapp://` scheme. LinkedIn requires exact match; no wildcards. | [ ] |

## Cross-cutting verification

- [ ] Each URI is saved with EXACT casing as shown above (`enviapp` lowercase, provider slug lowercase).
- [ ] Each provider console shows the redirect URI as "saved" / "approved" / "allowed".
- [ ] `CFBundleURLTypes` in `ENVI/Resources/Info.plist` includes `<string>enviapp</string>` under `CFBundleURLSchemes` (verify with `plutil -p $(xcrun simctl get_app_container booted com.weareinformal.envi.staging app)/Info.plist | grep enviapp`).
- [ ] One manual end-to-end test per provider (Phase 8+) landed back in app without a "Redirect URI mismatch" error.

## Provider-specific follow-ups

### TikTok Sandbox → Prod promotion (Phase 8)

Before flipping from sandbox to prod:
1. Add the prod redirect URI (same format, different TikTok app) to the production TikTok app.
2. Submit app for TikTok Login Kit review with screenshots of the ENVI connect flow.
3. Update `SocialOAuthManager` provider configuration to point at prod app id.

### Meta OAuth redirect URI — gotcha

Meta enforces the redirect URI in TWO places:
1. "Valid OAuth Redirect URIs" under Facebook Login / Instagram Graph settings.
2. "Bundle ID" under **Settings → Advanced → iOS**.

If either is missing, token exchange succeeds but the iOS SDK side will refuse the response.

### LinkedIn — app review

For `w_member_social` (post on behalf of a member) scope, LinkedIn requires submitting the app for review with a demo account and a public-facing site that uses the "Sign in with LinkedIn" button. This is a Phase 11 blocker, not Phase 6.

## Rollback

If a redirect URI registration breaks an existing prod integration (unlikely — all work here is on sandbox apps) — revert via the same console; providers keep edit history.

## Sign-off

- Registered by: _________
- Date: _________
- Verified by: _________
