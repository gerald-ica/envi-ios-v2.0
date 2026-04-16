/**
 * providerWorker.ts — shared retry + backoff + DLQ + idempotency harness
 * that every per-platform Pub/Sub worker wraps (see `workers/*.ts`).
 *
 * Phase 12-03. Replaces the direct provider calls in Phases 8-11 with a
 * single state machine:
 *
 *   [queued] → [processing] → [posted]
 *                   │
 *                   ↓
 *               [failed]  (if error but attempts < 3 → Pub/Sub retry)
 *                   │
 *                   ↓ (attempts >= 3)
 *               per-provider [dlq]
 *
 * Invariants the base enforces:
 *   1. IDEMPOTENCY — before doing any work, read the per-platform block
 *      from Firestore. If `status === "posted"`, ack + return silently.
 *      Pub/Sub's at-least-once delivery guarantees duplicate messages;
 *      the base guarantees duplicate PROCESSING.
 *   2. ATTEMPT COUNTING — the attempt number is derived from the stored
 *      `attempts` field, NOT from Pub/Sub's delivery count. The latter
 *      resets if we fail with a non-retryable error that we then decide
 *      to replay via `replayDLQ`.
 *   3. BACKOFF — 5s → 25s → 125s (geometric ×5). We don't sleep in the
 *      worker; we throw and rely on Pub/Sub's per-subscription ack deadline
 *      + retry policy to honour the delay. The scheduled delay is computed
 *      and surfaced via the `retryAt` field on the doc for observability.
 *   4. STATUS DERIVATION — after every write, re-compute the top-level
 *      `status` from the per-platform block INSIDE A FIRESTORE TRANSACTION.
 *      Two workers completing simultaneously would race; the transaction
 *      reads all sibling statuses atomically before writing the derivation.
 *   5. ERROR SANITIZATION — worker code only ever writes one of four
 *      sanitized codes to Firestore: `rate_limited`, `media_rejected`,
 *      `auth_expired`, `unknown`. Raw provider bodies stay in Cloud
 *      Function logs.
 */
import type { firestore as FirestoreNamespace } from "firebase-admin";
import * as admin from "firebase-admin";
import { onMessagePublished } from "firebase-functions/v2/pubsub";
import type { CloudEvent } from "firebase-functions/v2";
import type { MessagePublishedData } from "firebase-functions/v2/pubsub";

import { logger } from "../lib/logger";
import type { SupportedProvider } from "../lib/firestoreSchema";
import { getRegion } from "../lib/config";

const log = logger.withContext({ phase: "12-03", module: "providerWorker" });

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface PublishMessage {
  jobId: string;
  uid: string;
  platform: SupportedProvider;
  caption: string;
  mediaRefs: string[];
}

export interface PublishWorkResult {
  /** Provider's own post/tweet/media URN. Written to Firestore as-is. */
  providerPostId: string;
}

/** Sanitized error codes — exhaustive whitelist. */
export type PublishErrorCode =
  | "rate_limited"
  | "media_rejected"
  | "auth_expired"
  | "unknown";

export class PublishProviderError extends Error {
  readonly code: PublishErrorCode;
  /** For `rate_limited`: unix millis when we're allowed to retry. */
  readonly retryAfterMs?: number;
  /** Whether the error is transient (worth retrying) or terminal. */
  readonly retryable: boolean;

  constructor(
    code: PublishErrorCode,
    opts: { retryable?: boolean; retryAfterMs?: number; message?: string } = {}
  ) {
    super(opts.message ?? code);
    this.name = "PublishProviderError";
    this.code = code;
    this.retryable = opts.retryable ?? true;
    this.retryAfterMs = opts.retryAfterMs;
  }
}

/** Worker function that performs the actual provider publish. */
export type PublishWorkFn = (
  msg: PublishMessage,
  ctx: { attempt: number }
) => Promise<PublishWorkResult>;

// ---------------------------------------------------------------------------
// Tuning knobs
// ---------------------------------------------------------------------------

export const MAX_ATTEMPTS = 3;
/** Backoff schedule in ms: 5s, 25s, 125s. */
export const BACKOFF_MS = [5_000, 25_000, 125_000];

// ---------------------------------------------------------------------------
// Firestore handles
// ---------------------------------------------------------------------------

function ensureAdmin(): void {
  if (admin.apps.length === 0) admin.initializeApp();
}

function db(): FirestoreNamespace.Firestore {
  ensureAdmin();
  return admin.firestore();
}

// ---------------------------------------------------------------------------
// Factory
// ---------------------------------------------------------------------------

/**
 * Build an `onMessagePublished` handler for a platform topic. The returned
 * function is exported as a Cloud Function from each worker module.
 */
export function createProviderWorker(
  platform: SupportedProvider,
  work: PublishWorkFn
) {
  const topic = `envi-publish-${platform}`;

  return onMessagePublished<PublishMessage>(
    {
      topic,
      region: getRegion(),
      // Workers are write-light but may upload media; 256MB is ample.
      memory: "256MiB",
      // Firestore + Pub/Sub don't need outbound VPC.
      retry: true,
    },
    async (event: CloudEvent<MessagePublishedData<PublishMessage>>) => {
      await runWorker(platform, work, event);
    }
  );
}

// ---------------------------------------------------------------------------
// Core execution
// ---------------------------------------------------------------------------

async function runWorker(
  platform: SupportedProvider,
  work: PublishWorkFn,
  event: CloudEvent<MessagePublishedData<PublishMessage>>
): Promise<void> {
  const msg = event.data?.message?.json as PublishMessage | undefined;
  if (!msg || msg.platform !== platform) {
    log.error("malformed publish message", { platform, eventId: event.id });
    return;
  }

  const { jobId, uid } = msg;
  const jobRef = db().collection("publish_jobs").doc(jobId);

  // -- Idempotency guard: read current status. --
  const snap = await jobRef.get();
  if (!snap.exists) {
    log.error("publish job missing", { jobId, platform });
    return;
  }
  const data = snap.data() ?? {};
  const platformsBlock = (data.platforms ?? {}) as Record<string, {
    status?: string; attempts?: number;
  }>;
  const current = platformsBlock[platform] ?? {};

  if (current.status === "posted") {
    log.info("idempotent ack — already posted", { jobId, platform });
    return;
  }

  const storedAttempts = typeof current.attempts === "number" ? current.attempts : 0;
  const attempt = storedAttempts + 1;

  // -- Mark as processing BEFORE the provider call. --
  await jobRef.update({
    [`platforms.${platform}.status`]: "processing",
    [`platforms.${platform}.attempts`]: attempt,
    [`platforms.${platform}.lastAttemptAt`]: admin.firestore.FieldValue.serverTimestamp(),
  });
  await deriveTopLevelStatus(jobRef);

  try {
    const result = await work(msg, { attempt });

    // -- SUCCESS --
    await jobRef.update({
      [`platforms.${platform}.status`]: "posted",
      [`platforms.${platform}.providerPostId`]: result.providerPostId,
      [`platforms.${platform}.error`]: null,
      [`platforms.${platform}.postedAt`]: admin.firestore.FieldValue.serverTimestamp(),
    });
    await deriveTopLevelStatus(jobRef);
    await writeTelemetryEvent({
      name: "publish_provider_success",
      jobId, platform, uid, attempt,
    });
    log.info("provider publish succeeded", {
      jobId, platform, attempt, providerPostId: result.providerPostId,
    });
  } catch (err) {
    const code = coerceErrorCode(err);
    const retryable = err instanceof PublishProviderError ? err.retryable : true;
    const retryAfterMs =
      err instanceof PublishProviderError ? err.retryAfterMs : undefined;

    // Log the RAW error body to Cloud Function logs — stays server-side only.
    log.warn("provider publish failed", {
      jobId, platform, attempt, code,
      raw: err instanceof Error ? err.message : String(err),
    });

    const exhausted = attempt >= MAX_ATTEMPTS || !retryable;

    if (exhausted) {
      // DLQ terminal state.
      await jobRef.update({
        [`platforms.${platform}.status`]: "dlq",
        [`platforms.${platform}.error`]: code,
      });
      await deriveTopLevelStatus(jobRef);
      // Mirror to publish_dlq for ops queries.
      await db()
        .collection("publish_dlq")
        .doc(jobId)
        .collection("platforms")
        .doc(platform)
        .set({
          jobId,
          platform,
          uid,
          error: code,
          attempts: attempt,
          loggedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      await writeTelemetryEvent({
        name: "publish_provider_failure",
        jobId, platform, uid, attempt, error: code,
      });
      // Do NOT re-throw — DLQ is a terminal state we want Pub/Sub to ack.
      return;
    }

    // Retryable: write failed status + error code, then throw so Pub/Sub retries.
    await jobRef.update({
      [`platforms.${platform}.status`]: "failed",
      [`platforms.${platform}.error`]: code,
    });
    await deriveTopLevelStatus(jobRef);
    await writeTelemetryEvent({
      name: "publish_provider_failure",
      jobId, platform, uid, attempt, error: code,
    });

    // Compute scheduled delay (observability — Pub/Sub drives the actual wait).
    const delayMs = retryAfterMs ?? BACKOFF_MS[Math.min(attempt - 1, BACKOFF_MS.length - 1)];
    log.info("scheduling retry", { jobId, platform, attempt, delayMs });

    // Re-throw → Pub/Sub retries per subscription retry policy.
    throw err;
  }
}

// ---------------------------------------------------------------------------
// Error code coercion
// ---------------------------------------------------------------------------

function coerceErrorCode(err: unknown): PublishErrorCode {
  if (err instanceof PublishProviderError) return err.code;
  if (err instanceof Error) {
    const msg = err.message.toLowerCase();
    if (msg.includes("rate") || msg.includes("429")) return "rate_limited";
    if (msg.includes("401") || msg.includes("403") || msg.includes("auth")) {
      return "auth_expired";
    }
    if (msg.includes("media") || msg.includes("unsupported")) {
      return "media_rejected";
    }
  }
  return "unknown";
}

// ---------------------------------------------------------------------------
// Top-level status derivation (inside a transaction to prevent races)
// ---------------------------------------------------------------------------

async function deriveTopLevelStatus(
  jobRef: FirestoreNamespace.DocumentReference
): Promise<void> {
  await db().runTransaction(async (tx) => {
    const snap = await tx.get(jobRef);
    if (!snap.exists) return;
    const data = snap.data() ?? {};
    const platforms = (data.platforms ?? {}) as Record<string, { status?: string }>;
    const statuses = Object.values(platforms).map((p) => p.status ?? "queued");

    let newStatus: string;
    if (statuses.length === 0) {
      newStatus = "queued";
    } else if (statuses.every((s) => s === "posted")) {
      newStatus = "posted";
    } else if (statuses.every((s) => s === "failed" || s === "dlq")) {
      newStatus = "failed";
    } else if (
      statuses.some((s) => s === "posted") &&
      statuses.some((s) => s === "failed" || s === "dlq") &&
      statuses.every((s) => s === "posted" || s === "failed" || s === "dlq")
    ) {
      newStatus = "partial";
    } else {
      newStatus = "processing";
    }

    if (data.status !== newStatus) {
      tx.update(jobRef, { status: newStatus });
    }
  });
}

// ---------------------------------------------------------------------------
// Telemetry event mirror
// ---------------------------------------------------------------------------

/**
 * Write to `telemetry_events` so our Analytics pipeline picks it up without
 * pulling in firebase-admin Analytics (which isn't available server-side).
 */
interface TelemetryPayload {
  name: "publish_provider_success" | "publish_provider_failure";
  jobId: string;
  platform: SupportedProvider;
  uid: string;
  attempt: number;
  error?: string;
}

async function writeTelemetryEvent(payload: TelemetryPayload): Promise<void> {
  try {
    await db().collection("telemetry_events").add({
      name: payload.name,
      uid: payload.uid,
      params: {
        job_id: payload.jobId,
        platform: payload.platform,
        attempt: payload.attempt,
        ...(payload.error ? { error: payload.error } : {}),
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (err) {
    // Telemetry is best-effort; never fail the worker over an analytics miss.
    log.warn("telemetry_events write failed", {
      name: payload.name,
      err: err instanceof Error ? err.message : String(err),
    });
  }
}
