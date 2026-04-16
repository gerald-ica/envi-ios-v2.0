# Secret Rotation Checklist — v1.1 Social Connectors

**Owner:** Platform / Security
**Cadence:** On-demand (incident) + quarterly scheduled
**Last incident:** 2026-04-16 — all 8 provider secrets shared in plaintext in a planning conversation. Rotation is a blocker for flipping `SocialOAuthManager.useMockOAuth = false`.

This checklist is the source of truth for rotating every OAuth/Graph secret stored in Google Secret Manager. Every rotation must be logged in `.planning/STATE.md` under "Accumulated Context" with the date and the last 4 of the new secret for traceability.

## Pre-flight

- [ ] Confirm you can `gcloud auth login` as a principal with `roles/secretmanager.admin` on the target project (`envi-by-informal-staging` or prod project, TBD).
- [ ] Confirm the Functions runtime service account has `roles/secretmanager.secretAccessor` on every secret (run `./scripts/provision-secrets.sh --project <id> --service-account <sa>` to refresh bindings).
- [ ] Notify on-call: rotations can trigger a 60–120 second window where in-flight OAuth exchanges fail as containers hot-cycle.

## Canonical secret names

Must match `functions/src/lib/secrets.ts` exactly.

| # | Secret name | Provider console | Rotate action |
|---|---|---|---|
| 1 | `staging-tiktok-sandbox-client-secret` | TikTok Developer Portal → ENVI-SANDBOX app → Basic Info → Reset | Generate new client secret, version in SM |
| 2 | `staging-x-oauth1-consumer-secret` | X Developer Portal → App → Keys & tokens → Consumer Keys → Regenerate | Regenerate, version in SM |
| 3 | `staging-x-oauth1-access-token-secret` | X Developer Portal → App → Keys & tokens → Access Token → Regenerate | Regenerate, version in SM |
| 4 | `staging-x-bearer-token` | X Developer Portal → App → Keys & tokens → Bearer Token → Regenerate | Regenerate, version in SM |
| 5 | `staging-x-oauth2-client-secret` | X Developer Portal → App → Keys & tokens → OAuth 2.0 Client Secret → Regenerate | Regenerate, version in SM |
| 6 | `staging-meta-app-secret` | Meta for Developers → App `1233228574968466` → Settings → Basic → App Secret → Reset | Reset, version in SM |
| 7 | `staging-envi-threads-app-secret` | Meta for Developers → App `1649869446444171` → Settings → Basic → App Secret → Reset | Reset, version in SM |
| 8 | `staging-threads-app-secret` | Meta for Developers → App `1604969460421980` → Settings → Basic → App Secret → Reset | Reset, version in SM |
| 9 | `staging-instagram-app-secret` | Meta for Developers → App `1811522229543951` → Settings → Basic → App Secret → Reset | Reset, version in SM |
| 10 | `staging-instagram-client-token` | Meta for Developers → App `1811522229543951` → Settings → Advanced → Client Token → Reset | Reset, version in SM |
| 11 | `staging-linkedin-primary-client-secret` | LinkedIn Developer Portal → App `86geh6d7rzwu11` → Auth tab → Primary Client Secret → Generate new | Generate new, disable old after confirm, version in SM |

## Per-secret rotation procedure

For each row in the table:

1. [ ] Open the provider console in a new incognito window (do not re-use cached sessions).
2. [ ] Trigger "Regenerate" / "Reset" / "Generate new" on the target secret.
3. [ ] Copy the NEW value into a password manager entry named `envi-<secret>-YYYYMMDD`. Never paste it anywhere else.
4. [ ] Add a new Secret Manager version:
   ```
   printf "%s" "<new-value>" | gcloud secrets versions add <secret-name> \
     --project <project-id> \
     --data-file=-
   ```
5. [ ] Verify: `gcloud secrets versions access latest --secret <secret-name> --project <project-id>` returns the new value.
6. [ ] Disable the previous version once the Functions deploy has hot-cycled (~10 min) and a smoke test OAuth flow succeeds:
   ```
   gcloud secrets versions disable <previous-version-number> --secret <secret-name> --project <project-id>
   ```
7. [ ] Delete the password manager entry after 7 days if no incident requires the legacy value.

## Verification

- [ ] Functions log shows no `SecretNotFoundError` for any provider in the 30 minutes after rotation.
- [ ] At least one connect flow per provider completes successfully end-to-end.
- [ ] Record rotation completion in `.planning/STATE.md` under "v1.1 decisions":
  ```
  - YYYY-MM-DD: Rotated all 11 staging secrets. Last 4 of new values recorded in 1Password vault `envi-connector-secrets`.
  ```

## 2026-04-16 incident record

- **Trigger:** Secrets pasted in plaintext during planning chat.
- **Affected:** All 8 provider secrets listed in `.planning/ROADMAP.md` v1.1 section (TikTok, X, Meta, Threads, Instagram, LinkedIn).
- **Rotation status:** **PENDING** — blocker for Phase 7 deploy. Must complete every row above before `useMockOAuth = false`.
- **Completed by:** _pending_
- **Completed on:** _pending_
- **Verified by:** _pending_
