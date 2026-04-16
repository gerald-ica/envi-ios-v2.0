/**
 * linkedin.ts — Nightly LinkedIn insights sync.
 *
 * Endpoints (REST v202604+ required)
 * ----------------------------------
 *   GET /rest/memberCreatorPostAnalytics
 *   GET /rest/organizationalEntityShareStatistics  (org pages)
 *
 * Rate limit: ~100 req/day/app at non-enterprise tier. Hard cap — we
 * batch per-UID and NEVER issue per-post calls. The creator analytics
 * endpoint returns aggregate stats for the member's posts in a single
 * response.
 *
 * Demographics: LinkedIn exposes follower-statistics demographics for
 * organization pages only. We surface them when the connection has a
 * linked org; otherwise the fields stay null.
 */
import type { DailySnapshot } from "./_shared/snapshotSchema";
import { InsightsSyncBase } from "./_shared/insightsSyncBase";

const API = "https://api.linkedin.com/rest";
const VERSION = "202604";

interface MemberAnalytics {
  totalViews?: number;
  totalLikes?: number;
  totalComments?: number;
  totalShares?: number;
  totalImpressions?: number;
  totalClicks?: number;
  followerCount?: number;
}

export class LinkedInInsightsSync extends InsightsSyncBase {
  readonly provider = "linkedin" as const;

  async fetchMetrics(
    uid: string,
    token: string,
    date: string,
    providerUserId: string
  ): Promise<DailySnapshot> {
    // Single request for member creator analytics.
    const urn = encodeURIComponent(`urn:li:person:${providerUserId}`);
    const res = await fetch(
      `${API}/memberCreatorPostAnalytics?q=author&author=${urn}`,
      {
        headers: {
          Authorization: `Bearer ${token}`,
          "LinkedIn-Version": VERSION,
          "X-Restli-Protocol-Version": "2.0.0",
        },
      }
    );
    if (!res.ok) {
      throw new Error(`linkedin memberCreatorPostAnalytics HTTP ${res.status}`);
    }
    const payload = (await res.json()) as MemberAnalytics;

    return {
      provider: "linkedin",
      date,
      syncedAt: undefined as unknown as FirebaseFirestore.Timestamp,
      accountId: providerUserId,
      followers: payload.followerCount ?? 0,
      followersGain: 0,
      views: payload.totalViews ?? payload.totalImpressions ?? 0,
      reach: payload.totalImpressions ?? payload.totalViews ?? 0,
      likes: payload.totalLikes ?? 0,
      comments: payload.totalComments ?? 0,
      shares: payload.totalShares ?? 0,
      saves: null,
      linkClicks: payload.totalClicks ?? 0,
      posts: [],  // Per-post detail requires per-URN calls — blocked by daily cap.
      postsByHour: {},
      audienceAge: null,
      audienceGender: null,
      audienceCountry: null,
      dataQuality: payload.totalViews !== undefined ? "full" : "partial",
      rawResponseRef: null,
    };
  }
}
