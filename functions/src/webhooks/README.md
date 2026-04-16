# Publish Webhooks

Phase 12-05. Only Meta-family providers (Facebook Pages + Instagram) offer
per-post webhook subscriptions today. This directory hosts those two
receivers plus this gap document for the remaining providers.

## Receivers

| Provider  | File          | Trigger                      | Reconciles     |
| --------- | ------------- | ---------------------------- | -------------- |
| Instagram | `instagram.ts`| `entry[].changes[].value`    | `media_id`     |
| Facebook  | `facebook.ts` | `entry[].changes[].value`    | `post_id`      |

Both receivers:

1. Respond to Meta's GET `hub.mode=subscribe` verification by echoing
   `hub.challenge` iff `hub.verify_token` matches Secret Manager
   `meta-webhook-verify-token`.
2. On POST, match `providerPostId` against
   `publish_jobs.platforms[platform].providerPostId` and write the new
   per-platform status, then re-derive the top-level `status` in a
   transaction.
3. Never read or store PII beyond what's already in the publish job doc.

## Gap providers

### TikTok

TikTok exposes webhooks for Login Kit / Content Posting events, but only
for approved partners on the enterprise tier. Our sandbox credentials don't
qualify. Until we upgrade:

- **Reconciliation strategy**: client polls `publish_jobs/{jobId}` via the
  existing Firestore listener. The Phase 8 TikTok worker writes
  `posted` / `failed` synchronously after `pollUntilComplete` finishes, so
  the client sees terminal state within ~60s of publish.
- **Phase 13 supplement**: nightly analytics sync pulls the user's recent
  video list via the v2 `/video/list/` endpoint and reconciles any
  provider-side deletions that occurred after our initial publish.

### X (Twitter)

X's Account Activity API is v1.1-only and our connector is v2. Bridging
them requires the dormant OAuth 1.0a credentials (see `providers/x.ts`
v1.1 retention note) AND a separate app-level webhook registration that
can't be done programmatically.

- **Reconciliation strategy**: same as TikTok — worker writes terminal
  state, client polls Firestore. Rate-limit retries are already tracked
  via the `x-rate-limit-reset` handling in `workers/xWorker.ts`.
- **Phase 13 supplement**: nightly sync pulls `/2/users/me/tweets` and
  cross-references against `platforms.x.providerPostId` to catch deletes.

### LinkedIn

LinkedIn offers no webhook surface for member posts. Organisation-level
events are exposed via the "Organisation Look-up API" but require the
`r_organization_social` scope and a moderation approval we don't hold.

- **Reconciliation strategy**: none. Worker success is authoritative;
  post-level deletes are silently missed until Phase 13 nightly sync
  fetches `/rest/posts/{urn}` and marks `status: "deleted"`.

## Operational notes

- Both Meta receivers must be registered in the Meta App Dashboard's
  **Webhooks** tab. The callback URL is the Cloud Functions HTTPS trigger
  (region-prefixed). Phase 12 ships the receivers; registration is a
  manual console step tracked in `.planning/STATE.md` deployment checklist.
- The verify token lives in Secret Manager under the key
  `meta-webhook-verify-token`. Rotate by writing a new version; the
  receivers fetch on every GET (no caching).
- Signed POSTs: Meta sends `X-Hub-Signature-256: sha256=<hmac>`. Phase 12
  does NOT yet verify the HMAC — the current receivers accept any POST
  matching the body shape. A follow-up ticket tightens this to HMAC
  verification before public launch.
