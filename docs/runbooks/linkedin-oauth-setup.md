# LinkedIn OAuth Setup — Runbook

**Phase:** 11 — LinkedIn Connector (v1.1 Real Social Connectors)
**Verified:** 2026-04-16
**Owner:** Platform / OAuth Broker

---

## TL;DR

LinkedIn OAuth uses 3-legged authorization_code. Member scopes
(`r_liteprofile`, `w_member_social`) are self-serve; org scopes
(`r_organization_social`, `w_organization_social`) require Marketing
Developer Platform (MDP) approval via email form. Access tokens last 60
days and there is **no refresh endpoint and no revocation endpoint** —
we force a reauth on expiry and delete the Firestore row on disconnect.
All REST API calls must pin `Linkedin-Version: 202505` (versions ≤
202504 are already sunset as of 2026-04).

---

## 1. LinkedIn Developer Portal — App Setup

1. Sign in to <https://www.linkedin.com/developers/apps> with the
   `developer@weareinformal.com` identity (SSO through the shared ENVI
   account).
2. **Create App**:
   - App name: `ENVI — Staging` (prod app created after MDP approval).
   - LinkedIn Page: `ENVI`.
   - Privacy policy URL: `https://envi.app/privacy`.
   - Logo: 240 × 240 PNG from `Design/Brand/`.
3. Record the generated **Client ID** (already pinned in
   `functions/src/providers/linkedin.ts` → `LINKEDIN_CLIENT_ID =
   "86geh6d7rzwu11"`).
4. **Auth → Redirect URLs**, add:
   - `enviapp://oauth-callback/linkedin` (iOS deep link)
   - `https://<region>-<project>.cloudfunctions.net/oauthCallback/linkedin`
     (broker universal-link fallback)
5. **Auth → Scopes**, confirm checked:
   - `r_liteprofile` ✅ (member-tier, self-serve)
   - `w_member_social` ✅ (member-tier, self-serve)

---

## 2. Secret Provisioning

The client secret is loaded at runtime from Google Secret Manager under
the canonical name declared in `functions/src/lib/secrets.ts`:

```
staging-linkedin-primary-client-secret
```

**Never check the secret into the repo or the iOS binary.**

To rotate / re-provision:

```bash
# From the repo root, assumes gcloud is authed as the staging owner.
echo -n "<paste-from-linkedin-dev-portal>" | \
  gcloud secrets versions add staging-linkedin-primary-client-secret \
    --data-file=- \
    --project=envi-by-informal-staging
```

After rotating, restart the Cloud Functions containers so the module
cache clears (or wait up to ~10 minutes for natural recycling):

```bash
gcloud run services update oauthCallback \
  --region=us-central1 \
  --project=envi-by-informal-staging \
  --clear-env-vars=__ROTATE
```

Rotation cadence: LinkedIn does not enforce rotation, but our internal
policy (`docs/ops/secret-rotation-checklist.md`) mandates a quarterly
rotation on the first Monday of Jan / Apr / Jul / Oct.

---

## 3. Marketing Developer Platform (MDP) Approval — **HARD BLOCKER**

Organization-tier scopes (`r_organization_social`,
`w_organization_social`) cannot be toggled in the portal UI. They
require explicit approval via LinkedIn's Marketing Developer Platform
process:

1. Email `developer-programs@linkedin.com` from a verified company
   domain with subject `MDP Access Request — ENVI`.
2. Include:
   - App Client ID: `86geh6d7rzwu11`
   - Use case description (see boilerplate below).
   - Screenshots of the in-app author picker (the "Unlock company
     pages" flow — `ENVI/Features/Publishing/LinkedInAuthorPickerView.swift`).
   - Privacy policy URL + data retention commitment.
3. Expected turnaround: **1–5 business days**. Watch the case tracker
   email for follow-up questions (they often ask for OAuth consent
   screenshots).

**Until approval lands, `r_organization_social` / `w_organization_social`
cannot be requested — the adapter requests only member scopes by
default and the iOS author picker shows a locked "Unlock company pages"
row that surfaces a friendly "pending approval" message.**

Boilerplate use-case copy is maintained in
`docs/ops/OAUTH_SCOPE_POLICY.md` under "LinkedIn MDP submission".

---

## 4. API Version Pinning — `Linkedin-Version: 202505`

Every call to `https://api.linkedin.com/rest/*` must carry:

```http
Authorization: Bearer <access_token>
Linkedin-Version: 202505
X-Restli-Protocol-Version: 2.0.0
Content-Type: application/json
```

The constant `LINKEDIN_API_HEADERS` in
`functions/src/providers/linkedin.ts` is the single source of truth. Do
**not** replicate the string.

**Sunset policy:** LinkedIn sunsets versions approximately 12 months
after release. As of 2026-04-16, versions ≤ `202504` are already
rejected with HTTP 426. Calendar a review on **2027-04-01** to bump
pin. Bump procedure:

1. Read the LinkedIn changelog at
   <https://learn.microsoft.com/linkedin/marketing/versioning> and pick
   the latest non-sunset YYYYMM.
2. Update `LINKEDIN_API_HEADERS["Linkedin-Version"]` in `linkedin.ts`.
3. Run `grep -r "202505" functions/src/` and verify 0 hits after edit
   (the constant should be the only reference).
4. Run the contract tests in `functions/src/providers/linkedin.test.ts`
   + `linkedin-publish.test.ts`.
5. Canary deploy to staging, watch 24 h of logs for 426 responses.
6. Promote to prod.

---

## 5. `ugcPosts` is Dead — Use `/rest/posts`

LinkedIn sunset the UGC Posts endpoint in **June 2023**. Any code
reference to `ugcPosts` is a bug.

Verification:

```bash
grep -r "ugcPosts" functions/
# expected: 0 hits
```

Posts API surface used by this phase (all on `https://api.linkedin.com`):

| Endpoint | Purpose |
|---|---|
| `POST /rest/posts` | Create a text / media post |
| `POST /rest/images?action=initializeUpload` | Step 1 of image upload |
| `PUT <presignedUrl>` | Step 2 of image upload (no auth header!) |
| `POST /rest/videos?action=initializeUpload` | Step 1 of video upload |
| `PUT <presignedUrl>` | Step 2 of video upload (per 4MB part) |
| `POST /rest/videos?action=finalizeUpload` | Step 3 of video upload |
| `GET /rest/videos/{encodedUrn}` | Step 4: poll processing status |

---

## 6. Token Lifecycle — No Refresh, No Revocation

LinkedIn's defaults for the Posts API product tier:

- **Access token TTL:** 60 days (5,184,000 seconds). Stored in the
  `expiresAt` field on `users/{uid}/connections/linkedin`.
- **Refresh token:** **not issued** (contrast Google / TikTok / X v2).
  Phase 12's refresh cron (`functions/src/crons/refreshLinkedInTokens.ts`
  — not yet implemented) will flag connections expiring within 7 days
  and surface a reauth prompt in the iOS app via the existing
  `requiresReauth` field.
- **Revocation endpoint:** **none exists**. `disconnect()` deletes the
  Firestore row so the token is unreachable from ENVI, but the token
  itself continues to live out its TTL on LinkedIn's side. This is
  documented behavior — see `linkedInAdapter.revoke()` in
  `functions/src/providers/linkedin.ts` (logs a warning, otherwise
  no-op).

Implications:

- **Force reauth on expiry** is the only token-refresh path. The iOS
  `LinkedInConnectorError.notConnected` / `.token_expired` surfaces route
  the user back through `LinkedInConnector.connect()`.
- **Monitor disconnect events** — if a user reports a leaked token
  concern, escalate to LinkedIn developer support because we cannot
  revoke server-side.

---

## 7. Phase 12 Handoff

Phase 12 (refresh cron + publish job schema) should:

1. Add a scheduled job `refreshLinkedInTokens` that runs nightly,
   scans connections with `expiresAt < now + 7d` AND `provider =
   "linkedin"`, and writes `requiresReauth: true` to the connection
   doc. (LinkedIn cannot be refreshed programmatically; this is a
   pure UI-signal path.)
2. When the iOS app reads the connection status (via `oauth/linkedin/status`)
   and sees `requiresReauth: true`, surface a banner routing back into
   `LinkedInConnector.connect()`.
3. Harmonize the publish-job doc schema with the `postUrn` returned by
   `publishLinkedIn` (currently echoed as `jobID` as a stop-gap).

---

## 8. Local / Staging Verification Checklist

Run before signing off a LinkedIn-touching PR:

- [ ] `grep -r "ugcPosts" functions/` returns 0 hits.
- [ ] `grep -r "86geh6d7rzwu11" functions/src` only surfaces the client
      id in `providers/linkedin.ts` (never in tests as a hardcode,
      never in iOS sources).
- [ ] `grep -r "client_secret" functions/src` returns only the
      form-body composition in `providers/linkedin.ts` (no literal
      secret values).
- [ ] Jest suite `linkedin.test.ts` + `linkedin-publish.test.ts` green.
- [ ] Swift build of `LinkedInConnectorTests` green.
- [ ] MDP approval state logged in `.planning/STATE.md` (pending vs.
      approved vs. rejected).

---

## 9. Support Contacts

- LinkedIn Developer Support: <https://www.linkedin.com/help/linkedin/ask/api>
- MDP Application Status: <https://learn.microsoft.com/linkedin/marketing/>
- Internal owner for Phase 11: Platform / OAuth Broker squad.
