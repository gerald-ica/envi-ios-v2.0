/**
 * dispatch.ts — Phase 12-01 publish dispatcher.
 *
 * Firebase Callable (2nd gen). Owns the iOS-facing entry point for
 * multi-platform publishing. Creates a `publish_jobs/{jobId}` Firestore
 * doc, then fans out one Pub/Sub message per platform to topic
 * `envi-publish-{platform}`. Per-platform workers (see `workers/*.ts`)
 * subscribe, run the provider publish primitive, update the doc, and
 * re-derive the top-level status.
 *
 * Request shape
 * -------------
 *   {
 *     caption:      string;
 *     platforms:    string[];    // apiSlug values
 *     mediaRefs:    string[];    // Cloud Storage object paths
 *     scheduledAt?: string;      // ISO-8601
 *   }
 *
 * Response
 * --------
 *   { jobId: string; status: "queued" }
 *
 * Scheduled posts
 * ---------------
 * If `scheduledAt` is absent OR within 30s of now, we fan out immediately.
 * For further-future schedules, we write the doc with `status: "queued"`
 * and let `envi-cron-dispatch-scheduled` (see `crons/dispatchScheduled.ts`)
 * run every 5 min and publish the Pub/Sub messages when the window opens.
 *
 * Error sanitization
 * ------------------
 * This module only validates; worker errors are sanitized server-side in
 * `providerWorker.ts`. Client-visible errors here are strict
 * `UNAUTHENTICATED` / `INVALID_ARGUMENT` codes.
 */
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { PubSub } from "@google-cloud/pubsub";
import * as admin from "firebase-admin";

import { logger } from "../lib/logger";
import { SUPPORTED_PROVIDERS, type SupportedProvider } from "../lib/firestoreSchema";
import { getRegion } from "../lib/config";

const log = logger.withContext({ phase: "12-01", fn: "publishDispatch" });

// Threshold below which we treat `scheduledAt` as "publish now". 30s chosen
// because Pub/Sub delivery + worker cold start already eats ~2-5s, so a
// tighter window provides no UX value but risks double-fan-out with the cron.
const IMMEDIATE_DISPATCH_WINDOW_MS = 30_000;

// Pub/Sub topic name pattern. Per-platform to keep backpressure isolated —
// TikTok outages shouldn't block the LinkedIn queue.
export function publishTopicName(platform: SupportedProvider): string {
  return `envi-publish-${platform}`;
}

interface DispatchRequest {
  caption: string;
  platforms: string[];
  mediaRefs: string[];
  scheduledAt?: string;
}

interface DispatchResponse {
  jobId: string;
  status: "queued";
}

// Pub/Sub singleton — reused across warm invocations.
let pubSubClient: PubSub | null = null;
function getPubSub(): PubSub {
  if (!pubSubClient) pubSubClient = new PubSub();
  return pubSubClient;
}

/** Ensure firebase-admin is initialised once per process. */
function ensureAdmin(): void {
  if (admin.apps.length === 0) admin.initializeApp();
}

export const publishDispatch = onCall<DispatchRequest, Promise<DispatchResponse>>(
  { region: getRegion() },
  async (request) => {
    ensureAdmin();

    // 1. Authn gate. onCall v2 provides `request.auth`.
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Firebase auth required");
    }

    // 2. Validate payload shape.
    const { caption, platforms, mediaRefs, scheduledAt } = request.data ?? {};
    if (typeof caption !== "string") {
      throw new HttpsError("invalid-argument", "caption must be a string");
    }
    if (!Array.isArray(platforms) || platforms.length === 0) {
      throw new HttpsError("invalid-argument", "platforms must be a non-empty array");
    }
    if (!Array.isArray(mediaRefs)) {
      throw new HttpsError("invalid-argument", "mediaRefs must be an array");
    }

    // 3. Platform slug whitelist check. We reject unknowns up front rather
    //    than writing a doc with a bad platform slug the workers can't route.
    const unknown = platforms.filter(
      (p): p is string => !SUPPORTED_PROVIDERS.includes(p as SupportedProvider)
    );
    if (unknown.length > 0) {
      throw new HttpsError(
        "invalid-argument",
        `unknown platform(s): ${unknown.join(",")}`
      );
    }
    const validPlatforms = platforms as SupportedProvider[];

    // 4. Parse optional scheduledAt.
    let scheduledAtMs: number | null = null;
    if (scheduledAt) {
      const parsed = Date.parse(scheduledAt);
      if (Number.isNaN(parsed)) {
        throw new HttpsError("invalid-argument", "scheduledAt must be ISO-8601");
      }
      scheduledAtMs = parsed;
    }

    const nowMs = Date.now();
    const immediate =
      scheduledAtMs === null || scheduledAtMs - nowMs <= IMMEDIATE_DISPATCH_WINDOW_MS;

    // 5. Create Firestore doc.
    const db = admin.firestore();
    const jobRef = db.collection("publish_jobs").doc();

    const platformsBlock: Record<string, unknown> = {};
    for (const p of validPlatforms) {
      platformsBlock[p] = {
        status: "queued",
        providerPostId: null,
        error: null,
        attempts: 0,
        lastAttemptAt: null,
        postedAt: null,
      };
    }

    await jobRef.set({
      uid,
      caption,
      mediaRefs,
      scheduledAt: scheduledAtMs
        ? admin.firestore.Timestamp.fromMillis(scheduledAtMs)
        : null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      status: "queued",
      platforms: platformsBlock,
    });

    log.info("publish job created", {
      jobId: jobRef.id,
      uid,
      platforms: validPlatforms,
      immediate,
    });

    // 6. Fan out to Pub/Sub iff immediate. Scheduled jobs wait for the cron.
    if (immediate) {
      await fanOut(jobRef.id, uid, validPlatforms, caption, mediaRefs);
    }

    return { jobId: jobRef.id, status: "queued" };
  }
);

/**
 * Publish one Pub/Sub message per platform. Exported so the scheduled-
 * dispatch cron can reuse the same code path.
 */
export async function fanOut(
  jobId: string,
  uid: string,
  platforms: SupportedProvider[],
  caption: string,
  mediaRefs: string[]
): Promise<void> {
  const ps = getPubSub();
  await Promise.all(
    platforms.map(async (platform) => {
      const topic = ps.topic(publishTopicName(platform));
      await topic.publishMessage({
        json: { jobId, uid, platform, caption, mediaRefs },
      });
    })
  );
  log.info("publish fan-out complete", { jobId, platforms });
}
