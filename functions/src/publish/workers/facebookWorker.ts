/**
 * facebookWorker.ts — Phase 12 Pub/Sub worker for Facebook Page feed posts.
 *
 * Subscribes to `envi-publish-facebook`. The connection stores the page
 * access token (not the user token) after the Phase 10 page-selection step,
 * so all Graph calls here use `connection.accessToken` directly.
 *
 * Single-endpoint flow:
 *   POST https://graph.facebook.com/v20.0/{page-id}/feed
 *     body: message=<caption>, link?=<url>, access_token=<page-token>
 *
 * Photo/video attachments use the `/photos` and `/videos` endpoints
 * respectively; the branch below keys off file extension.
 */
import { createProviderWorker, PublishProviderError } from "../providerWorker";
import { readConnection } from "../../lib/tokenStorage";
import { resolveKmsKeyName } from "../../oauth/http";
import * as admin from "firebase-admin";
import { logger } from "../../lib/logger";

const log = logger.withContext({ phase: "12-03", worker: "facebook" });

const GRAPH_BASE = "https://graph.facebook.com/v20.0";

export const publishWorkerFacebook = createProviderWorker(
  "facebook",
  async (msg, ctx) => {
    if (admin.apps.length === 0) admin.initializeApp();
    const db = admin.firestore();

    const connection = await readConnection(msg.uid, "facebook", {
      db,
      kmsKeyName: resolveKmsKeyName(),
    });
    if (!connection || connection.revokedAt) {
      throw new PublishProviderError("auth_expired", { retryable: false });
    }

    const pageId = connection.providerUserId;
    const mediaPath = msg.mediaRefs[0];

    let endpoint: string;
    const params = new URLSearchParams({
      access_token: connection.accessToken,
    });

    if (!mediaPath) {
      endpoint = `${GRAPH_BASE}/${pageId}/feed`;
      params.set("message", msg.caption);
    } else {
      const isVideo = mediaPath.toLowerCase().endsWith(".mp4");
      const [signedUrl] = await admin.storage().bucket().file(mediaPath).getSignedUrl({
        action: "read",
        expires: Date.now() + 10 * 60 * 1000,
      });
      if (isVideo) {
        endpoint = `${GRAPH_BASE}/${pageId}/videos`;
        params.set("description", msg.caption);
        params.set("file_url", signedUrl);
      } else {
        endpoint = `${GRAPH_BASE}/${pageId}/photos`;
        params.set("caption", msg.caption);
        params.set("url", signedUrl);
      }
    }

    const res = await fetch(endpoint, { method: "POST", body: params });
    if (!res.ok) {
      const body = await res.text();
      if (res.status === 429) {
        throw new PublishProviderError("rate_limited", { retryable: true });
      }
      if (res.status === 401 || res.status === 403) {
        throw new PublishProviderError("auth_expired", { retryable: false });
      }
      if (res.status === 400) {
        throw new PublishProviderError("media_rejected", {
          retryable: false,
          message: `facebook graph rejected: ${body.slice(0, 200)}`,
        });
      }
      throw new PublishProviderError("unknown", {
        retryable: res.status >= 500,
        message: `facebook HTTP ${res.status}`,
      });
    }

    const json = (await res.json()) as { id?: string; post_id?: string };
    const postId = json.post_id ?? json.id;
    if (!postId) {
      throw new PublishProviderError("unknown", {
        retryable: false,
        message: "facebook missing post id",
      });
    }

    log.info("facebook publish succeeded", {
      jobId: msg.jobId, attempt: ctx.attempt, postId,
    });
    return { providerPostId: postId };
  }
);
