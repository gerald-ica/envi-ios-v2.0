---
phase: 10-meta-family-connector
task: 10-08
type: decision
decided: 2026-04-16
owner: connectors
status: locked
---

# 10-08 — Meta App ID Strategy

## TL;DR

ENVI integrates with four Meta dev-app IDs. **We keep all four separate**
for v1.1 and the foreseeable future. Consolidation is tempting but carries
App Review risk that outweighs the complexity saved.

## The four IDs

| ID                  | Role                                            | OAuth `client_id`?     | Secret Manager key              |
|---------------------|-------------------------------------------------|------------------------|---------------------------------|
| `1233228574968466`  | **Facebook Pages**                              | Yes (FB OAuth)         | `staging-meta-app-secret`       |
| `1811522229543951`  | **Instagram Graph** (Business/Creator)          | Yes (IG via FB dialog) | `staging-instagram-app-secret`  |
| `1604969460421980`  | **Threads standalone**                          | Yes (Threads OAuth)    | `staging-threads-app-secret`    |
| `1649869446444171`  | **Envi-Threads-parent** (app group discriminator) | **No**               | n/a                             |

The `Envi-Threads-parent` ID is NOT an OAuth client. It's the Graph "app
group" that owns the Threads standalone app. We keep it around because:

1. Meta's Secret Manager surface lets us label secrets by parent app
   group — handy for audit logs when rotating.
2. Threads' Graph surface occasionally cross-references the parent
   (`app_id` field on `/me` responses) for analytics.
3. Future Meta product launches are likely to sit under the same parent
   group — easier to pre-authorize than to create a new parent later.

## Decision: KEEP ALL FOUR SEPARATE

### Why not consolidate?

A consolidated single-app strategy would look like: "one Meta dev app,
request all permissions (Pages, IG Graph, Threads) in one App Review
round-trip." Problems:

1. **Broader review surface** — Reviewers scrutinize every permission
   against the whole app's use cases. A single rejected scope blocks the
   entire review until resolved. Today we can ship Threads while FB Pages
   is still in review for `pages_manage_posts`.
2. **Lost product separation** — Threads has distinct TOS + data policies
   that Meta enforces at the app level. Cramming it into the FB app
   invites TOS violation warnings.
3. **Permission expiry** — Some Meta permissions expire if unused. A
   consolidated app with mixed scope activity is harder to keep in good
   standing than three focused apps.
4. **Rate limits** — Per-app rate limits apply uniformly. Separate apps
   get separate buckets; a Facebook publish flood doesn't starve
   Instagram refreshes.

### Why not fold the Threads parent into the standalone?

1. **Meta-internal tooling** — The parent app group controls whether we
   can list the Threads app in the Meta App Gallery, which we need for
   the marketing push in Phase 13.
2. **Secret rotation** — Rotating the Threads client secret while
   preserving the parent's trust relationships is a one-click operation
   in the current shape. Folding them together means every secret rotation
   risks breaking the app gallery listing.
3. **Role of `1649869446444171` is purely administrative** — it is NOT an
   OAuth `client_id`, it is a Secret Manager / App Gallery discriminator.
   No user-facing flow talks to it.

### Complexity cost of keeping them separate

Absorbed entirely in `functions/src/providers/meta.ts`. The `MetaProvider`
class constructor branches on `MetaSubPlatform` and selects the right
`appID` + secret name + auth URL. iOS code doesn't see any of it — three
connector subclasses each fix their sub-platform, no enum branching
beyond the base class.

Total additional LOC vs. a single-app strategy: ~40 (the enum + the
switch in `MetaProvider`'s constructor). Trivial compared to the App
Review risk removed.

## When to revisit

Merge the four into one dev app ONLY if:

1. Meta publicly deprecates separate-app permission granting (signal: a
   `MIGRATION_REQUIRED` webhook on our dev-app dashboard).
2. We hit an undocumented rate limit interaction that only surfaces across
   separate apps (signal: rate limit errors that don't correlate with our
   per-app call volume).
3. Meta's App Review policy changes to explicitly favor consolidated apps
   (signal: a policy update in the Facebook Developer newsletter).

Until then: four apps, three OAuth clients, one provider class, zero
consolidation work.

## App Review status (as of 2026-04-16)

- `1233228574968466` (FB Pages):
  - `pages_show_list` ✅ self-serve
  - `pages_manage_posts` ⏳ submitted, under review
  - `pages_read_engagement` ⏳ submitted, under review
  - `public_profile` ✅ self-serve
- `1811522229543951` (IG Graph):
  - `instagram_basic` ✅ self-serve
  - `instagram_content_publish` ⏳ submitted, under review
  - `pages_read_engagement` ⏳ inherited from FB Pages review
  - `pages_show_list` ✅ self-serve
- `1604969460421980` (Threads):
  - `threads_basic` ✅ self-serve
  - `threads_content_publish` ⏳ submitted, under review
  - `threads_manage_replies` ✅ self-serve

Until all three publish scopes clear review, `FeatureFlags.canConnectFacebook`
stays `false` AND the Connect UI doesn't surface IG or Threads connect
buttons either. We flip each platform independently as review completes.

## References

- Phase 10 PLAN: `.planning/phases/10-meta-family-connector/PLAN.md`
- Implementation: `functions/src/providers/meta.ts`
- iOS connectors: `ENVI/Core/Connectors/{MetaGraphConnector,FacebookConnector,InstagramConnector,ThreadsConnector}.swift`
