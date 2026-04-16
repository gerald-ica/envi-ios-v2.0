/**
 * tiktok.display.ts — TikTok Display API (`/v2/video/list/`).
 *
 * Phase 08. Read-only endpoint surfaced to iOS under
 *   GET /connectors/tiktok/videos?cursor=...&max_count=...
 *
 * TikTok's `video.list` is cursor-based and returns 1–20 items per page.
 * We project the raw payload onto a compact shape the iOS decoder expects
 * (see `TikTokModels.swift#TikTokVideo`). Extra fields from TikTok pass
 * through via `data.videos[i]` — the mapping below is intentionally narrow
 * so new TikTok fields don't break the response contract.
 */
import { logger } from "../lib/logger";

const log = logger.withContext({ phase: "08", scope: "tiktok-display" });

export const TIKTOK_VIDEO_LIST_URL =
  "https://open.tiktokapis.com/v2/video/list/";

/** `fields` query param. Must match the keys projected in `mapVideo`. */
const VIDEO_FIELDS = [
  "id",
  "title",
  "cover_image_url",
  "create_time",
  "duration",
  "view_count",
  "like_count",
  "comment_count",
  "share_count",
].join(",");

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** Shape we return to iOS. Matches `TikTokVideo`'s snake_case decode. */
export interface TikTokVideoDTO {
  id: string;
  title: string | null;
  cover_image_url: string | null;
  create_time: number | null;
  duration: number;
  view_count: number | null;
  like_count: number | null;
  comment_count: number | null;
  share_count: number | null;
}

export interface ListVideosResult {
  videos: TikTokVideoDTO[];
  cursor: number | null;
  has_more: boolean;
}

interface TikTokVideoListResponse {
  data?: {
    videos?: Array<{
      id?: string;
      title?: string;
      cover_image_url?: string;
      create_time?: number;
      duration?: number;
      view_count?: number;
      like_count?: number;
      comment_count?: number;
      share_count?: number;
    }>;
    cursor?: number;
    has_more?: boolean;
  };
  error: {
    code: string;
    message?: string;
  };
}

// ---------------------------------------------------------------------------
// listVideos
// ---------------------------------------------------------------------------

/**
 * Fetch a page of videos for the authenticated user.
 *
 * @param userToken  Bearer access token (decrypted by caller).
 * @param cursor     Opaque cursor from a previous response, or `null` for page 1.
 * @param maxCount   1-20. Clamped to 20 per TikTok's documented ceiling.
 */
export async function listVideos(
  userToken: string,
  cursor: number | null,
  maxCount: number,
  fetchImpl: typeof fetch = fetch
): Promise<ListVideosResult> {
  const clamped = Math.min(Math.max(maxCount | 0, 1), 20);
  const url = `${TIKTOK_VIDEO_LIST_URL}?fields=${encodeURIComponent(
    VIDEO_FIELDS
  )}`;

  const body: Record<string, unknown> = { max_count: clamped };
  if (typeof cursor === "number" && cursor > 0) {
    body.cursor = cursor;
  }

  const response = await fetchImpl(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${userToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  const raw = (await response.json().catch(() => ({}))) as TikTokVideoListResponse;

  if (!response.ok || raw.error?.code !== "ok") {
    throw new Error(
      `tiktok: video/list/ responded HTTP ${response.status}: ${
        raw.error?.message ?? "unknown error"
      }`
    );
  }

  const videos = (raw.data?.videos ?? [])
    .filter((v) => typeof v.id === "string" && v.id.length > 0)
    .map((v) => mapVideo(v));

  const nextCursor =
    typeof raw.data?.cursor === "number" ? raw.data.cursor : null;
  const hasMore = raw.data?.has_more === true;

  log.info("tiktok video.list ok", {
    count: videos.length,
    hasMore,
  });

  return { videos, cursor: nextCursor, has_more: hasMore };
}

// ---------------------------------------------------------------------------
// Mapper
// ---------------------------------------------------------------------------

/** 1:1 projection from TikTok's raw video payload onto `TikTokVideoDTO`. */
function mapVideo(v: {
  id?: string;
  title?: string;
  cover_image_url?: string;
  create_time?: number;
  duration?: number;
  view_count?: number;
  like_count?: number;
  comment_count?: number;
  share_count?: number;
}): TikTokVideoDTO {
  return {
    id: v.id ?? "",
    title: typeof v.title === "string" && v.title.length > 0 ? v.title : null,
    cover_image_url:
      typeof v.cover_image_url === "string" ? v.cover_image_url : null,
    create_time: typeof v.create_time === "number" ? v.create_time : null,
    duration: typeof v.duration === "number" ? v.duration : 0,
    view_count: typeof v.view_count === "number" ? v.view_count : null,
    like_count: typeof v.like_count === "number" ? v.like_count : null,
    comment_count:
      typeof v.comment_count === "number" ? v.comment_count : null,
    share_count: typeof v.share_count === "number" ? v.share_count : null,
  };
}
