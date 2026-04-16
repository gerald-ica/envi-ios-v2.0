/**
 * x.media.ts — v2 chunked media upload helpers.
 *
 * Phase 9. All calls hit `https://api.x.com/2/media/upload`. We use v2
 * exclusively — the v1.1 upload endpoint (`upload.twitter.com/1.1/
 * media/upload.json`) deprecated 2025-03-31. See Phase 9 PLAN Decision 1.
 *
 * API surface (exported)
 * ----------------------
 * - `uploadMediaChunked(...)` — the full INIT → APPEND* → FINALIZE →
 *   STATUS* chain. Returns a terminal `media_id`.
 * - `chooseMediaCategory(...)` — pick `amplify_video` | `tweet_video` |
 *   `tweet_image` based on MIME + duration.
 *
 * Single-shot image path
 * ----------------------
 * Images don't need the multi-step upload. `uploadMediaChunked` short-
 * circuits to a single POST for `tweet_image`. Callers can rely on the
 * same return shape.
 *
 * Rate-limit awareness
 * --------------------
 * Each HTTP call is wrapped in `withXRateLimit`. The outer fn catches
 * `RateLimitError` and re-throws — the top-level route handler in
 * `x.ts` renders the iOS-facing `{ error: "rate_limited" }` envelope.
 */
import { logger } from "../lib/logger";
import {
  RateLimitError,
  withXRateLimit,
  type RateLimitedCall,
} from "./x.rate-limit";
import type {
  XMediaInitResponse,
  XMediaStatusResponse,
  XMediaUploadCommand,
} from "./x.types";

const log = logger.withContext({ phase: "09-04", provider: "x" });

const X_MEDIA_ENDPOINT = "https://api.x.com/2/media/upload";

/**
 * 5 MB chunks — X documents anything from 1 MB to 5 MB works; 5 MB gives
 * the best throughput for typical ENVI MP4 sizes (30–120s at 1080p).
 */
const APPEND_CHUNK_BYTES = 5 * 1024 * 1024;

/**
 * Upper bound on STATUS poll iterations. With the minimum
 * `check_after_secs = 5` this covers ~2.5 min of X-side processing,
 * which comfortably contains the 99th percentile for < 10-min clips.
 */
const STATUS_POLL_MAX_ATTEMPTS = 30;

export interface UploadMediaChunkedInput {
  accessToken: string;
  totalBytes: number;
  mimeType: string;
  durationSeconds: number;
  /**
   * Lazily-resolved chunk reader. Accepts a byte range, returns the
   * raw bytes. We take this as a function (rather than a Buffer or
   * Stream) so the call site can stream from Cloud Storage without
   * loading the full file into memory.
   */
  readChunk: (offset: number, length: number) => Promise<Buffer>;
}

export interface UploadMediaChunkedResult {
  mediaID: string;
  mediaKey: string | null;
  expiresAfterSecs: number | null;
}

/**
 * Decide which `media_category` string to pass at INIT time.
 *
 * See PLAN Decision 4:
 *   - video ≤ 140s → tweet_video
 *   - video > 140s → amplify_video (eligibility required)
 *   - image        → tweet_image (single-shot, no chunking)
 */
export function chooseMediaCategory(
  mimeType: string,
  durationSeconds: number
): "tweet_image" | "tweet_video" | "amplify_video" {
  if (mimeType.startsWith("image/")) {
    return "tweet_image";
  }
  return durationSeconds > 140 ? "amplify_video" : "tweet_video";
}

/**
 * Full upload chain. Images short-circuit through the single-shot
 * image endpoint.
 */
export async function uploadMediaChunked(
  input: UploadMediaChunkedInput
): Promise<UploadMediaChunkedResult> {
  const category = chooseMediaCategory(input.mimeType, input.durationSeconds);

  if (category === "tweet_image") {
    return uploadImageSingleShot(input);
  }

  // INIT
  const initResp = await initUpload({
    accessToken: input.accessToken,
    totalBytes: input.totalBytes,
    mediaType: input.mimeType,
    mediaCategory: category,
  });
  const mediaID = initResp.data.id;
  log.info("x.media INIT ok", {
    mediaID,
    category,
    totalBytes: input.totalBytes,
  });

  // APPEND (loop)
  const chunks = Math.ceil(input.totalBytes / APPEND_CHUNK_BYTES);
  for (let segmentIndex = 0; segmentIndex < chunks; segmentIndex++) {
    const offset = segmentIndex * APPEND_CHUNK_BYTES;
    const length = Math.min(
      APPEND_CHUNK_BYTES,
      input.totalBytes - offset
    );
    const chunkBytes = await input.readChunk(offset, length);
    await appendUpload({
      accessToken: input.accessToken,
      mediaID,
      segmentIndex,
      chunk: chunkBytes,
      offset,
      length,
      total: input.totalBytes,
    });
  }
  log.info("x.media APPEND complete", { mediaID, chunks });

  // FINALIZE
  const finalize = await finalizeUpload({
    accessToken: input.accessToken,
    mediaID,
  });

  // STATUS loop if async processing indicated
  const state = finalize.data.processing_info?.state;
  if (state === "pending" || state === "in_progress") {
    await pollStatusUntilTerminal({
      accessToken: input.accessToken,
      mediaID,
      initialDelaySecs: finalize.data.processing_info?.check_after_secs ?? 5,
    });
  } else if (state === "failed") {
    const reason =
      finalize.data.processing_info?.error?.name ??
      finalize.data.processing_info?.error?.message ??
      "unknown";
    throw new MediaProcessingError(reason);
  }

  return {
    mediaID,
    mediaKey: initResp.data.media_key ?? null,
    expiresAfterSecs: initResp.data.expires_after_secs ?? null,
  };
}

// ---------------------------------------------------------------------------
// Images (single-shot)
// ---------------------------------------------------------------------------

/**
 * Images go through the simple path: one POST with the bytes, no
 * INIT/APPEND/FINALIZE. We still reuse the rate-limit wrapper.
 */
async function uploadImageSingleShot(
  input: UploadMediaChunkedInput
): Promise<UploadMediaChunkedResult> {
  const bytes = await input.readChunk(0, input.totalBytes);

  const call: RateLimitedCall<XMediaInitResponse> = async ({ signal }) => {
    const form = new FormData();
    form.append(
      "media",
      new Blob([bytes], { type: input.mimeType }),
      "upload"
    );
    const response = await fetch(X_MEDIA_ENDPOINT, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${input.accessToken}`,
      },
      body: form,
      signal,
    });
    const json =
      response.ok ? ((await response.json()) as XMediaInitResponse) : {
        data: { id: "", media_key: "", expires_after_secs: 0 },
      };
    return { response, value: json };
  };

  const { value } = await withXRateLimit(call, {
    endpointLabel: "media.upload.image",
  });

  return {
    mediaID: value.data.id,
    mediaKey: value.data.media_key ?? null,
    expiresAfterSecs: value.data.expires_after_secs ?? null,
  };
}

// ---------------------------------------------------------------------------
// INIT
// ---------------------------------------------------------------------------

interface InitInput {
  accessToken: string;
  totalBytes: number;
  mediaType: string;
  mediaCategory: "tweet_video" | "amplify_video";
}

async function initUpload(input: InitInput): Promise<XMediaInitResponse> {
  const call: RateLimitedCall<XMediaInitResponse> = async ({ signal }) => {
    const body = new URLSearchParams({
      command: "INIT" satisfies XMediaUploadCommand,
      media_type: input.mediaType,
      total_bytes: String(input.totalBytes),
      media_category: input.mediaCategory,
    });
    const response = await fetch(X_MEDIA_ENDPOINT, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${input.accessToken}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body,
      signal,
    });
    if (!response.ok) {
      return {
        response,
        value: {
          data: { id: "", media_key: "", expires_after_secs: 0 },
        },
      };
    }
    const value = (await response.json()) as XMediaInitResponse;
    return { response, value };
  };

  const { value } = await withXRateLimit(call, {
    endpointLabel: "media.upload.init",
  });
  if (!value.data.id) {
    throw new Error("x.media INIT returned no media id");
  }
  return value;
}

// ---------------------------------------------------------------------------
// APPEND
// ---------------------------------------------------------------------------

interface AppendInput {
  accessToken: string;
  mediaID: string;
  segmentIndex: number;
  chunk: Buffer;
  offset: number;
  length: number;
  total: number;
}

async function appendUpload(input: AppendInput): Promise<void> {
  const call: RateLimitedCall<void> = async ({ signal }) => {
    const form = new FormData();
    form.append(
      "command",
      "APPEND" satisfies XMediaUploadCommand
    );
    form.append("media_id", input.mediaID);
    form.append("segment_index", String(input.segmentIndex));
    form.append(
      "media",
      new Blob([input.chunk]),
      `chunk-${input.segmentIndex}`
    );

    const endByte = input.offset + input.length - 1;
    const contentRange = `bytes ${input.offset}-${endByte}/${input.total}`;

    const response = await fetch(X_MEDIA_ENDPOINT, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${input.accessToken}`,
        "Content-Range": contentRange,
      },
      body: form,
      signal,
    });
    return { response, value: undefined };
  };

  await withXRateLimit(call, {
    endpointLabel: "media.upload.append",
  });
}

// ---------------------------------------------------------------------------
// FINALIZE
// ---------------------------------------------------------------------------

interface FinalizeInput {
  accessToken: string;
  mediaID: string;
}

async function finalizeUpload(
  input: FinalizeInput
): Promise<XMediaStatusResponse> {
  const call: RateLimitedCall<XMediaStatusResponse> = async ({ signal }) => {
    const body = new URLSearchParams({
      command: "FINALIZE" satisfies XMediaUploadCommand,
      media_id: input.mediaID,
    });
    const response = await fetch(X_MEDIA_ENDPOINT, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${input.accessToken}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body,
      signal,
    });
    const value = response.ok
      ? ((await response.json()) as XMediaStatusResponse)
      : ({ data: { id: input.mediaID, media_key: "" } } as XMediaStatusResponse);
    return { response, value };
  };

  const { value } = await withXRateLimit(call, {
    endpointLabel: "media.upload.finalize",
  });
  return value;
}

// ---------------------------------------------------------------------------
// STATUS (poll)
// ---------------------------------------------------------------------------

interface StatusPollInput {
  accessToken: string;
  mediaID: string;
  initialDelaySecs: number;
}

async function pollStatusUntilTerminal(
  input: StatusPollInput
): Promise<void> {
  let delaySecs = Math.max(input.initialDelaySecs, 1);

  for (let attempt = 0; attempt < STATUS_POLL_MAX_ATTEMPTS; attempt++) {
    await sleep(delaySecs * 1000);

    const call: RateLimitedCall<XMediaStatusResponse> = async ({ signal }) => {
      const url =
        `${X_MEDIA_ENDPOINT}` +
        `?command=STATUS&media_id=${encodeURIComponent(input.mediaID)}`;
      const response = await fetch(url, {
        method: "GET",
        headers: { Authorization: `Bearer ${input.accessToken}` },
        signal,
      });
      const value = response.ok
        ? ((await response.json()) as XMediaStatusResponse)
        : ({
            data: { id: input.mediaID, media_key: "" },
          } as XMediaStatusResponse);
      return { response, value };
    };

    const { value } = await withXRateLimit(call, {
      endpointLabel: "media.upload.status",
    });

    const state = value.data.processing_info?.state;
    if (state === "succeeded" || state === undefined) {
      return;
    }
    if (state === "failed") {
      const reason =
        value.data.processing_info?.error?.name ??
        value.data.processing_info?.error?.message ??
        "unknown";
      throw new MediaProcessingError(reason);
    }
    delaySecs = value.data.processing_info?.check_after_secs ?? delaySecs;
  }

  throw new MediaProcessingError("status poll timed out");
}

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

/**
 * Thrown by FINALIZE / STATUS when X reports a terminal `failed` state.
 * Caught in `x.ts` and translated to the iOS envelope
 * `{ error: "media_processing", detail: <reason> }`.
 */
export class MediaProcessingError extends Error {
  readonly reason: string;
  constructor(reason: string) {
    super(`x.media processing failed: ${reason}`);
    this.name = "MediaProcessingError";
    this.reason = reason;
  }
}

// Re-export so x.ts can `instanceof`-check without importing from deep.
export { RateLimitError };

// ---------------------------------------------------------------------------
// Utils
// ---------------------------------------------------------------------------

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
