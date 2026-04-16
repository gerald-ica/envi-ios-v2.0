/**
 * threadsWorker.ts — Phase 12 Pub/Sub worker for Threads publishes.
 *
 * Subscribes to `envi-publish-threads`. Threads has its own Graph endpoint
 * surface rooted at https://graph.threads.net; the publish flow mirrors
 * Instagram's two-step container pattern:
 *   1. POST /{threads-user-id}/threads         → container id
 *   2. POST /{threads-user-id}/threads_publish → final thread id
 *
 * Text-only threads are supported (unlike Instagram), so `mediaRefs` is
 * optional.
 */
import { createProviderWorker, PublishProviderError } from "../providerWorker";
import { readConnection } from "../../lib/tokenStorage";
import { resolveKmsKeyName } from "../../oauth/http";
import * as admin from "firebase-admin";
import { logger } from "../../lib/logger";

const log = logger.withContext({ phase: "12-03", worker: "threads" });

const GRAPH_BASE = "https://graph.threads.net/v1.0";

export const publishWorkerThreads = createProviderWorker(
  "threads",
  async (msg, ctx) => {
    if (admin.apps.length === 0) admin.initializeApp();
    const db = admin.firestore();

    const connection = await readConnection(msg.uid, "threads", {
      db,
      kmsKeyName: resolveKmsKeyName(),
    });
    if (!connection || connection.revokedAt) {
      throw new PublishProviderError("auth_expired", { retryable: false });
    }

    const threadsUserId = connection.providerUserId;

    // Step 1 — create container.
    const containerParams = new URLSearchParams({
      access_token: connection.accessToken,
      text: msg.caption,
    });
    const mediaPath = msg.mediaRefs[0];
    if (mediaPath) {
      const isVideo = mediaPath.toLowerCase().endsWith(".mp4");
      const [signedUrl] = await admin.storage().bucket().file(mediaPath).getSignedUrl({
        action: "read",
        expires: Date.now() + 10 * 60 * 1000,
      });
      if (isVideo) {
        containerParams.set("media_type", "VIDEO");
        containerParams.set("video_url", signedUrl);
      } else {
        containerParams.set("media_type", "IMAGE");
        containerParams.set("image_url", signedUrl);
      }
    } else {
      containerParams.set("media_type", "TEXT");
    }

    const containerRes = await fetch(
      `${GRAPH_BASE}/${threadsUserId}/threads`,
      { method: "POST", body: containerParams }
    );
    if (!containerRes.ok) {
      throw mapThreadsError(containerRes.status, await containerRes.text());
    }
    const containerJson = (await containerRes.json()) as { id?: string };
    const containerId = containerJson.id;
    if (!containerId) {
      throw new PublishProviderError("unknown", {
        retryable: false,
        message: "threads container missing id",
      });
    }

    // Step 2 — publish container.
    const publishParams = new URLSearchParams({
      creation_id: containerId,
      access_token: connection.accessToken,
    });
    const publishRes = await fetch(
      `${GRAPH_BASE}/${threadsUserId}/threads_publish`,
      { method: "POST", body: publishParams }
    );
    if (!publishRes.ok) {
      throw mapThreadsError(publishRes.status, await publishRes.text());
    }
    const publishJson = (await publishRes.json()) as { id?: string };
    const threadId = publishJson.id;
    if (!threadId) {
      throw new PublishProviderError("unknown", {
        retryable: false,
        message: "threads_publish missing id",
      });
    }

    log.info("threads publish succeeded", {
      jobId: msg.jobId, attempt: ctx.attempt, threadId,
    });
    return { providerPostId: threadId };
  }
);

function mapThreadsError(status: number, rawBody: string): PublishProviderError {
  if (status === 429) {
    return new PublishProviderError("rate_limited", { retryable: true });
  }
  if (status === 401 || status === 403) {
    return new PublishProviderError("auth_expired", { retryable: false });
  }
  if (status === 400) {
    return new PublishProviderError("media_rejected", {
      retryable: false,
      message: `threads rejected: ${rawBody.slice(0, 200)}`,
    });
  }
  return new PublishProviderError("unknown", {
    retryable: status >= 500,
    message: `threads HTTP ${status}`,
  });
}
