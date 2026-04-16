/**
 * tiktok.publish.ts — TikTok Content Posting API (inbox variant).
 *
 * Phase 08.
 *
 * Flow
 * ----
 *   1. Client POSTs `/connectors/tiktok/publish/init` with `video_size`.
 *   2. We call TikTok's `/v2/post/publish/inbox/video/init/` → returns
 *      `publish_id` + `upload_url` (pre-signed, 1 h TTL).
 *   3. Client PUTs chunks directly to `upload_url` (we never proxy bytes).
 *   4. Client POSTs `/connectors/tiktok/publish/complete` with the
 *      `publish_id`. That kicks off `pollUntilComplete` which:
 *        - POSTs `/v2/post/publish/status/fetch/` with exponential backoff
 *          (5s → 60s cap, 10min overall timeout).
 *        - Writes the live + final status to
 *          `users/{uid}/connections/tiktok/publishes/{publishID}`.
 *
 * Why inbox and not direct publish?
 * ---------------------------------
 * Sandbox *mandates* the inbox flow (`/inbox/video/init/`) — the direct-
 * publish endpoint rejects sandbox tokens. Inbox gives the tester a manual
 * "Post" step, which is also an App Review expectation. When we ship the
 * prod app + approved permissions, switching to direct is a 1-line change
 * in `initUpload`.
 *
 * All functions in this module accept a plain `userToken` (Bearer access
 * token) — broker handlers decrypt tokens from `users/{uid}/connections/tiktok`
 * and pass them in.
 */
import type { firestore } from "firebase-admin";

import { logger } from "../lib/logger";

const log = logger.withContext({ phase: "08", scope: "tiktok-publish" });

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

export const TIKTOK_INBOX_INIT_URL =
  "https://open.tiktokapis.com/v2/post/publish/inbox/video/init/";

export const TIKTOK_PUBLISH_STATUS_URL =
  "https://open.tiktokapis.com/v2/post/publish/status/fetch/";

/** 10 MB chunk size — matches the iOS client and fits inside Functions
 *  request-body caps. TikTok accepts up to ~64 MB per chunk but smaller
 *  chunks resume more cleanly on flaky connections. */
export const TIKTOK_CHUNK_SIZE_BYTES = 10 * 1_048_576;

/** Initial backoff before the first status poll. */
const POLL_INITIAL_DELAY_MS = 5_000;

/** Cap on per-attempt backoff so long queues don't stretch indefinitely. */
const POLL_MAX_DELAY_MS = 60_000;

/** Total wall-clock budget. 10 minutes matches TikTok's own SLO for sandbox
 *  processing; if we blow past this we assume something's stuck. */
const POLL_TIMEOUT_MS = 10 * 60 * 1_000;

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type TikTokPublishState =
  | "PROCESSING_UPLOAD"
  | "SEND_TO_USER_INBOX"
  | "PUBLISH_COMPLETE"
  | "FAILED";

export interface InitUploadResult {
  publishID: string;
  uploadURL: string;
  /** Bytes. We echo `TIKTOK_CHUNK_SIZE_BYTES` in case the client prefers it. */
  chunkSize: number;
  /** Chunk count we computed client-side; helps broker sanity-check. */
  totalChunkCount: number;
}

export interface PollUntilCompleteInput {
  uid: string;
  userToken: string;
  publishID: string;
  db: firestore.Firestore;
  /** Injection hook for tests — defaults to `fetch`. */
  fetchImpl?: typeof fetch;
  /** Injection hook for tests — defaults to `setTimeout`-backed sleep. */
  sleepImpl?: (ms: number) => Promise<void>;
  /** Injection hook for tests — defaults to `Date.now`. */
  nowImpl?: () => number;
}

export interface PollUntilCompleteResult {
  terminalState: TikTokPublishState;
  reason?: string;
}

// ---------------------------------------------------------------------------
// initUpload
// ---------------------------------------------------------------------------

/**
 * Call TikTok's inbox-init endpoint. Returns the publish id + pre-signed
 * upload URL. The broker forwards both back to the client; the client
 * uploads bytes directly to TikTok (we never see them).
 *
 * @param userToken  Bearer access token (decrypted by caller).
 * @param videoSizeBytes  Total file size. Used to compute `total_chunk_count`.
 */
export async function initUpload(
  userToken: string,
  videoSizeBytes: number,
  fetchImpl: typeof fetch = fetch
): Promise<InitUploadResult> {
  if (!Number.isFinite(videoSizeBytes) || videoSizeBytes <= 0) {
    throw new Error("tiktok.publish.initUpload: invalid videoSizeBytes");
  }
  const totalChunkCount = Math.max(
    1,
    Math.ceil(videoSizeBytes / TIKTOK_CHUNK_SIZE_BYTES)
  );

  const body = {
    source_info: {
      source: "FILE_UPLOAD",
      video_size: videoSizeBytes,
      chunk_size: TIKTOK_CHUNK_SIZE_BYTES,
      total_chunk_count: totalChunkCount,
    },
  };

  const response = await fetchImpl(TIKTOK_INBOX_INIT_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${userToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  const raw = (await response.json().catch(() => ({}))) as {
    data?: { publish_id?: string; upload_url?: string };
    error?: { code?: string; message?: string };
  };

  if (!response.ok || raw.error?.code !== "ok") {
    throw new Error(
      `tiktok: inbox init responded HTTP ${response.status}: ${
        raw.error?.message ?? "unknown error"
      }`
    );
  }

  const publishID = raw.data?.publish_id;
  const uploadURL = raw.data?.upload_url;
  if (!publishID || !uploadURL) {
    throw new Error("tiktok: inbox init missing publish_id/upload_url");
  }

  log.info("tiktok inbox init ok", {
    publishID,
    totalChunkCount,
    videoSizeBytes,
  });

  return {
    publishID,
    uploadURL,
    chunkSize: TIKTOK_CHUNK_SIZE_BYTES,
    totalChunkCount,
  };
}

// ---------------------------------------------------------------------------
// pollUntilComplete
// ---------------------------------------------------------------------------

/**
 * Poll `/post/publish/status/fetch/` with exponential backoff until the
 * publish hits a terminal state (`SEND_TO_USER_INBOX` | `PUBLISH_COMPLETE`
 * | `FAILED`) or we exceed `POLL_TIMEOUT_MS`. Each poll result is mirrored
 * onto `users/{uid}/connections/tiktok/publishes/{publishID}` so iOS can
 * observe progress via Firestore snapshot listeners without holding an HTTP
 * connection open.
 *
 * Rate limit: TikTok allows 30 status requests / min / user. With 5-60s
 * backoff and a 10-min ceiling we stay safely under.
 */
export async function pollUntilComplete(
  input: PollUntilCompleteInput
): Promise<PollUntilCompleteResult> {
  const fetchImpl = input.fetchImpl ?? fetch;
  const sleep = input.sleepImpl ?? defaultSleep;
  const now = input.nowImpl ?? Date.now;

  const startedAt = now();
  let delay = POLL_INITIAL_DELAY_MS;
  let lastState: TikTokPublishState = "PROCESSING_UPLOAD";
  let lastReason: string | undefined;

  // Write an initial queued row so observers see something immediately.
  await writeStatus(input.db, {
    uid: input.uid,
    publishID: input.publishID,
    state: lastState,
    reason: null,
    terminal: false,
  });

  while (now() - startedAt < POLL_TIMEOUT_MS) {
    await sleep(delay);

    const response = await fetchImpl(TIKTOK_PUBLISH_STATUS_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${input.userToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ publish_id: input.publishID }),
    });

    const raw = (await response.json().catch(() => ({}))) as {
      data?: { status?: TikTokPublishState; fail_reason?: string };
      error?: { code?: string; message?: string };
    };

    if (!response.ok || raw.error?.code !== "ok") {
      // Transient provider errors — log and let the backoff loop retry.
      log.warn("tiktok status fetch transient error", {
        publishID: input.publishID,
        status: response.status,
        error: raw.error?.message,
      });
      delay = Math.min(delay * 2, POLL_MAX_DELAY_MS);
      continue;
    }

    const state = raw.data?.status ?? "PROCESSING_UPLOAD";
    lastState = state;
    lastReason = raw.data?.fail_reason;

    const terminal =
      state === "SEND_TO_USER_INBOX" ||
      state === "PUBLISH_COMPLETE" ||
      state === "FAILED";

    await writeStatus(input.db, {
      uid: input.uid,
      publishID: input.publishID,
      state,
      reason: lastReason ?? null,
      terminal,
    });

    if (terminal) {
      log.info("tiktok publish terminal state", {
        publishID: input.publishID,
        state,
      });
      return { terminalState: state, reason: lastReason };
    }

    delay = Math.min(delay * 2, POLL_MAX_DELAY_MS);
  }

  // Timed out before TikTok told us we were done. Mark the doc and return
  // FAILED so the caller surfaces something actionable.
  const reason = "timeout waiting for TikTok status";
  await writeStatus(input.db, {
    uid: input.uid,
    publishID: input.publishID,
    state: "FAILED",
    reason,
    terminal: true,
  });
  log.warn("tiktok publish polling timed out", {
    publishID: input.publishID,
    lastState,
  });
  return { terminalState: "FAILED", reason };
}

// ---------------------------------------------------------------------------
// Firestore write helper
// ---------------------------------------------------------------------------

interface PublishStatusDoc {
  publishID: string;
  state: TikTokPublishState;
  reason: string | null;
  terminal: boolean;
  updatedAt: firestore.Timestamp;
}

async function writeStatus(
  db: firestore.Firestore,
  params: {
    uid: string;
    publishID: string;
    state: TikTokPublishState;
    reason: string | null;
    terminal: boolean;
  }
): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const admin = require("firebase-admin") as typeof import("firebase-admin");
  const Timestamp = admin.firestore.Timestamp;

  const ref = db
    .collection("users")
    .doc(params.uid)
    .collection("connections")
    .doc("tiktok")
    .collection("publishes")
    .doc(params.publishID);

  const doc: PublishStatusDoc = {
    publishID: params.publishID,
    state: params.state,
    reason: params.reason,
    terminal: params.terminal,
    updatedAt: Timestamp.now(),
  };

  await ref.set(doc, { merge: true });
}

function defaultSleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
