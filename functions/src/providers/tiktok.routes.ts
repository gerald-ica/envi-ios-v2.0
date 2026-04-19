/**
 * tiktok.routes.ts — HTTPS handlers for TikTok-specific (non-OAuth) ops.
 *
 * Phase 08 introduces three routes outside the generic Phase 7 broker:
 *
 *   POST /connectors/tiktok/publish/init       — exchange video_size for
 *                                                 publish_id + upload_url.
 *   POST /connectors/tiktok/publish/complete   — fire-and-forget the
 *                                                 status poller.
 *   GET  /connectors/tiktok/videos             — Display API read path.
 *
 * Each route is App Check-required (App Check middleware wraps the
 * handler). The Firebase ID token is verified via `requireFirebaseUid`,
 * and the user's TikTok access token is read from
 * `users/{uid}/connections/tiktok` via `tokenStorage.readConnection`.
 *
 * Background polling
 * ------------------
 * `publish/complete` awaits `pollUntilComplete` directly. Cloud Functions
 * 2nd gen tolerates up to 60 min per invocation and 10 min is well inside
 * that envelope; no Cloud Tasks required for v1.1. Phase 12's publish
 * dispatcher will take this over and move polling behind a durable queue.
 */
import {
  onRequest,
  type Request,
} from "firebase-functions/v2/https";
import type { Response } from "express";

import { requireAppCheck } from "../lib/appCheck";
import { getRegion } from "../lib/config";
import { logger } from "../lib/logger";
import { readConnection } from "../lib/tokenStorage";
import { requireFirebaseUid } from "../oauth/auth";
import { OAuthBrokerError, OAuthBrokerErrorCode } from "../oauth/errors";
import {
  getFirestore,
  handleBrokerError,
  resolveKmsKeyName,
} from "../oauth/http";
import {
  initUpload,
  pollUntilComplete,
} from "./tiktok.publish";
import { listVideos } from "./tiktok.display";

const log = logger.withContext({ phase: "08", scope: "tiktok-routes" });

// ---------------------------------------------------------------------------
// /connectors/tiktok/publish/init
// ---------------------------------------------------------------------------

interface PublishInitBody {
  video_size?: number;
  caption?: string;
  privacy_level?: string;
}

async function handlePublishInit(req: Request, res: Response): Promise<void> {
  if (req.method !== "POST") {
    res.status(405).json({ error: "method_not_allowed" });
    return;
  }
  try {
    const uid = await requireFirebaseUid(req);
    const body = (req.body ?? {}) as PublishInitBody;
    const videoSize = Number(body.video_size);
    if (!Number.isFinite(videoSize) || videoSize <= 0) {
      throw new OAuthBrokerError(
        OAuthBrokerErrorCode.INTERNAL,
        "video_size must be a positive integer"
      );
    }

    const accessToken = await loadAccessToken(uid);

    const result = await initUpload(accessToken, videoSize);

    log.info("publish/init ok", {
      uid,
      publishID: result.publishID,
    });

    res.status(200).json({
      publish_id: result.publishID,
      upload_url: result.uploadURL,
      chunk_size: result.chunkSize,
      total_chunk_count: result.totalChunkCount,
    });
  } catch (err) {
    handleBrokerError(res, err);
  }
}

export const connectorsTikTokPublishInit = onRequest(
  { region: getRegion(), cors: false },
  requireAppCheck(handlePublishInit)
);

// ---------------------------------------------------------------------------
// /connectors/tiktok/publish/complete
// ---------------------------------------------------------------------------

interface PublishCompleteBody {
  publish_id?: string;
}

async function handlePublishComplete(
  req: Request,
  res: Response
): Promise<void> {
  if (req.method !== "POST") {
    res.status(405).json({ error: "method_not_allowed" });
    return;
  }
  try {
    const uid = await requireFirebaseUid(req);
    const body = (req.body ?? {}) as PublishCompleteBody;
    const publishID = body.publish_id;
    if (!publishID || typeof publishID !== "string") {
      throw new OAuthBrokerError(
        OAuthBrokerErrorCode.INTERNAL,
        "publish_id is required"
      );
    }
    const accessToken = await loadAccessToken(uid);

    // Respond to the client immediately; polling continues in the same
    // invocation (Cloud Functions v2 keeps the instance alive until the
    // promise resolves, up to its configured timeout).
    res.status(202).json({ publish_id: publishID, status: "polling" });

    const result = await pollUntilComplete({
      uid,
      userToken: accessToken,
      publishID,
      db: getFirestore(),
    });
    log.info("publish/complete finalized", {
      uid,
      publishID,
      state: result.terminalState,
    });
  } catch (err) {
    // `res` may already be closed by the 202 above; guard against double-send.
    if (!res.headersSent) {
      handleBrokerError(res, err);
    } else {
      log.error("publish/complete failed after 202", {
        message: (err as Error).message,
      });
    }
  }
}

export const connectorsTikTokPublishComplete = onRequest(
  { region: getRegion(), cors: false, timeoutSeconds: 900 },
  requireAppCheck(handlePublishComplete)
);

// ---------------------------------------------------------------------------
// /connectors/tiktok/videos
// ---------------------------------------------------------------------------

async function handleListVideos(req: Request, res: Response): Promise<void> {
  if (req.method !== "GET") {
    res.status(405).json({ error: "method_not_allowed" });
    return;
  }
  try {
    const uid = await requireFirebaseUid(req);
    const maxCountRaw = getQuery(req, "max_count") ?? "20";
    const cursorRaw = getQuery(req, "cursor");
    const maxCount = Number(maxCountRaw);
    const cursor = cursorRaw ? Number(cursorRaw) : null;
    if (!Number.isFinite(maxCount)) {
      throw new OAuthBrokerError(
        OAuthBrokerErrorCode.INTERNAL,
        "max_count must be numeric"
      );
    }

    const accessToken = await loadAccessToken(uid);
    const result = await listVideos(accessToken, cursor, maxCount);

    res.status(200).json({
      videos: result.videos,
      cursor: result.cursor,
      has_more: result.has_more,
    });
  } catch (err) {
    handleBrokerError(res, err);
  }
}

export const connectorsTikTokVideos = onRequest(
  { region: getRegion(), cors: false },
  requireAppCheck(handleListVideos)
);

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/**
 * Load the user's TikTok access token from Firestore. Raises
 * `CONNECTION_NOT_FOUND` when the user hasn't connected yet.
 */
async function loadAccessToken(uid: string): Promise<string> {
  const result = await readConnection(uid, "tiktok", {
    db: getFirestore(),
    kmsKeyName: resolveKmsKeyName(),
  });
  if (!result) {
    throw new OAuthBrokerError(
      OAuthBrokerErrorCode.CONNECTION_NOT_FOUND,
      "no tiktok connection for user"
    );
  }
  if (result.revokedAt) {
    throw new OAuthBrokerError(
      OAuthBrokerErrorCode.CONNECTION_NOT_FOUND,
      "tiktok connection is revoked"
    );
  }
  return result.accessToken;
}

function getQuery(req: Request, name: string): string | null {
  const raw = req.query[name];
  if (typeof raw === "string" && raw.length > 0) return raw;
  if (Array.isArray(raw) && typeof raw[0] === "string") return raw[0];
  return null;
}
