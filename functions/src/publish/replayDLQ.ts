/**
 * replayDLQ.ts — Phase 12-03 ops Callable for replaying dead-lettered
 * per-platform publishes.
 *
 * Requires `request.auth.token.admin === true` (App Check + custom claim).
 * A regular end-user calling this callable will get `PERMISSION_DENIED`.
 *
 * Semantics:
 *   1. Look up `publish_jobs/{jobId}`.
 *   2. Reset `platforms[platform].status = "queued"` and `attempts = 0`.
 *   3. Clear the `platforms[platform].error` field.
 *   4. Re-derive top-level status (transactional).
 *   5. Re-publish one Pub/Sub message to `envi-publish-{platform}`.
 *
 * The ops UI (not shipped in Phase 12) will iterate over
 * `publish_dlq/{jobId}/platforms/*` and call this for each entry.
 */
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { PubSub } from "@google-cloud/pubsub";

import { logger } from "../lib/logger";
import { SUPPORTED_PROVIDERS, type SupportedProvider } from "../lib/firestoreSchema";
import { getRegion } from "../lib/config";
import { publishTopicName } from "./dispatch";

const log = logger.withContext({ phase: "12-03", fn: "replayDLQ" });

interface ReplayRequest {
  jobId: string;
  platform: string;
}

interface ReplayResponse {
  ok: true;
  attempt: 0;
}

let pubSubClient: PubSub | null = null;
function getPubSub(): PubSub {
  if (!pubSubClient) pubSubClient = new PubSub();
  return pubSubClient;
}

export const replayDLQ = onCall<ReplayRequest, Promise<ReplayResponse>>(
  { region: getRegion() },
  async (request) => {
    if (admin.apps.length === 0) admin.initializeApp();

    // Admin-only gate. Phase 12 does not ship an ops console, so the claim
    // is set manually via gcloud. A missing claim returns PERMISSION_DENIED.
    const token = request.auth?.token;
    if (!token || token.admin !== true) {
      throw new HttpsError("permission-denied", "admin claim required");
    }

    const { jobId, platform } = request.data ?? ({} as ReplayRequest);
    if (!jobId || typeof jobId !== "string") {
      throw new HttpsError("invalid-argument", "jobId required");
    }
    if (!SUPPORTED_PROVIDERS.includes(platform as SupportedProvider)) {
      throw new HttpsError("invalid-argument", `unknown platform: ${platform}`);
    }

    const db = admin.firestore();
    const jobRef = db.collection("publish_jobs").doc(jobId);

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(jobRef);
      if (!snap.exists) {
        throw new HttpsError("not-found", `job ${jobId} missing`);
      }
      tx.update(jobRef, {
        [`platforms.${platform}.status`]: "queued",
        [`platforms.${platform}.attempts`]: 0,
        [`platforms.${platform}.error`]: null,
        [`platforms.${platform}.lastAttemptAt`]: null,
      });
    });

    // Re-derive top-level status now that this platform is queued again.
    await reDeriveTopLevelStatus(jobRef);

    // Reload job doc for Pub/Sub payload (caption + mediaRefs).
    const snap = await jobRef.get();
    const data = snap.data() ?? {};

    await getPubSub()
      .topic(publishTopicName(platform as SupportedProvider))
      .publishMessage({
        json: {
          jobId,
          uid: data.uid,
          platform,
          caption: data.caption,
          mediaRefs: data.mediaRefs ?? [],
        },
      });

    // Clear DLQ mirror so ops doesn't see a stale entry.
    await db
      .collection("publish_dlq")
      .doc(jobId)
      .collection("platforms")
      .doc(platform)
      .delete()
      .catch(() => {
        /* ignore: mirror may have TTL'd or never been written */
      });

    log.info("dlq replay enqueued", { jobId, platform });
    return { ok: true, attempt: 0 };
  }
);

async function reDeriveTopLevelStatus(
  jobRef: FirebaseFirestore.DocumentReference
): Promise<void> {
  const db = admin.firestore();
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(jobRef);
    if (!snap.exists) return;
    const data = snap.data() ?? {};
    const platforms = (data.platforms ?? {}) as Record<string, { status?: string }>;
    const statuses = Object.values(platforms).map((p) => p.status ?? "queued");

    let next = "queued";
    if (statuses.length > 0) {
      if (statuses.every((s) => s === "posted")) next = "posted";
      else if (statuses.every((s) => s === "failed" || s === "dlq")) next = "failed";
      else if (
        statuses.some((s) => s === "posted") &&
        statuses.every((s) => s === "posted" || s === "failed" || s === "dlq")
      ) next = "partial";
      else next = "processing";
    }
    if (data.status !== next) tx.update(jobRef, { status: next });
  });
}
