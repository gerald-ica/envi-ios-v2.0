# TikTok Production Promotion Checklist

Phase 08 ships ENVI against TikTok's **sandbox**. This doc enumerates the
steps required to move TikTok from sandbox to production — i.e., so any
end-user can connect their TikTok, not just a pre-approved allowlist.

All sandbox-specific code paths are behind
`AppEnvironment.current == .staging` / `getConnectorEnv() === "sandbox"`, so
the promotion is primarily an App Review + credentials rotation process —
no iOS / Cloud Functions code changes are strictly required.

---

## 1. App Review prerequisites

TikTok requires App Review for each of our four scopes:

| Scope | Justification | Demo required? |
|---|---|---|
| `user.info.basic` | Display handle + follower count on Connections screen. | Yes — 30s demo video showing Connections screen. |
| `video.list` | Surface the user's recent TikToks inside ENVI's content gallery. | Yes — 30s demo of the gallery populated with real TikToks. |
| `video.upload` | Upload a video file to the user's inbox for manual publishing. | Yes — 45s demo of the publish flow: choose video, set caption, tap Publish, see inbox receipt on TikTok. |
| `video.publish` | Auto-publish (no manual tester step) once App Review approves. | Yes — 60s demo covering schedule + auto-publish + success confirmation. |

Each demo video must:
- Be ≤50 MB and ≤60s.
- Include captions / voice-over describing what scope is being exercised.
- Demonstrate the feature end-to-end within ENVI, not just a mock.
- Use a dedicated `demo@weareinformal.com` test account on both ENVI + TikTok.

See `/docs/tiktok-scope-justifications.md` (create alongside submission) for
the written justification TikTok requires for each scope.

---

## 2. TikTok developer portal

1. Log in at <https://developers.tiktok.com/> with the ENVI-shared developer
   account (see 1Password entry "TikTok Developer").
2. Duplicate the sandbox app via **Configure → Create App** or click
   **Promote to production** on the sandbox entry — same app, new credentials.
3. Set:
   - **App name:** ENVI
   - **App icon:** 1024×1024 PNG (matches App Store listing)
   - **Category:** Content creation / Lifestyle
   - **Redirect URI:** `https://us-central1-envi-by-informal-prod.cloudfunctions.net/oauth/tiktok/callback`
   - **iOS bundle ID allowlist:** `com.weareinformal.envi`
4. Submit the four scopes for review with the demo videos above.
5. Receive production `client_key` + `client_secret` — **never** commit
   either to the repo.

---

## 3. Secrets rotation

Follow the Phase 6-02 procedure
(`/docs/secrets-rotation.md`) to introduce the production secret without
redeploying:

```bash
# 1. Create the new secret version
gcloud secrets create prod-tiktok-client-secret \
  --project=envi-by-informal-prod \
  --data-file=./tiktok-prod-secret.txt

# 2. Grant Cloud Functions runtime SA access
gcloud secrets add-iam-policy-binding prod-tiktok-client-secret \
  --project=envi-by-informal-prod \
  --member="serviceAccount:envi-functions@envi-by-informal-prod.iam.gserviceaccount.com" \
  --role=roles/secretmanager.secretAccessor

# 3. Verify the function reads it
ENVI_CONNECTOR_ENV=prod GCLOUD_PROJECT=envi-by-informal-prod \
  npm --prefix functions run test -- --testPathPattern tiktok
```

The secret name is hard-coded in
`functions/src/providers/tiktok.ts#resolveClientSecretName()` so flipping
`ENVI_CONNECTOR_ENV=prod` is sufficient.

---

## 4. iOS app config

1. Update `ENVI/Core/Config/AppEnvironment.swift` production constants if the
   Cloud Functions base URL changes (it should remain
   `https://us-central1-envi-by-informal-prod.cloudfunctions.net`).
2. Ensure `FeatureFlags.shared.useTikTokConnector` Remote Config key returns
   `true` in prod (code default is already `true` in release).
3. Verify the production app has `enviapp` registered as a URL scheme
   (Info.plist → `CFBundleURLTypes`). Sandbox + prod share the same scheme,
   so this should already be in place from Phase 6-04.
4. Submit the next App Store build with an updated "App Review notes" entry
   explaining how a reviewer can exercise TikTok publishing (demo account
   + reviewer guide).

---

## 5. Cutover sequencing

Recommended order to minimize user impact:

1. **Day -14** — submit TikTok App Review with all four scope demos.
2. **Day -7**  — TikTok approval usually arrives. Rotate `prod-tiktok-client-secret`.
3. **Day -3**  — deploy Cloud Functions with `ENVI_CONNECTOR_ENV=prod`.
4. **Day  0**  — ship iOS release that flips `useTikTokConnector` default to
   `true` in prod (already the code default — just verify Remote Config
   isn't overriding it to `false`).
5. **Day +1**  — confirm first-party smoke test: connect, publish, observe
   `PUBLISH_COMPLETE` state in Firestore.
6. **Day +7**  — delete the sandbox allowlist (TikTok portal → Sandbox tab →
   remove all target users). Archive the sandbox app.
7. **Day +14** — delete staging-only `TikTokSandboxErrorView` presentation
   branch in `SocialOAuthManager` (it's a no-op in prod anyway, but the
   dead code should go).

---

## 6. Post-cutover verification

- [ ] Real (non-tester) TikTok account can connect end-to-end.
- [ ] `PlatformConnection.handle` shows the user's display name.
- [ ] `TikTokConnector.listVideos` returns non-empty within an hour of
      connection.
- [ ] `TikTokConnector.publishVideo` reaches `PUBLISH_COMPLETE` terminal
      state without requiring a manual inbox tap.
- [ ] Firestore `users/{uid}/connections/tiktok` holds a valid
      `ConnectionDocument` with `followerCount` populated.
- [ ] Sandbox client secret version is disabled in Secret Manager
      (`gcloud secrets versions disable <v> --secret=staging-tiktok-sandbox-client-secret`).
- [ ] Crashlytics shows no spike in `TikTokConnectorError` events in the
      48 h following cutover.

---

## 7. Rollback

If anything regresses post-cutover, flip Remote Config
`useTikTokConnector=false` to drop users back onto the Phase 7 generic
broker path (which falls through to the mock in DEBUG / shows a generic
error in release). No deploy required.

For a deeper rollback (e.g., TikTok revokes production approval), disable
the prod secret version in Secret Manager — `exchangeCode` will throw,
surfaces as `OAuthError.connectionFailed` on iOS.
