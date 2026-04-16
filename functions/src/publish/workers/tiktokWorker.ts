/**
 * tiktokWorker.ts — Phase 12 Pub/Sub worker for TikTok publishes.
 *
 * Subscribes to `envi-publish-tiktok`. For each message, loads the user's
 * encrypted connection, then delegates to the Phase 8 TikTok publish
 * primitives (`initUpload`, `pollUntilComplete`). The base harness
 * (`providerWorker.ts`) owns retry / DLQ / idempotency.
 */
import { createProviderWorker, PublishProviderError } from "../providerWorker";
import { readConnection } from "../../lib/tokenStorage";
import { resolveKmsKeyName } from "../../oauth/http";
import * as admin from "firebase-admin";
import { initUpload, pollUntilComplete } from "../../providers/tiktok.publish";
import { logger } from "../../lib/logger";

const log = logger.withContext({ phase: "12-03", worker: "tiktok" });

export const publishWorkerTikTok = createProviderWorker(
  "tiktok",
  async (msg, ctx) => {
    if (admin.apps.length === 0) admin.initializeApp();
    const db = admin.firestore();

    const connection = await readConnection(msg.uid, "tiktok", {
      db,
      kmsKeyName: resolveKmsKeyName(),
    });
    if (!connection) {
      throw new PublishProviderError("auth_expired", {
        retryable: false,
        message: "tiktok connection missing",
      });
    }
    if (connection.revokedAt || connection.expiresAt.toMillis() < Date.now()) {
      throw new PublishProviderError("auth_expired", { retryable: false });
    }

    // Phase 12 end-to-end TikTok publish requires a media ref. Caption is
    // emitted as the clip description by the iOS editor upload step; the
    // worker needs the object path (msg.mediaRefs[0]).
    const mediaPath = msg.mediaRefs[0];
    if (!mediaPath) {
      throw new PublishProviderError("media_rejected", {
        retryable: false,
        message: "tiktok publish requires a media ref",
      });
    }
    const [metadata] = await admin.storage().bucket().file(mediaPath).getMetadata();
    const sizeBytes = Number(metadata.size ?? 0);

    const init = await initUpload(connection.accessToken, sizeBytes);
    // pollUntilComplete signature (Phase 8) requires { db, uid, publishID,
    // userToken, ... }. We pass the same Firestore handle so the existing
    // per-publish status mirror under `users/{uid}/connections/tiktok/publishes`
    // keeps working.
    const final = await pollUntilComplete({
      db,
      uid: msg.uid,
      publishID: init.publishID,
      userToken: connection.accessToken,
    });
    log.info("tiktok publish complete", {
      jobId: msg.jobId,
      attempt: ctx.attempt,
      publishID: init.publishID,
      terminalState: final.terminalState,
    });
    if (final.terminalState === "FAILED") {
      throw new PublishProviderError("media_rejected", {
        retryable: false,
        message: `tiktok terminal FAILED: ${final.reason ?? "unknown"}`,
      });
    }
    return { providerPostId: init.publishID };
  }
);
