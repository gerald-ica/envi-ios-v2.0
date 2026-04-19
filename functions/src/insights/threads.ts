/**
 * threads.ts — Nightly Threads insights sync.
 *
 * Endpoints
 * ---------
 *   GET /{threads-user-id}/threads?fields=id,timestamp
 *   GET /{threads-user-id}/threads_insights
 *         ?metric=views,likes,replies,reposts,quotes,shares
 *
 * No audience demographics on the Threads API as of Apr 2026 — those
 * fields are flagged "coming soon" but never shipped. We leave the
 * audience* fields null and set dataQuality=partial only if the
 * metrics payload is empty.
 */
import type { DailySnapshot, PostMetric } from "./_shared/snapshotSchema";
import { InsightsSyncBase } from "./_shared/insightsSyncBase";

const GRAPH = "https://graph.threads.net/v1.0";

interface ThreadsListResponse {
  data: Array<{ id: string; timestamp: string }>;
}

interface ThreadsMetric {
  name: string;
  values?: Array<{ value: number }>;
  total_value?: { value: number };
}

interface ThreadsInsightsResponse {
  data: ThreadsMetric[];
}

export class ThreadsInsightsSync extends InsightsSyncBase {
  readonly provider = "threads" as const;

  async fetchMetrics(
    _uid: string,
    token: string,
    date: string,
    providerUserId: string
  ): Promise<DailySnapshot> {
    // 1. Account-level insights — followers_count + views.
    const accountInsights = await getJson<ThreadsInsightsResponse>(
      `${GRAPH}/${providerUserId}/threads_insights?metric=views,likes,replies,reposts,quotes,followers_count&access_token=${encodeURIComponent(token)}`
    );
    const acct = pickTotals(accountInsights);

    // 2. Recent threads.
    const list = await getJson<ThreadsListResponse>(
      `${GRAPH}/${providerUserId}/threads?fields=id,timestamp&limit=25&access_token=${encodeURIComponent(token)}`
    );

    const posts: PostMetric[] = [];
    for (const t of list.data ?? []) {
      const per = await getJson<ThreadsInsightsResponse>(
        `${GRAPH}/${t.id}/insights?metric=views,likes,replies,reposts,quotes,shares&access_token=${encodeURIComponent(token)}`
      );
      const m = pickTotals(per);
      posts.push({
        postId: t.id,
        platform: "threads",
        views: m.views,
        likes: m.likes,
        comments: m.replies,
        shares: m.shares + m.reposts + m.quotes,
        saves: null,
        postedAt: t.timestamp,
      });
    }

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
      provider: "threads",
      date,
      syncedAt: undefined as unknown as FirebaseFirestore.Timestamp,
      accountId: providerUserId,
      followers: acct.followers_count,
      followersGain: 0,
      views: acct.views > 0 ? acct.views : totals.views,
      reach: acct.views > 0 ? acct.views : totals.views,
      likes: totals.likes,
      comments: totals.comments,
      shares: totals.shares,
      saves: null,
      linkClicks: 0,  // Threads doesn't expose link_clicks yet — keep 0 rather than null.
      posts,
      postsByHour: bucketPostsByHour(posts),
      audienceAge: null,
      audienceGender: null,
      audienceCountry: null,
      dataQuality: list.data?.length ? "full" : "partial",
      rawResponseRef: null,
    };
  }
}

function pickTotals(r: ThreadsInsightsResponse): {
  views: number; likes: number; replies: number; reposts: number;
  quotes: number; shares: number; followers_count: number;
} {
  const get = (name: string) => {
    const m = r.data.find((d) => d.name === name);
    return m?.total_value?.value ?? m?.values?.[0]?.value ?? 0;
  };
  return {
    views: get("views"),
    likes: get("likes"),
    replies: get("replies"),
    reposts: get("reposts"),
    quotes: get("quotes"),
    shares: get("shares"),
    followers_count: get("followers_count"),
  };
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
    throw new Error(`threads GET ${url.split("?")[0]} HTTP ${res.status}`);
  }
  return (await res.json()) as T;
}
