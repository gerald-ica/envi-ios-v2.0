/**
 * facebook.ts — Nightly Facebook Pages insights sync.
 *
 * Endpoint: `GET /{page-id}/insights?metric=page_views_total,...`
 *
 * Two things to know about the Meta API in April 2026
 * ----------------------------------------------------
 * 1. `page_impressions` was DEPRECATED in Nov 2025. Use
 *    `page_views_total` for the "views" metric family.
 * 2. `page_impressions_unique` (reach) is NO LONGER RETURNED for
 *    `start_time` > 13 months ago (June 2025). We clamp the window to
 *    the last 14 days to stay inside the supported range.
 *
 * Demographics are intentionally skipped for FB Pages — the signal is
 * poor and the page-level audience insights API is on the way out.
 */
import type { DailySnapshot, PostMetric } from "./_shared/snapshotSchema";
import { InsightsSyncBase } from "./_shared/insightsSyncBase";

const GRAPH = "https://graph.facebook.com/v21.0";

interface PageInsightsResponse {
  data: Array<{
    name: string;
    values: Array<{ value: number | Record<string, number>; end_time: string }>;
  }>;
}

interface PagePostsResponse {
  data: Array<{ id: string; created_time: string }>;
}

interface PagePostInsightsResponse {
  data: Array<{ name: string; values: Array<{ value: number }> }>;
}

interface PageResponse {
  id: string;
  fan_count?: number;
  followers_count?: number;
}

export class FacebookInsightsSync extends InsightsSyncBase {
  readonly provider = "facebook" as const;

  async fetchMetrics(
    uid: string,
    token: string,
    date: string,
    providerUserId: string
  ): Promise<DailySnapshot> {
    // 1. Page totals (followers / fans).
    const page = await getJson<PageResponse>(
      `${GRAPH}/${providerUserId}?fields=id,fan_count,followers_count&access_token=${encodeURIComponent(token)}`
    );

    // 2. Page-level insights — `page_views_total` replaces deprecated
    //    `page_impressions`. `page_post_engagements` still works.
    const pageInsights = await getJson<PageInsightsResponse>(
      `${GRAPH}/${providerUserId}/insights?metric=page_views_total,page_post_engagements,page_impressions_unique&period=day&access_token=${encodeURIComponent(token)}`
    );
    const pageViews = pickLatest(pageInsights, "page_views_total");
    const pageReach = pickLatest(pageInsights, "page_impressions_unique");  // 13mo clamp
    const pageEngagements = pickLatest(pageInsights, "page_post_engagements");

    // 3. Recent posts + per-post insights.
    const postsList = await getJson<PagePostsResponse>(
      `${GRAPH}/${providerUserId}/posts?fields=id,created_time&limit=25&access_token=${encodeURIComponent(token)}`
    );
    const posts: PostMetric[] = [];
    for (const p of postsList.data ?? []) {
      const metrics = await getJson<PagePostInsightsResponse>(
        `${GRAPH}/${p.id}/insights?metric=post_impressions,post_reactions_by_type_total,post_clicks&access_token=${encodeURIComponent(token)}`
      );
      const vals = flattenMetrics(metrics);
      posts.push({
        postId: p.id,
        platform: "facebook",
        views: vals.post_impressions ?? 0,
        likes: countReactions(metrics),
        comments: 0,  // FB page posts require separate /comments endpoint; skip per rate-limit budget.
        shares: 0,
        saves: null,
        postedAt: p.created_time,
      });
    }

    const dataQuality = pageViews === null ? "partial" : "full";

    return {
      provider: "facebook",
      date,
      syncedAt: undefined as unknown as FirebaseFirestore.Timestamp,
      accountId: providerUserId,
      followers: page.followers_count ?? page.fan_count ?? 0,
      followersGain: 0,
      views: pageViews ?? 0,
      reach: pageReach ?? pageViews ?? 0,
      likes: pageEngagements ?? 0,
      comments: 0,
      shares: 0,
      saves: null,
      linkClicks: null,
      posts,
      postsByHour: bucketPostsByHour(posts),
      audienceAge: null,
      audienceGender: null,
      audienceCountry: null,
      dataQuality,
      rawResponseRef: null,
    };
  }
}

function pickLatest(r: PageInsightsResponse, name: string): number | null {
  const series = r.data.find((d) => d.name === name)?.values;
  if (!series || series.length === 0) return null;
  const last = series[series.length - 1]?.value;
  return typeof last === "number" ? last : null;
}

function flattenMetrics(r: PagePostInsightsResponse): Record<string, number> {
  const out: Record<string, number> = {};
  for (const d of r.data) {
    const v = d.values?.[0]?.value;
    if (typeof v === "number") out[d.name] = v;
  }
  return out;
}

function countReactions(r: PagePostInsightsResponse): number {
  const m = r.data.find((d) => d.name === "post_reactions_by_type_total");
  const v = m?.values?.[0]?.value as unknown as Record<string, number> | number | undefined;
  if (!v) return 0;
  if (typeof v === "number") return v;
  return Object.values(v).reduce((a, b) => a + b, 0);
}

function bucketPostsByHour(posts: PostMetric[]): Record<string, number> {
  const out: Record<string, number> = {};
  for (const p of posts) {
    const h = String(new Date(p.postedAt).getUTCHours()).padStart(2, "0");
    out[h] = (out[h] ?? 0) + p.likes + p.comments + p.shares;
  }
  return out;
}

async function getJson<T>(url: string): Promise<T> {
  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`facebook GET ${url.split("?")[0]} HTTP ${res.status}`);
  }
  return (await res.json()) as T;
}
