/**
 * dispatchScheduled.ts — Phase 12 scheduled-dispatch cron.
 *
 * Cloud Scheduler → Pub/Sub → `onSchedule`. Runs every 5 minutes. Queries
 * `publish_jobs` for docs with `status == "queued" AND scheduledAt <= now`
 * and fans out to Pub/Sub using the shared `fanOut` helper from
 * `dispatch.ts`.
 *
 * Why a separate cron (vs. a Firestore trigger):
 *   - Trigger fires on write; we'd have to set up a heartbeat doc. A
 *     polling cron is simpler, cheaper, and cleaner to reason about.
 *   - 5 min worst-case latency matches the iOS scheduled-publish UX copy
 *     ("within a few minutes"). Shorter cadence = more Firestore reads
 *     with no user-visible benefit.
 */
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";

import { logger } from "../lib/logger";
import { fanOut } from "../publish/dispatch";
import type { SupportedProvider } from "../lib/firestoreSchema";
import { getRegion } from "../lib/config";

const log = logger.withContext({ phase: "12-01", cron: "dispatchScheduled" });

export const dispatchScheduled = onSchedule(
  {
    schedule: "every 5 minutes",
    region: getRegion(),
    timeZone: "Etc/UTC",
  },
  async () => {
    if (admin.apps.length === 0) admin.initializeApp();
    const db = admin.firestore();

    const now = admin.firestore.Timestamp.now();
    const query = await db
      .collection("publish_jobs")
      .where("status", "==", "queued")
      .where("scheduledAt", "<=", now)
      .limit(200)
      .get();

    if (query.empty) {
      log.info("no scheduled jobs due");
      return;
    }

    for (const doc of query.docs) {
      const data = doc.data();
      const platformsBlock = (data.platforms ?? {}) as Record<string, unknown>;
      const platforms = Object.keys(platformsBlock) as SupportedProvider[];
      const uid = data.uid as string;
      const caption = data.caption as string;
      const mediaRefs = (data.mediaRefs ?? []) as string[];

      try {
        await fanOut(doc.id, uid, platforms, caption, mediaRefs);
        log.info("fanned out scheduled job", { jobId: doc.id, platforms });
      } catch (err) {
        // Don't mark the job failed — let the next cron tick retry. Idempotency
        // is guaranteed because fanOut re-publishes to per-platform topics
        // and the worker's idempotency guard skips already-posted platforms.
        log.warn("scheduled dispatch failed", {
          jobId: doc.id,
          err: err instanceof Error ? err.message : String(err),
        });
      }
    }
  }
);
