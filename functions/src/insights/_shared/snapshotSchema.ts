/**
 * snapshotSchema.ts — canonical types for Phase 13 analytics insights.
 *
 * Firestore layout (authoritative reference — PLAN.md §Firestore Schema):
 *   users/{uid}/insights/{provider}/{yyyy-mm-dd}                           — daily
 *   users/{uid}/insights/{provider}/rollups/weekly/{yyyy-Www}              — weekly
 *   users/{uid}/insights/{provider}/rollups/monthly/{yyyy-mm}              — monthly
 *
 *   benchmarks/{industryCategory}/{metricKey}                              — global
 *   trendSignals/{yyyy-mm-dd}                                              — global
 *   users/{uid}/generatedInsights/{yyyy-mm-dd}                             — per-user
 *   users/{uid}/weeklyDigest/{yyyy-Www}                                    — per-user
 *
 * Invariants
 * ----------
 * - `views` (NOT `impressions`) is the canonical reach-ish counter. The Nov
 *   2025 Meta deprecation removed `impressions` from IG/FB Graph responses;
 *   we use `views` everywhere and the iOS `AnalyticsData.KPI.reach` label
 *   maps to it for display continuity.
 * - `saves` is null on providers that do not expose it (X, Threads, FB,
 *   LinkedIn). Similarly `linkClicks` is null on IG/TikTok.
 * - `dataQuality` signals partial-payload cases (e.g. X Free tier without
 *   per-post impressions). The iOS KPI card reads this to show the
 *   "Limited data" badge.
 * - `rawResponseRef` is a GCS path used in staging for replay; it MUST be
 *   null in prod writes.
 */
import type { firestore } from "firebase-admin";
import type { SupportedProvider } from "../../lib/firestoreSchema";

/** Coarse data-quality marker carried on every snapshot + rollup. */
export type DataQuality = "full" | "partial" | "unavailable";

/** One row per post, present inside a daily snapshot's `posts` array. */
export interface PostMetric {
  /** Provider-native post id (media id, tweet id, Threads id, etc). */
  postId: string;
  /** Mirror of the snapshot's `provider` for cross-collection queries. */
  platform: SocialProvider;
  /** IG/Threads/YT use "views"; FB/LinkedIn use their `views_total` equiv. */
  views: number;
  likes: number;
  comments: number;
  shares: number;
  /** Null where unavailable (X, Threads, FB page posts, LinkedIn shares). */
  saves: number | null;
  /** ISO-8601 in UTC — always writeable from `new Date().toISOString()`. */
  postedAt: string;
}

/**
 * Authoritative daily payload. Written once per (uid, provider, yyyy-mm-dd)
 * by the provider-specific `InsightsSyncBase` subclass.
 */
export interface DailySnapshot {
  provider: SocialProvider;
  /** Local date key in UTC, YYYY-MM-DD. Doc id = this value. */
  date: string;
  syncedAt: firestore.Timestamp;
  /** Provider-native account id (IG user id, Page id, TikTok open_id, ...). */
  accountId: string;

  followers: number;
  /** Day-over-day delta. Negative when an account loses followers. */
  followersGain: number;

  /**
   * Replaces the pre-Nov-2025 `impressions` field. Meta Graph API returns
   * `views` on IG/FB from Nov 2025 onwards; TikTok returns `video_views`;
   * Threads returns `views`; X returns `impression_count` when tier
   * permits — we normalise that into `views` here.
   */
  views: number;
  /** Unique accounts reached. Where unavailable, mirrors `views`. */
  reach: number;

  likes: number;
  comments: number;
  shares: number;
  /** IG/TikTok only. Null everywhere else. */
  saves: number | null;
  /** Threads/LinkedIn/X. Null on IG/TikTok/FB. */
  linkClicks: number | null;

  /** Per-post breakdown for leaderboards. Capped at 50 by sync job. */
  posts: PostMetric[];

  /** Map of "00".."23" → total engagement that hour. Used for heatmap. */
  postsByHour: Record<string, number>;

  /** IG/TikTok/LinkedIn only. Null on others. */
  audienceAge: Record<string, number> | null;
  audienceGender: Record<string, number> | null;
  audienceCountry: Record<string, number> | null;

  dataQuality: DataQuality;
  /** GCS path for staging replay; null in prod. */
  rawResponseRef: string | null;
}

/**
 * Weekly rollup — derived from 7 daily snapshots by
 * `rollupAggregator.aggregateWeek`. Doc id is the ISO week label
 * `yyyy-Www` (e.g. `2026-W15`).
 */
export interface WeeklyRollup {
  provider: SocialProvider;
  weekLabel: string;
  /** ISO date string (YYYY-MM-DD) for Monday of the week in UTC. */
  startDate: string;
  /** ISO date string (YYYY-MM-DD) for Sunday of the week in UTC. */
  endDate: string;

  totalViews: number;
  totalReach: number;
  totalLikes: number;
  totalComments: number;
  totalShares: number;
  totalSaves: number | null;
  totalLinkClicks: number | null;

  /** (likes + comments + shares + saves) / views * 100. 0 when views=0. */
  avgEngagementRate: number;
  /** Net follower delta across the week. */
  followerGrowth: number;
  /** Provider-native id of the week's best-performing post by views. */
  topPostId: string | null;

  syncedAt: firestore.Timestamp;
  /**
   * Worst data-quality across the 7 days — a week is only "full" if all 7
   * daily docs were "full".
   */
  dataQuality: DataQuality;
}

/**
 * Monthly rollup — derived from 28–31 daily snapshots. Doc id is
 * `yyyy-mm` (e.g. `2026-04`).
 *
 * Adds audience aggregates that are too noisy to trust day-to-day.
 */
export interface MonthlyRollup {
  provider: SocialProvider;
  monthLabel: string;
  startDate: string;
  endDate: string;

  totalViews: number;
  totalReach: number;
  totalLikes: number;
  totalComments: number;
  totalShares: number;
  totalSaves: number | null;
  totalLinkClicks: number | null;

  avgEngagementRate: number;
  followerGrowth: number;
  /** Month's best-performing post across all daily snapshots. */
  bestPostId: string | null;

  /** Averaged/most-recent demographics. Null where provider never returns. */
  audienceAge: Record<string, number> | null;
  audienceGender: Record<string, number> | null;
  audienceCountry: Record<string, number> | null;

  syncedAt: firestore.Timestamp;
  dataQuality: DataQuality;
}

/**
 * Per-user generated insight doc — written by the `generateInsights`
 * Pub/Sub-triggered function after each nightly sync. Read by the iOS
 * `FirestoreBackedBenchmarkRepository.fetchInsights()`.
 */
export interface GeneratedInsightsDoc {
  date: string;
  generatedAt: firestore.Timestamp;
  insights: Array<{
    id: string;
    title: string;
    description: string;
    actionableAdvice: string;
    impact: "high" | "medium" | "low";
    confidence: number;
    providers: SocialProvider[];
  }>;
}

/**
 * Global trend signals — written by the `trendSignalsGenerator` nightly
 * function from envi-aggregated creator data. Doc id = yyyy-mm-dd.
 */
export interface TrendSignalsDoc {
  date: string;
  generatedAt: firestore.Timestamp;
  signals: Array<{
    topic: string;
    momentum: number;
    direction: "up" | "down" | "stable";
    platforms: SocialProvider[];
    timeframe: string;
  }>;
}

/**
 * Weekly digest — written once per user per ISO week by the
 * `generateWeeklyDigest` function. Doc id = `yyyy-Www`.
 */
export interface WeeklyDigestDoc {
  weekLabel: string;
  weekStarting: string;
  highlights: string[];
  topContentIds: string[];
  keyMetrics: Array<{
    metric: string;
    userValue: number;
    industryAvg: number;
    topPerformer: number;
    percentile: number;
  }>;
  recommendations: string[];
  generatedAt: firestore.Timestamp;
}

/**
 * Global benchmark doc — static per (industryCategory, metricKey).
 * Populated once by the `seedBenchmarks` CF and refreshed quarterly.
 */
export interface BenchmarkDoc {
  category: string;
  metric: string;
  industryAvg: number;
  topPerformerThreshold: number;
  sampleSize: number;
  lastUpdated: firestore.Timestamp;
}

/** Narrowed provider string matching the iOS `SocialPlatform` slugs. */
export type SocialProvider = SupportedProvider;

// ---------------------------------------------------------------------------
// Path helpers
// ---------------------------------------------------------------------------

/**
 * Daily snapshot location. Uses a `daily/` subcollection so the provider
 * doc id can stay a short, stable platform slug and so the iOS Firestore
 * SDK can read with `.collection("daily").document(key)` rather than
 * treating the date as a doc under the provider (which would make the
 * provider doc itself a parent of heterogeneous children — bad for
 * security rule matching + offline cache eviction).
 */
export function dailySnapshotPath(
  uid: string,
  provider: SocialProvider,
  dateKey: string
): string {
  return `users/${uid}/insights/${provider}/daily/${dateKey}`;
}

export function weeklyRollupPath(
  uid: string,
  provider: SocialProvider,
  weekLabel: string
): string {
  return `users/${uid}/insights/${provider}/rollups/weekly/entries/${weekLabel}`;
}

export function monthlyRollupPath(
  uid: string,
  provider: SocialProvider,
  monthLabel: string
): string {
  return `users/${uid}/insights/${provider}/rollups/monthly/entries/${monthLabel}`;
}

/** yyyy-mm-dd in UTC — the canonical date key for daily snapshots. */
export function dateKeyUTC(d: Date): string {
  const yyyy = d.getUTCFullYear();
  const mm = String(d.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(d.getUTCDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

/** yyyy-mm in UTC. */
export function monthKeyUTC(d: Date): string {
  const yyyy = d.getUTCFullYear();
  const mm = String(d.getUTCMonth() + 1).padStart(2, "0");
  return `${yyyy}-${mm}`;
}

/**
 * ISO-8601 week label (yyyy-Www). Monday is the week start; Thursday is
 * the anchor for year determination — matches ISO-8601 §5.1 and the Java
 * / Python `%G-W%V` formatter.
 */
export function isoWeekLabelUTC(d: Date): string {
  const target = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  const dayNum = target.getUTCDay() || 7;
  target.setUTCDate(target.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(target.getUTCFullYear(), 0, 1));
  const weekNum = Math.ceil(((target.getTime() - yearStart.getTime()) / 86_400_000 + 1) / 7);
  return `${target.getUTCFullYear()}-W${String(weekNum).padStart(2, "0")}`;
}

/** Conservative data-quality downgrade: `unavailable` > `partial` > `full`. */
export function worstQuality(a: DataQuality, b: DataQuality): DataQuality {
  if (a === "unavailable" || b === "unavailable") return "unavailable";
  if (a === "partial" || b === "partial") return "partial";
  return "full";
}
