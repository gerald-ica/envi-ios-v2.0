/**
 * x.ts — Nightly X (Twitter) insights sync.
 *
 * Endpoint: `GET /2/users/:id/tweets?tweet.fields=public_metrics,created_at`
 *
 * Tier note (CRITICAL)
 * --------------------
 * - Free tier: public_metrics is missing `impression_count`. We set
 *   `dataQuality: "partial"` so the iOS KPI card shows a "Limited data"
 *   badge.
 * - Basic tier ($200/mo as of 2026): returns `impression_count`,
 *   `bookmark_count`, and `non_public_metrics` when the token belongs
 *   to the author. We consume those when available.
 * - Pro tier ($5000/mo): full per-tweet analytics — not gated here.
 *
 * Rate limit: 15 req / 15 min on the tweets timeline endpoint at Basic.
 * We issue ONE call per UID per sync.
 */
import type { DailySnapshot, PostMetric } from "./_shared/snapshotSchema";
import { InsightsSyncBase } from "./_shared/insightsSyncBase";

const API = "https://api.x.com/2";

interface TweetPublicMetrics {
  retweet_count?: number;
  reply_count?: number;
  like_count?: number;
  quote_count?: number;
  bookmark_count?: number;
  impression_count?: number;
}

interface Tweet {
  id: string;
  created_at: string;
  public_metrics?: TweetPublicMetrics;
  non_public_metrics?: { impression_count?: number; user_profile_clicks?: number };
}

interface TimelineResponse {
  data?: Tweet[];
  meta?: { result_count?: number };
}

interface UserMeResponse {
  data: { id: string; public_metrics?: { followers_count?: number } };
}

export class XInsightsSync extends InsightsSyncBase {
  readonly provider = "x" as const;

  async fetchMetrics(
    _uid: string,
    token: string,
    date: string,
    providerUserId: string
  ): Promise<DailySnapshot> {
    // 1. Followers (cheap call, charged against a different bucket).
    const me = await getJson<UserMeResponse>(
      `${API}/users/me?user.fields=public_metrics`,
      token
    );
    const followers = me.data?.public_metrics?.followers_count ?? 0;

    // 2. Recent tweets — one call per UID.
    const tl = await getJson<TimelineResponse>(
      `${API}/users/${providerUserId}/tweets?max_results=25&tweet.fields=public_metrics,created_at,non_public_metrics`,
      token
    );

    let hasImpressions = true;
    const posts: PostMetric[] = (tl.data ?? []).map((t) => {
      const impressions =
        t.public_metrics?.impression_count ??
        t.non_public_metrics?.impression_count ??
        null;
      if (impressions === null) hasImpressions = false;
      return {
        postId: t.id,
        platform: "x",
        views: impressions ?? 0,
        likes: t.public_metrics?.like_count ?? 0,
        comments: t.public_metrics?.reply_count ?? 0,
        shares: (t.public_metrics?.retweet_count ?? 0) + (t.public_metrics?.quote_count ?? 0),
        saves: null,  // bookmark_count exists but semantics differ; expose as null for now.
        postedAt: t.created_at,
      };
    });

    const totals = posts.reduce(
      (acc, p) => ({
        views: acc.views + p.views,
        likes: acc.likes + p.likes,
        comments: acc.comments + p.comments,
        shares: acc.shares + p.shares,
      }),
      { views: 0, likes: 0, comments: 0, shares: 0 }
    );

    return {
      provider: "x",
      date,
      syncedAt: undefined as unknown as FirebaseFirestore.Timestamp,
      accountId: providerUserId,
      followers,
      followersGain: 0,
      views: totals.views,
      reach: totals.views,
      likes: totals.likes,
      comments: totals.comments,
      shares: totals.shares,
      saves: null,
      linkClicks: null,
      posts,
      postsByHour: bucketPostsByHour(posts),
      audienceAge: null,
      audienceGender: null,
      audienceCountry: null,
      // Basic tier returns impressions; Free tier does not. Partial when missing.
      dataQuality: hasImpressions && posts.length > 0 ? "full" : "partial",
      rawResponseRef: null,
    };
  }
}

function bucketPostsByHour(posts: PostMetric[]): Record<string, number> {
  const out: Record<string, number> = {};
  for (const p of posts) {
    const h = String(new Date(p.postedAt).getUTCHours()).padStart(2, "0");
    out[h] = (out[h] ?? 0) + p.likes + p.comments + p.shares;
  }
  return out;
}

async function getJson<T>(url: string, token: string): Promise<T> {
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) {
    throw new Error(`x GET ${url.split("?")[0]} HTTP ${res.status}`);
  }
  return (await res.json()) as T;
}
