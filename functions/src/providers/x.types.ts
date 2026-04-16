/**
 * x.types.ts — TypeScript shapes for the X (Twitter) v2 API wire formats.
 *
 * Phase 9 intentionally keeps these hand-rolled rather than pulling a
 * third-party typing package. The X v2 schema is small in our usage
 * (token exchange, users/me, tweet create, chunked media upload) and
 * evolves fast enough that pinned types drift within a release cycle.
 *
 * Naming convention
 * -----------------
 * - `X*Response`           — exact shape X returns on success (snake_case).
 * - `X*Request`            — exact shape we POST to X.
 * - `XRateLimitHeaders`    — parsed `x-rate-limit-*` response headers.
 *
 * We intentionally DO NOT re-export these as public API types from the
 * broker — iOS sees our own camelCase shapes translated in `x.ts`.
 * That keeps us free to adapt to X's schema changes without burning a
 * binary-compatible iOS symbol.
 */

// ---------------------------------------------------------------------------
// OAuth 2.0 token exchange / refresh
// ---------------------------------------------------------------------------

/**
 * POST /2/oauth2/token — response on successful code exchange or refresh.
 * TTL fields: `expires_in` is seconds-from-now; `scope` is space-separated.
 */
export interface XTokenResponse {
  token_type: "bearer";
  access_token: string;
  /** Present when `offline.access` was requested. Nullable otherwise. */
  refresh_token?: string;
  expires_in: number;
  /** Space-separated list echoed back by X. */
  scope: string;
}

// ---------------------------------------------------------------------------
// Users / profile
// ---------------------------------------------------------------------------

/**
 * GET /2/users/me?user.fields=username,name,public_metrics,profile_image_url
 */
export interface XUserResponse {
  data: {
    id: string;
    username: string;
    name: string;
    profile_image_url?: string;
    public_metrics?: {
      followers_count: number;
      following_count: number;
      tweet_count: number;
      listed_count: number;
    };
  };
}

// ---------------------------------------------------------------------------
// Tweets
// ---------------------------------------------------------------------------

/** POST /2/tweets body. */
export interface XTweetCreateRequest {
  text: string;
  media?: {
    media_ids: string[];
  };
  reply?: {
    in_reply_to_tweet_id: string;
  };
}

/** POST /2/tweets successful response. */
export interface XTweetCreateResponse {
  data: {
    id: string;
    text: string;
  };
}

// ---------------------------------------------------------------------------
// Media upload (v2 — POST /2/media/upload)
// ---------------------------------------------------------------------------

/**
 * INIT sub-command response. Returns a stable `id` we use as `media_id`
 * in subsequent APPEND / FINALIZE / STATUS calls.
 */
export interface XMediaInitResponse {
  data: {
    id: string;
    media_key: string;
    expires_after_secs: number;
  };
}

/**
 * STATUS sub-command response. `processing_info.state` walks through
 * `pending` → `in_progress` → (`succeeded` | `failed`). Terminal states
 * short-circuit the poll loop.
 */
export interface XMediaStatusResponse {
  data: {
    id: string;
    media_key: string;
    processing_info?: {
      state: "pending" | "in_progress" | "succeeded" | "failed";
      check_after_secs?: number;
      progress_percent?: number;
      error?: {
        code: number;
        name: string;
        message: string;
      };
    };
  };
}

/**
 * FINALIZE sub-command response. Reuses the STATUS shape — when X needs
 * more processing time it returns `processing_info.state === "pending"`
 * and expects the caller to enter the STATUS poll loop.
 */
export type XMediaFinalizeResponse = XMediaStatusResponse;

/** Union of the v2 upload sub-commands. */
export type XMediaUploadCommand = "INIT" | "APPEND" | "FINALIZE" | "STATUS";

/**
 * iOS → Cloud Function request body for `POST /connectors/x/media`.
 * Mirrors `XMediaUploadRequest` on the Swift side.
 */
export interface XProxyMediaRequest {
  /** Cloud Storage object path OR absolute `file://` URL (emulator). */
  storagePath: string;
  /** Full MIME type, e.g. `video/mp4`. */
  mimeType: string;
  /** Byte count — required for INIT's `total_bytes` field. */
  totalBytes: number;
  /** Video duration in seconds. 0 for images. */
  durationSeconds: number;
}

/**
 * Cloud Function → iOS response. Mirrors `XMediaUploadTicket` on Swift.
 */
export interface XProxyMediaResponse {
  mediaID: string;
  mediaKey: string | null;
  expiresAfterSecs: number | null;
}

// ---------------------------------------------------------------------------
// Rate-limit response headers
// ---------------------------------------------------------------------------

/**
 * Parsed `x-rate-limit-*` headers. `reset` is normalized from a unix
 * timestamp string to a Date in `x.rate-limit.ts`.
 */
export interface XRateLimitHeaders {
  /** Window ceiling (e.g. 100 for the Basic tier `/2/tweets` endpoint). */
  limit: number;
  /** Calls remaining in the current window. */
  remaining: number;
  /** Absolute instant the window resets. */
  reset: Date;
}

// ---------------------------------------------------------------------------
// iOS proxy response shapes (camelCase, translated from X's snake_case)
// ---------------------------------------------------------------------------

/**
 * Response body for `GET /connectors/x/account`.
 * Public_metrics.followers_count is unwrapped; handle is username.
 */
export interface XAccountResponse {
  id: string;
  username: string;
  name: string;
  followerCount: number;
  profileImageURL: string | null;
}

/**
 * Request body for `POST /connectors/x/tweet`. iOS → server.
 */
export interface XProxyTweetRequest {
  text: string;
  mediaID?: string | null;
  replyToID?: string | null;
}

/**
 * Response body for `POST /connectors/x/tweet`. Server → iOS.
 * Mirrors `XTweetResponse` Swift struct.
 */
export interface XProxyTweetResponse {
  id: string;
  text: string;
}

// ---------------------------------------------------------------------------
// Error envelope (server → iOS)
// ---------------------------------------------------------------------------

/**
 * Canonical error envelope returned from every `/connectors/x/*` route.
 * Mirrors `XConnectorErrorEnvelope` on Swift.
 *
 * Known codes:
 *   - "rate_limited"       (also sets retryAfter)
 *   - "media_processing"   (also sets detail)
 *   - "media_too_large"
 *   - "media_unsupported"  (detail = extension)
 *   - "media_duration"     (detail = seconds)
 *   - "not_connected"
 *   - "tweet_rejected"     (also sets detail)
 *   - "internal"           (generic fallback)
 */
export interface XErrorEnvelope {
  error: string;
  /** ISO-8601 string. Only present for `error === "rate_limited"`. */
  retryAfter?: string;
  /** Free-form detail string. Never carries token material. */
  detail?: string;
}
