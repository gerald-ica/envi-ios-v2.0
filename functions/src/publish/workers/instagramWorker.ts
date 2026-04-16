/**
 * instagramWorker.ts — Phase 12 Pub/Sub worker for Instagram Graph publishes.
 *
 * Subscribes to `envi-publish-instagram`. Uses the two-step Graph publish
 * contract:
 *   1. POST /{ig-user-id}/media          → container id
 *   2. POST /{ig-user-id}/media_publish  → final media id
 *
 * This file deliberately keeps the publish primitive inline rather than
 * extracting it to `providers/instagram-publish.ts` — Phase 10 ships Meta
 * as an OAuth adapter only; the first publish primitive needed in
 * production arrives with Phase 12. When a second caller needs it, extract.
 */
import { createProviderWorker, PublishProviderError } from "../providerWorker";
import { readConnection } from "../../lib/tokenStorage";
import { resolveKmsKeyName } from "../../oauth/http";
import * as admin from "firebase-admin";
import { logger } from "../../lib/logger";

const log = logger.withContext({ phase: "12-03", worker: "instagram" });

const GRAPH_BASE = "https://graph.facebook.com/v20.0";

export const publishWorkerInstagram = createProviderWorker(
  "instagram",
  async (msg, ctx) => {
    if (admin.apps.length === 0) admin.initializeApp();
    const db = admin.firestore();

    const connection = await readConnection(msg.uid, "instagram", {
      db,
      kmsKeyName: resolveKmsKeyName(),
    });
    if (!connection || connection.revokedAt) {
      throw new PublishProviderError("auth_expired", { retryable: false });
    }

    const igUserId = connection.providerUserId;
    const mediaPath = msg.mediaRefs[0];
    if (!mediaPath) {
      // IG Graph API requires either an image_url or video_url. Text-only
      // posts are not supported by the Graph Content Publishing API.
      throw new PublishProviderError("media_rejected", {
        retryable: false,
        message: "instagram requires a media ref",
      });
    }

    // Resolve a public URL for the stored object. For v1 we rely on signed
    // URLs with a short TTL; the Graph API ingests within ~30s.
    const [signedUrl] = await admin.storage().bucket().file(mediaPath).getSignedUrl({
      action: "read",
      expires: Date.now() + 10 * 60 * 1000,
    });
    const isVideo = mediaPath.toLowerCase().endsWith(".mp4");

    // Step 1 — create container.
    const containerParams = new URLSearchParams({
      caption: msg.caption,
      ...(isVideo
        ? { media_type: "REELS", video_url: signedUrl }
        : { image_url: signedUrl }),
      access_token: connection.accessToken,
    });
    const containerRes = await fetch(
      `${GRAPH_BASE}/${igUserId}/media`,
      { method: "POST", body: containerParams }
    );
    if (!containerRes.ok) {
      throw mapGraphError(containerRes.status, await containerRes.text());
    }
    const containerJson = (await containerRes.json()) as { id?: string };
    const containerId = containerJson.id;
    if (!containerId) {
      throw new PublishProviderError("unknown", {
        retryable: false,
        message: "ig container missing id",
      });
    }

    // Step 2 — publish container.
    const publishParams = new URLSearchParams({
      creation_id: containerId,
      access_token: connection.accessToken,
    });
    const publishRes = await fetch(
      `${GRAPH_BASE}/${igUserId}/media_publish`,
      { method: "POST", body: publishParams }
    );
    if (!publishRes.ok) {
      throw mapGraphError(publishRes.status, await publishRes.text());
    }
    const publishJson = (await publishRes.json()) as { id?: string };
    const mediaId = publishJson.id;
    if (!mediaId) {
      throw new PublishProviderError("unknown", {
        retryable: false,
        message: "ig media_publish missing id",
      });
    }

    log.info("instagram publish succeeded", {
      jobId: msg.jobId, attempt: ctx.attempt, mediaId,
    });
    return { providerPostId: mediaId };
  }
);

function mapGraphError(status: number, rawBody: string): PublishProviderError {
  const lower = rawBody.toLowerCase();
  if (status === 429 || lower.includes("rate")) {
    return new PublishProviderError("rate_limited", { retryable: true });
  }
  if (status === 401 || status === 403 || lower.includes("oauth")) {
    return new PublishProviderError("auth_expired", { retryable: false });
  }
  if (status === 400 || lower.includes("media")) {
    return new PublishProviderError("media_rejected", {
      retryable: false,
      message: `graph rejected: ${rawBody.slice(0, 200)}`,
    });
  }
  return new PublishProviderError("unknown", {
    retryable: status >= 500,
    message: `graph HTTP ${status}`,
  });
}
