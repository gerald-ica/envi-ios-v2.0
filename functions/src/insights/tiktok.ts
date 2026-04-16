/**
 * tiktok.ts — Nightly TikTok Display API sync.
 *
 * Endpoint: `POST https://open.tiktokapis.com/v2/video/query/` (Display API).
 * We pull the account's last 20 videos + stats in ONE call to stay under
 * the 100 req/day tier cap (see `rateLimitConfig.ts`).
 *
 * Returns a `DailySnapshot` keyed by today's UTC date. TikTok does NOT
 * provide day-over-day historical metrics via Display API, so we snapshot
 * the CUMULATIVE `view_count/like_count/comment_count/share_count` and
 * let the rollup aggregator compute daily deltas downstream.
 *
 * Demographics: TikTok Display API exposes no audience data; the
 * Research API is the path forward and requires academic-tier approval
 * (out of scope for v1.1).
 */
import type { DailySnapshot, PostMetric } from "./_shared/snapshotSchema";
import { InsightsSyncBase } from "./_shared/insightsSyncBase";

interface TikTokVideoFields {
  id: string;
  create_time: number;
  view_count: number;
  like_count: number;
  comment_count: number;
  share_count: number;
}

interface TikTokQueryResponse {
  data: {
    videos: TikTokVideoFields[];
    cursor: number;
    has_more: boolean;
  };
  error: { code: string; message: string; log_id?: string };
}

const TIKTOK_VIDEO_QUERY_URL = "https://open.tiktokapis.com/v2/video/query/";
const VIDEO_FIELDS = [
  "id",
  "create_time",
  "view_count",
  "like_count",
  "comment_count",
  "share_count",
].join(",");

export class TikTokInsightsSync extends InsightsSyncBase {
  readonly provider = "tiktok" as const;

  async fetchMetrics(
    uid: string,
    token: string,
    date: string,
    providerUserId: string
  ): Promise<DailySnapshot> {
    const res = await fetch(`${TIKTOK_VIDEO_QUERY_URL}?fields=${VIDEO_FIELDS}`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ max_count: 20 }),
    });
    if (!res.ok) {
      throw new Error(`tiktok video.query HTTP ${res.status}`);
    }
    const json = (await res.json()) as TikTokQueryResponse;
    if (json.error && json.error.code !== "ok") {
      throw new Error(`tiktok video.query error: ${json.error.code} ${json.error.message}`);
    }

    const videos = json.data?.videos ?? [];
    const posts: PostMetric[] = videos.map((v) => ({
      postId: v.id,
      platform: "tiktok",
      views: v.view_count,
      likes: v.like_count,
      comments: v.comment_count,
      shares: v.share_count,
      saves: null,  // TikTok Display API does not expose saves.
      postedAt: new Date(v.create_time * 1000).toISOString(),
    }));

    const totals = posts.reduce(
      (acc, p) => ({
        views: acc.views + p.views,
        likes: acc.likes + p.likes,
        comments: acc.comments + p.comments,
        shares: acc.shares + p.shares,
      }),
      { views: 0, likes: 0, comments: 0, shares: 0 }
    );

    const postsByHour = bucketPostsByHour(posts);

    return {
      provider: "tiktok",
      date,
      syncedAt: undefined as unknown as FirebaseFirestore.Timestamp,  // base stamps it
      accountId: providerUserId,
      followers: 0,          // Display API omits; pulled separately by user.info sync.
      followersGain: 0,
      views: totals.views,
      reach: totals.views,   // No distinct "reach" field — mirror views.
      likes: totals.likes,
      comments: totals.comments,
      shares: totals.shares,
      saves: null,
      linkClicks: null,
      posts,
      postsByHour,
      audienceAge: null,
      audienceGender: null,
      audienceCountry: null,
      dataQuality: posts.length > 0 ? "full" : "partial",
      rawResponseRef: null,
    };
  }
}

/** Hour-of-post → summed engagement. Used for heatmap seed. */
function bucketPostsByHour(posts: PostMetric[]): Record<string, number> {
  const out: Record<string, number> = {};
  for (const p of posts) {
    const h = String(new Date(p.postedAt).getUTCHours()).padStart(2, "0");
    out[h] = (out[h] ?? 0) + p.likes + p.comments + p.shares;
  }
  return out;
}
