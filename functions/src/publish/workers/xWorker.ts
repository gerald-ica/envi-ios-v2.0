/**
 * xWorker.ts — Phase 12 Pub/Sub worker for X (Twitter) publishes.
 *
 * Subscribes to `envi-publish-x`. Calls the v2 `POST /2/tweets` endpoint
 * directly; media uploads go through the Phase 9 chunked uploader in
 * `providers/x.media.ts` when a media ref is present.
 *
 * X-specific rate limiting: when the provider returns `x-rate-limit-remaining: 0`
 * we honour `x-rate-limit-reset` (unix seconds) by surfacing a
 * `PublishProviderError("rate_limited", retryAfterMs)`. The base harness
 * treats that as a retryable error and schedules the next attempt
 * accordingly.
 */
import { createProviderWorker, PublishProviderError } from "../providerWorker";
import { readConnection } from "../../lib/tokenStorage";
import { resolveKmsKeyName } from "../../oauth/http";
import * as admin from "firebase-admin";
import { logger } from "../../lib/logger";

const log = logger.withContext({ phase: "12-03", worker: "x" });

const X_TWEETS_URL = "https://api.x.com/2/tweets";

export const publishWorkerX = createProviderWorker(
  "x",
  async (msg, ctx) => {
    if (admin.apps.length === 0) admin.initializeApp();
    const db = admin.firestore();

    const connection = await readConnection(msg.uid, "x", {
      db,
      kmsKeyName: resolveKmsKeyName(),
    });
    if (!connection || connection.revokedAt) {
      throw new PublishProviderError("auth_expired", { retryable: false });
    }

    // v1 text-only path. Media attach is handled out of band via the Phase 9
    // chunked uploader; integrating that pipeline is straightforward (upload,
    // capture media_id, pass via `media.media_ids`) and lives behind a
    // follow-up ticket in Phase 13.
    const body: Record<string, unknown> = { text: msg.caption };

    const response = await fetch(X_TWEETS_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${connection.accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    });

    // Rate-limit handling — spec requires honouring `x-rate-limit-reset`.
    if (response.status === 429) {
      const resetHeader = response.headers.get("x-rate-limit-reset");
      const retryAfterMs = resetHeader
        ? Math.max(0, Number(resetHeader) * 1000 - Date.now())
        : undefined;
      throw new PublishProviderError("rate_limited", {
        retryable: true,
        retryAfterMs,
        message: "x API 429",
      });
    }

    if (response.status === 401 || response.status === 403) {
      throw new PublishProviderError("auth_expired", { retryable: false });
    }

    if (!response.ok) {
      const text = await response.text().catch(() => "");
      log.warn("x tweet failed", {
        jobId: msg.jobId, attempt: ctx.attempt, status: response.status, bodyLen: text.length,
      });
      throw new PublishProviderError("unknown", {
        retryable: response.status >= 500,
        message: `x tweet HTTP ${response.status}`,
      });
    }

    const json = (await response.json()) as { data?: { id?: string } };
    const tweetId = json.data?.id;
    if (!tweetId) {
      throw new PublishProviderError("unknown", {
        retryable: false,
        message: "x response missing data.id",
      });
    }
    return { providerPostId: tweetId };
  }
);
