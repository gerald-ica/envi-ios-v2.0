/**
 * insightsSyncBase.ts — abstract base class for the 6 nightly provider
 * sync functions (tiktok, instagram, facebook, threads, linkedin, x).
 *
 * Concrete subclasses override ONLY `fetchMetrics`; the base handles:
 *   1. Iterating all users with a non-revoked connection to the provider.
 *   2. Token-bucket rate limiting against `_rateLimit/{provider}/{date}`.
 *   3. Fetch → write `DailySnapshot` → trigger rollup aggregator.
 *   4. Deferring overflow UIDs to Cloud Tasks with exp backoff + jitter.
 *   5. Emitting `insights_sync_*` telemetry events.
 *
 * Subclasses never touch Firestore directly — they return a pure
 * `DailySnapshot` and the base persists it. Keeps per-provider files
 * thin and testable.
 */
import * as admin from "firebase-admin";
import { logger } from "../../lib/logger";
import { readConnection } from "../../lib/tokenStorage";
import type { SupportedProvider } from "../../lib/firestoreSchema";
import {
  RATE_LIMIT_CONFIG,
  effectiveCap,
  backoffWithJitter,
} from "./rateLimitConfig";
import {
  dailySnapshotPath,
  dateKeyUTC,
  type DailySnapshot,
} from "./snapshotSchema";
import { aggregateOnTriggerDates } from "./rollupAggregator";

const log = logger.withContext({ phase: "13-01" });

/**
 * Injected dependencies. All optional so production callers get sensible
 * defaults and tests can stub Firestore / KMS / clock.
 */
export interface SyncContext {
  db?: admin.firestore.Firestore;
  kmsKeyName?: string;
  now?: () => Date;
  /** For tests — pin the UTC date key rather than reading `now()`. */
  dateKeyOverride?: string;
}

export interface SyncResult {
  provider: SupportedProvider;
  dateKey: string;
  processed: number;
  skippedRateLimited: number;
  deferred: number;
  errors: number;
}

export abstract class InsightsSyncBase {
  /** Must match the `SocialPlatform` slug on iOS. */
  abstract readonly provider: SupportedProvider;

  /**
   * Fetch one day of metrics for a single user. The base class calls this
   * once per UID after checking the token bucket.
   *
   * @param uid   — Firebase Auth user id.
   * @param token — Decrypted OAuth access token for the provider.
   * @param date  — UTC `yyyy-mm-dd` the metrics should land under.
   * @returns     — A fully-formed `DailySnapshot` ready for persistence.
   *                Subclasses MUST NOT write to Firestore; the base does.
   */
  abstract fetchMetrics(
    uid: string,
    token: string,
    date: string,
    providerUserId: string
  ): Promise<DailySnapshot>;

  async run(context: SyncContext = {}): Promise<SyncResult> {
    const db = context.db ?? admin.firestore();
    const nowFn = context.now ?? (() => new Date());
    const dateKey = context.dateKeyOverride ?? dateKeyUTC(nowFn());
    const provider = this.provider;

    const result: SyncResult = {
      provider,
      dateKey,
      processed: 0,
      skippedRateLimited: 0,
      deferred: 0,
      errors: 0,
    };

    // 1. Locate all users with an active connection for this provider via
    //    a collection-group query. `isConnected`/`revokedAt` already exist
    //    in the connection doc shape (Phase 6).
    const connSnap = await db
      .collectionGroup("connections")
      .where("provider", "==", provider)
      .where("revokedAt", "==", null)
      .get();

    if (connSnap.empty) {
      log.info("no active connections", { provider, dateKey });
      return result;
    }

    // 2. Prepare the rate-limit bucket doc for the day.
    const bucketRef = db.doc(`_rateLimit/${provider}/${dateKey}/counter`);
    const policy = RATE_LIMIT_CONFIG[provider];
    const cap = effectiveCap(policy);

    for (const doc of connSnap.docs) {
      const uid = doc.ref.parent.parent?.id;
      if (!uid) continue;

      // 2a. Attempt atomic increment; if the bucket is full, defer.
      let admitted = false;
      try {
        admitted = await db.runTransaction(async (tx) => {
          const snap = await tx.get(bucketRef);
          const used = (snap.exists ? snap.data()?.count ?? 0 : 0) as number;
          if (used >= cap) return false;
          tx.set(bucketRef, { count: used + 1, cap, provider, dateKey }, { merge: true });
          return true;
        });
      } catch (err) {
        log.warn("bucket tx failed — treating as deferred", {
          uid,
          provider,
          error: (err as Error).message,
        });
      }

      if (!admitted) {
        result.skippedRateLimited += 1;
        await this.deferUid(db, uid, dateKey);
        result.deferred += 1;
        continue;
      }

      // 2b. Decrypt the access token via existing storage helper.
      let accessToken: string | null = null;
      let providerUserId = "";
      try {
        const read = await readConnection(uid, provider, {
          db,
          kmsKeyName: context.kmsKeyName ?? resolveKmsKey(),
        });
        if (!read) {
          log.warn("connection vanished between query and read", { uid, provider });
          continue;
        }
        accessToken = read.accessToken;
        providerUserId = read.providerUserId;
      } catch (err) {
        log.error("token decrypt failed", { uid, provider, error: (err as Error).message });
        result.errors += 1;
        continue;
      }

      // 2c. Fetch + persist, with per-UID retry/backoff.
      let success = false;
      for (let attempt = 0; attempt < policy.maxRetries && !success; attempt += 1) {
        try {
          const snapshot = await this.fetchMetrics(uid, accessToken, dateKey, providerUserId);
          await db.doc(dailySnapshotPath(uid, provider, dateKey)).set({
            ...snapshot,
            syncedAt: admin.firestore.Timestamp.now(),
          });
          success = true;
        } catch (err) {
          const delay = backoffWithJitter(policy, attempt);
          log.warn("fetchMetrics failed — backing off", {
            uid,
            provider,
            attempt,
            delayMs: Math.round(delay),
            error: (err as Error).message,
          });
          await sleep(delay);
        }
      }

      if (success) {
        result.processed += 1;
        // 2d. Kick the rollup aggregator for this UID + provider on the fly
        //     (weekly + monthly). Cheap: it only touches the last 7/30 docs.
        try {
          await aggregateOnTriggerDates(db, uid, provider, dateKey);
        } catch (err) {
          log.warn("rollup aggregation failed", {
            uid,
            provider,
            error: (err as Error).message,
          });
        }
      } else {
        result.errors += 1;
      }
    }

    log.info("sync complete", result);
    return result;
  }

  /**
   * Defer a UID to the next sync window by writing a queue doc. A
   * dedicated Cloud Task enqueues on this doc; if Cloud Tasks isn't wired
   * (emulator, unit tests) the doc still lives in Firestore and can be
   * inspected / retried manually.
   */
  private async deferUid(
    db: admin.firestore.Firestore,
    uid: string,
    dateKey: string
  ): Promise<void> {
    const policy = RATE_LIMIT_CONFIG[this.provider];
    const delayMs = backoffWithJitter(policy, 0);
    await db
      .collection("_rateLimit")
      .doc(this.provider)
      .collection("deferred")
      .doc(`${dateKey}_${uid}`)
      .set({
        uid,
        provider: this.provider,
        dateKey,
        deferredAt: admin.firestore.Timestamp.now(),
        runAfter: admin.firestore.Timestamp.fromMillis(Date.now() + delayMs),
      });
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Resolve the KMS key name from env — mirrors the helper used by the
 * OAuth broker. Avoids importing `oauth/http` into this module which
 * pulls in a big HTTP graph.
 */
function resolveKmsKey(): string {
  const key = process.env.KMS_TOKEN_KEY_NAME;
  if (!key) {
    throw new Error("KMS_TOKEN_KEY_NAME env var not configured");
  }
  return key;
}
