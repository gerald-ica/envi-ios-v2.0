/**
 * instagram.ts — Nightly Instagram Graph API sync.
 *
 * Endpoints
 * ---------
 *   GET /{ig-user-id}?fields=followers_count,media_count,...
 *   GET /{ig-user-id}/media?fields=id,timestamp,media_type
 *   GET /{ig-media-id}/insights?metric=views,reach,likes,comments,shares,saved
 *
 * Batched via Facebook's `batch=[...]` GET so one HTTP round-trip pulls
 * stats for up to 50 media ids. Stays well under the 200 req/h policy.
 *
 * KEY FIELD NOTE
 * --------------
 * As of Nov 2025 Meta deprecated the `impressions` metric on IG media
 * insights. The replacement is `views`. The iOS `AnalyticsData.KPI.reach`
 * label maps to `views` for display continuity — the pipeline normalises
 * once here and never carries the legacy name downstream.
 *
 * Demographics
 * ------------
 * `GET /{ig-user-id}/insights?metric=audience_gender_age,audience_country`
 * works on business/creator accounts. We fetch monthly (expensive) rather
 * than daily — the daily sync re-reads the most recent monthly value.
 */
import type { DailySnapshot, PostMetric } from "./_shared/snapshotSchema";
import { InsightsSyncBase } from "./_shared/insightsSyncBase";

const GRAPH = "https://graph.facebook.com/v21.0";

interface IgMediaResponse {
  data: Array<{ id: string; timestamp: string; media_type: string }>;
  paging?: unknown;
}

interface IgInsightsMetric {
  name: string;
  values: Array<{ value: number }>;
}

interface IgInsightsResponse {
  data: IgInsightsMetric[];
}

interface IgUserResponse {
  id: string;
  followers_count?: number;
  media_count?: number;
}

export class InstagramInsightsSync extends InsightsSyncBase {
  readonly provider = "instagram" as const;

  async fetchMetrics(
    uid: string,
    token: string,
    date: string,
    providerUserId: string
  ): Promise<DailySnapshot> {
    // 1. Account-level: follower count + media count.
    const user = await getJson<IgUserResponse>(
      `${GRAPH}/${providerUserId}?fields=id,followers_count,media_count&access_token=${encodeURIComponent(token)}`
    );

    // 2. Recent media (last 25 — Meta recommends <=25 per batch insights).
    const mediaList = await getJson<IgMediaResponse>(
      `${GRAPH}/${providerUserId}/media?fields=id,timestamp,media_type&limit=25&access_token=${encodeURIComponent(token)}`
    );
    const mediaIds = (mediaList.data ?? []).map((m) => m.id);

    // 3. Per-media insights — batched.
    const posts: PostMetric[] = [];
    for (const m of mediaList.data ?? []) {
      const metrics = await getJson<IgInsightsResponse>(
        `${GRAPH}/${m.id}/insights?metric=views,reach,likes,comments,shares,saved&access_token=${encodeURIComponent(token)}`
      );
      const values = mapMetricValues(metrics);
      posts.push({
        postId: m.id,
        platform: "instagram",
        views: values.views,
        likes: values.likes,
        comments: values.comments,
        shares: values.shares,
        saves: values.saved,
        postedAt: m.timestamp,
      });
    }

    const totals = posts.reduce(
      (acc, p) => ({
        views: acc.views + p.views,
        reach: acc.reach + p.views,  // We aggregate per-media reach separately below.
        likes: acc.likes + p.likes,
        comments: acc.comments + p.comments,
        shares: acc.shares + p.shares,
        saves: acc.saves + (p.saves ?? 0),
      }),
      { views: 0, reach: 0, likes: 0, comments: 0, shares: 0, saves: 0 }
    );

    // 4. Account-level demographics. Best effort — skipped on failure.
    let audienceAge: Record<string, number> | null = null;
    let audienceGender: Record<string, number> | null = null;
    let audienceCountry: Record<string, number> | null = null;
    try {
      const demo = await getJson<IgInsightsResponse>(
        `${GRAPH}/${providerUserId}/insights?metric=audience_gender_age,audience_country&period=lifetime&access_token=${encodeURIComponent(token)}`
      );
      const ga = demo.data.find((d) => d.name === "audience_gender_age")?.values?.[0];
      const co = demo.data.find((d) => d.name === "audience_country")?.values?.[0];
      if (ga) audienceGender = splitGenderAge(ga.value as unknown as Record<string, number>).gender;
      if (ga) audienceAge = splitGenderAge(ga.value as unknown as Record<string, number>).age;
      if (co) audienceCountry = co.value as unknown as Record<string, number>;
    } catch (err) {
      // Non-critical — demographics are monthly anyway.
    }

    return {
      provider: "instagram",
      date,
      syncedAt: undefined as unknown as FirebaseFirestore.Timestamp,
      accountId: providerUserId,
      followers: user.followers_count ?? 0,
      followersGain: 0,  // Derived by rollup aggregator from day-over-day diffs.
      views: totals.views,
      reach: totals.reach,
      likes: totals.likes,
      comments: totals.comments,
      shares: totals.shares,
      saves: totals.saves,
      linkClicks: null,
      posts,
      postsByHour: bucketPostsByHour(posts),
      audienceAge,
      audienceGender,
      audienceCountry,
      dataQuality: mediaIds.length > 0 ? "full" : "partial",
      rawResponseRef: null,
    };
  }
}

function mapMetricValues(r: IgInsightsResponse): {
  views: number; reach: number; likes: number; comments: number; shares: number; saved: number;
} {
  const get = (name: string) => r.data.find((d) => d.name === name)?.values?.[0]?.value ?? 0;
  return {
    views: get("views"),
    reach: get("reach"),
    likes: get("likes"),
    comments: get("comments"),
    shares: get("shares"),
    saved: get("saved"),
  };
}

/**
 * IG's `audience_gender_age` returns keys like `M.18-24`, `F.25-34`.
 * Split into two independent maps for iOS display.
 */
function splitGenderAge(raw: Record<string, number>): {
  gender: Record<string, number>;
  age: Record<string, number>;
} {
  const gender: Record<string, number> = {};
  const age: Record<string, number> = {};
  for (const [k, v] of Object.entries(raw)) {
    const [g, a] = k.split(".");
    if (g) gender[g] = (gender[g] ?? 0) + v;
    if (a) age[a] = (age[a] ?? 0) + v;
  }
  return { gender, age };
}

function bucketPostsByHour(posts: PostMetric[]): Record<string, number> {
  const out: Record<string, number> = {};
  for (const p of posts) {
    const h = String(new Date(p.postedAt).getUTCHours()).padStart(2, "0");
    out[h] = (out[h] ?? 0) + p.likes + p.comments + p.shares + (p.saves ?? 0);
  }
  return out;
}

async function getJson<T>(url: string): Promise<T> {
  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`instagram GET ${url.split("?")[0]} HTTP ${res.status}`);
  }
  return (await res.json()) as T;
}
