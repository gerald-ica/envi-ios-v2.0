---
phase: 13-analytics-insights-readpath
milestone: v1.1-real-social-connectors
type: execute
depends-on: 12-publish-lifecycle-hardening
---

# Phase 13 — Analytics Insights Read-Path

**Goal:** Wire each platform's insights into existing Analytics/Advanced/Benchmark repositories. Replace mock data with Firestore-backed reads. All dashboards (KPI, engagement, benchmarks) show real per-platform data gated by `FeatureFlags.connectorsInsightsLive`.

---

## Architecture

```
Platform API → Cloud Function nightly sync
  → Firestore: users/{uid}/insights/{provider}/{yyyy-mm-dd}     (daily)
  → Firestore: users/{uid}/insights/{provider}/rollups/weekly/{yyyy-Www}
  → Firestore: users/{uid}/insights/{provider}/rollups/monthly/{yyyy-mm}

iOS FirestoreBackedAnalyticsRepository
  → reads latest snapshot (15-min in-memory cache)
  → aggregates cross-platform for KPI/engagement/benchmark
```

When `connectorsInsightsLive == false` → `MockAnalyticsRepository`. When `true` → `FirestoreBackedAnalyticsRepository`. Same flag governs Advanced + Benchmark repos.

---

## Files

### Cloud Functions
```
functions/src/insights/
  tiktok.ts | instagram.ts | facebook.ts | threads.ts | linkedin.ts | x.ts
  _shared/
    insightsSyncBase.ts    # abstract base: token fetch, rate-limit guard, snapshot write
    rateLimitConfig.ts     # per-provider config map
    snapshotSchema.ts      # TypeScript types
    rollupAggregator.ts    # daily→weekly→monthly
    insightRules.ts        # heuristic insight generator
```

Export from `functions/src/index.ts`: `scheduledInsightsSyncTikTok/Instagram/Facebook/Threads/LinkedIn/X`.

**Schedules (staggered, UTC):**
| Function | Cron |
|---|---|
| TikTok | `0 2 * * *` |
| Instagram | `0 2 * * *` |
| Facebook | `0 3 * * *` |
| Threads | `0 3 * * *` |
| LinkedIn | `0 4 * * *` |
| X | `0 4 * * *` |

### iOS
```
ENVI/Core/Data/Repositories/
  FirestoreBackedAnalyticsRepository.swift          (new)
  FirestoreBackedAdvancedAnalyticsRepository.swift  (new)
  FirestoreBackedBenchmarkRepository.swift          (new)

ENVI/Core/Config/FeatureFlags.swift                 (+ connectorsInsightsLive)
ENVI/Features/Profile/Analytics/
  ConnectAccountEmptyStateView.swift                (new)
  AnalyticsViewModel.swift                          (+ hasConnectedData branch)
  BenchmarkViewModel.swift                          (+ empty state)
  AdvancedAnalyticsViewModel.swift                  (+ empty state)
```

---

## Firestore Schema

### Daily snapshot (authoritative)
```
users/{uid}/insights/{provider}/{yyyy-mm-dd}
{
  provider, date, syncedAt, accountId,
  followers, followersGain,
  views,            // replaces `impressions` for Meta (post-Nov 2025 deprecation)
  reach, likes, comments, shares,
  saves,            // IG/TikTok only; null otherwise
  linkClicks,       // Threads/LinkedIn/X; null where unavailable
  posts: [{ postId, platform, views, likes, comments, shares, saves, postedAt }],
  postsByHour: { "HH": totalEngagement },
  audienceAge, audienceGender, audienceCountry,   // IG/TikTok/LinkedIn only
  dataQuality: "full"|"partial"|"unavailable",
  rawResponseRef: string|null   // GCS path for debug; null in prod
}
```

### Rollups
```
users/{uid}/insights/{provider}/rollups/weekly/{yyyy-Www}
users/{uid}/insights/{provider}/rollups/monthly/{yyyy-mm}
```

Fields: totals, avgEngagementRate, followerGrowth, topPostId, audienceAggregates (monthly only), dataQuality.

### Global
```
benchmarks/{industryCategory}/{metricKey}  — industryAvg, topPerformerThreshold
trendSignals/{yyyy-mm-dd}                   — signals[], generatedAt
```

### Security Rules (append to firestore.rules)
```
match /users/{uid}/insights/{rest=**} {
  allow read: if request.auth.uid == uid;
  allow write: if false;  // Cloud Functions only
}
match /benchmarks/{category}/{metric} {
  allow read: if request.auth != null;
  allow write: if false;
}
match /trendSignals/{date} {
  allow read: if request.auth != null;
  allow write: if false;
}
```

### Indexes
```json
{
  "collectionGroup": "insights",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "provider", "order": "ASCENDING" },
    { "fieldPath": "date", "order": "DESCENDING" }
  ]
}
```

---

## Sub-Plans

### 13-01  Nightly sync per provider

`insightsSyncBase.ts`:
```typescript
abstract class InsightsSyncBase {
  abstract provider: Provider;
  abstract fetchMetrics(uid, token, date): Promise<DailySnapshot>;
  async run()  // list users with connection → fetch → write → rollup
}
```

Each provider extends base, overrides `fetchMetrics`.

**Per-provider endpoints:**
- **TikTok:** Display API `GET /v2/video/query/` — one call/user/sync
- **Instagram:** Graph `GET /{ig-media-id}/insights` (batch) — uses `views` (not deprecated `impressions`)
- **Facebook:** `GET /{page-id}/insights?metric=page_views_total` — avoid `start_time` > 13mo (reach removed June 2025)
- **Threads:** `GET /{threads-user-id}/threads_insights?metric=views,likes,replies,reposts,quotes,shares` — no demographics as of Apr 2026
- **LinkedIn:** `/memberCreatorPostAnalytics` (v202604+) + `/organizationalEntityShareStatistics` — ~100 req/day/app; batch by UID never per-post
- **X:** `GET /2/users/:id/tweets?tweet.fields=public_metrics` — full per-post impressions require Basic tier minimum; mark `dataQuality: partial` if missing

### 13-02  FirestoreBackedAnalyticsRepository

Conforms to existing `AnalyticsRepository` protocol (no protocol changes). Methods:
- `fetchDashboard()` — read latest daily snapshots for all connected providers, aggregate → `AnalyticsData`
- `fetchCreatorGrowth()` — last 4 weekly rollups per provider → `CreatorGrowthSnapshot`
- `fetchRetentionCohorts()` — last 6 monthly rollups → `[RetentionCohort]`
- `fetchAttribution()` — follower-count deltas → `[SourceAttribution]`

15-min in-memory TTL via `lastFetchedAt: Date`. Nightly sync is authoritative.

`AnalyticsData.empty` sentinel + `hasConnectedData: Bool` computed property — empty state when no connected provider has 30 days of data.

### 13-03  FirestoreBackedAdvancedAnalyticsRepository

All 6 protocol methods:
- `fetchPerformanceReport(range:platforms:)` — rollup query by DateInterval, stitched `MetricDataPoint`
- `fetchAudienceDemographics()` — most recent monthly rollup from providers that supply demographics (IG/TikTok/LinkedIn)
- `fetchContentPerformance(sortBy:limit:)` — per-post aggregates across daily docs (requires composite index)
- `fetchPostTimeAnalysis()` — aggregated `postsByHour` over 90 days
- `fetchFunnelData()` — reach→impressions→engagement→follows funnel
- `fetchPeriodComparison(current:previous:)` — rollup deltas

### 13-04  FirestoreBackedBenchmarkRepository

- `fetchBenchmarks(category:)` — reads user rollups + static `benchmarks/{category}/{metric}` global docs
- `fetchInsights()` — reads `users/{uid}/generatedInsights/{yyyy-mm-dd}` written by `generateInsights` CF
- `fetchTrendSignals()` — reads `trendSignals/{date}` global
- `fetchWeeklyDigest()` — reads `users/{uid}/weeklyDigest/{yyyy-Www}` written by weekly CF

`generateInsights` Cloud Function: Pub/Sub-triggered after nightly sync. Reads 30-day window, applies `insightRules.ts` heuristics (e.g., "TikTok engagement 2.3× 30-day avg"), writes `generatedInsights` doc.

### 13-05  KPI unmock + empty state

`FeatureFlags.swift`:
```swift
public var connectorsInsightsLive: Bool = false  // Remote Config key "connectorsInsightsLive"
```

`AnalyticsRepositoryProvider.resolve()` factory picks `FirestoreBackedAnalyticsRepository` when flag true. Same pattern for Advanced + Benchmark providers.

`ConnectAccountEmptyStateView` shown when `connectorsInsightsLive == true` AND no connected provider has data for last 30 days. Message + "Connect an Account" CTA deep-links to Phase 12 Connected Accounts.

**No view changes required** for KPI/engagement cards — `KPICardView`/`EngagementChartView` render whatever the VM emits. Unmock is entirely at repository layer.

### 13-06  Rate limits + cache TTL

`rateLimitConfig.ts`:
```typescript
{
  tiktok:    { maxReqPerDay: 100,  windowMs: 86_400_000, backoffBaseMs: 2_000 },
  instagram: { maxReqPerHour: 200, windowMs:  3_600_000, backoffBaseMs: 1_000 },
  facebook:  { maxReqPerHour: 200, windowMs:  3_600_000, backoffBaseMs: 1_000 },
  threads:   { maxReqPerHour: 200, windowMs:  3_600_000, backoffBaseMs: 1_000 },
  linkedin:  { maxReqPerDay: 100,  windowMs: 86_400_000, backoffBaseMs: 3_000, note: "tight — batch by UID" },
  x:         { maxReqPer15min: 15, windowMs:    900_000, backoffBaseMs: 5_000, note: "Basic tier; Pro for volume" }
}
```

Token-bucket counters: `_rateLimit/{provider}/{date}` docs, atomic increment per call. Full bucket → defer remaining UIDs to Cloud Tasks queue with exponential backoff + 30% jitter.

iOS cache: per-method `lastFetchedAt: [String: Date]` with 15-min TTL. Firestore offline persistence (already enabled by Firebase SDK) covers restart cases.

---

## Build Sequence

### Phase A — Cloud Functions (no iOS dependency)
- [ ] 13-01-A: `_shared/snapshotSchema.ts`
- [ ] 13-01-B: `_shared/rateLimitConfig.ts`
- [ ] 13-01-C: `_shared/insightsSyncBase.ts`
- [ ] 13-01-D: `_shared/rollupAggregator.ts`
- [ ] 13-01-E-J: 6 provider files (tiktok/instagram/facebook/threads/linkedin/x)
- [ ] 13-01-K: Export from index.ts
- [ ] 13-01-L: Deploy to staging, verify Cloud Scheduler logs
- [ ] 13-01-M: Firestore security rules
- [ ] 13-01-N: Firestore indexes deployed

### Phase B — AnalyticsRepository (13-02)
- [ ] Create `FirestoreBackedAnalyticsRepository` + 15-min TTL + `AnalyticsData.empty`
- [ ] Update `AnalyticsRepositoryProvider`
- [ ] Unit test vs Firestore emulator

### Phase C — AdvancedAnalytics + Benchmark (13-03, 13-04)
- [ ] Create Firestore-backed implementations
- [ ] Seed `benchmarks/{category}` via one-time CF `seedBenchmarks`
- [ ] Create `generateInsights` CF (Pub/Sub triggered)
- [ ] Create `trendSignals` nightly CF

### Phase D — KPI unmock (13-05)
- [ ] Add `connectorsInsightsLive` flag + Remote Config key
- [ ] Create `ConnectAccountEmptyStateView`
- [ ] Empty-state branches in 3 ViewModels
- [ ] Staging smoke test: enable flag for test UID via Remote Config → real KPI data

### Phase E — Rate-limit validation (13-06)
- [ ] Token-bucket verified in emulator
- [ ] 429 simulation in unit tests
- [ ] X Basic-tier constraint documented in `x.ts`

---

## Verification

- [ ] 6 nightly syncs running in Cloud Scheduler
- [ ] Firestore snapshots populate for test UID per provider
- [ ] All 3 Firestore-backed repos pass unit tests against emulator
- [ ] `connectorsInsightsLive = true` shows real KPI data in staging cohort
- [ ] `connectorsInsightsLive = false` rollback shows mock data without crash
- [ ] User with no connected accounts sees `ConnectAccountEmptyStateView`
- [ ] Rate-limit backoff verified for TikTok + LinkedIn
- [ ] No new iOS SPM deps
- [ ] All existing Analytics tests still pass

## Provider Notes

- **IG/FB deprecations:** `impressions` deprecated Nov 2025 → use `views`. `AnalyticsData.KPI.reach` label maps to `views` for display continuity.
- **FB:** `page_views_total` replaces deprecated `page_impressions`; reach no longer returned for `start_time` > 13mo (June 2025).
- **LinkedIn:** v202604+ for `/memberCreatorPostAnalytics`. Hard daily cap — batch per UID, never per-post.
- **X:** Basic tier minimum for per-post impressions. Lower tier → `dataQuality: partial` + "Limited data" badge on KPI card.

## Open Questions

1. X tier: if Basic still insufficient for some fields, should we show "Upgrade for full analytics" prompt?
2. Threads demographics API — check for release before shipping (currently unavailable)
3. `benchmarks` global seed data source — envi-aggregated vs third-party?
