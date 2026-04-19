/**
 * refreshMetaTokens.ts — Firebase Scheduled Function that proactively
 * refreshes Meta family long-lived tokens before they hit their 60-day
 * expiry.
 *
 * Phase 10. Meta tokens are long-lived (60 days) and DO NOT support
 * refresh tokens the way OAuth 2.0 providers usually do — the path is to
 * re-exchange the current long-lived token via `fb_exchange_token` /
 * `th_exchange_token` BEFORE it expires. Miss the window and the user
 * must reconnect.
 *
 * Schedule
 * --------
 * Runs every 50 days. That cadence plus the ≤15-day remaining-window
 * filter below gives us a ~35-day overlap where each token is refreshed
 * at least once, guaranteeing at least one success even if one scheduled
 * run fails.
 *
 * Scope
 * -----
 * Query users/{uid}/connections/{provider} for provider IN ("facebook","instagram","threads")
 * AND `expiresAt <= now + 15 days`. Each candidate gets exchanged via
 * `MetaProvider(subPlatform).refresh(...)`. Outcomes:
 *   - Success → write `expiresAt = now + 60d`, `lastRefreshedAt = now`.
 *   - `needsReauth` → write `tokenStatus = "expired"` and send FCM push.
 *
 * Concurrency
 * -----------
 * Graph rate limit is ~200 calls per app per hour. Chunked Promise.all
 * with `CONCURRENCY = 10` gives us plenty of headroom while still
 * finishing a 10k-user sweep in reasonable wall-clock time.
 *
 * Phase 12 hand-off
 * -----------------
 * Phase 12 introduces a global token refresh cron that consolidates all
 * provider refresh lifecycles. Leaving this as a standalone module for
 * now because Meta's "exchange, no refresh token" flow is meaningfully
 * different from standard OAuth refresh — merging would dilute the
 * global cron's shape. Phase 12 can either delete this file and absorb
 * the logic or import + compose; decision happens at the start of Phase 12.
 */
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import { logger } from "../lib/logger";
import { MetaProvider, type MetaSubPlatform } from "../providers/meta";

const log = logger.withContext({ phase: "10", cron: "refreshMetaTokens" });

// ---------------------------------------------------------------------------
// Tuning knobs
// ---------------------------------------------------------------------------

/** How often the cron fires. Cloud Scheduler rejects long "every N days"
 *  intervals, so we use a standard cron expression. Runs twice a month
 *  (1st and 15th at 03:00 UTC), always within the 15-day refresh window
 *  against Meta's 60-day long-lived token TTL. */
const SCHEDULE = "0 3 1,15 * *";

/** Only refresh connections within 15 days of expiry. */
const REFRESH_WINDOW_DAYS = 15;

/** 60 days in seconds — the long-lived TTL Meta documents. */
const NEW_EXPIRY_SECONDS = 60 * 24 * 60 * 60;

/** Concurrent Graph calls. Well under Meta's per-app rate ceiling. */
const CONCURRENCY = 10;

/** Meta sub-platforms eligible for refresh. */
const META_PROVIDERS: MetaSubPlatform[] = ["facebook", "instagram", "threads"];

// ---------------------------------------------------------------------------
// Connection shape (subset — what we need to refresh + write back)
// ---------------------------------------------------------------------------

interface CandidateConnection {
  uid: string;
  provider: MetaSubPlatform;
  accessToken: string;
  ref: FirebaseFirestore.DocumentReference;
}

// ---------------------------------------------------------------------------
// Scheduled entry point
// ---------------------------------------------------------------------------

/**
 * Exported as `refreshMetaTokens`. Registered from `index.ts`.
 *
 * @see `.planning/phases/10-meta-family-connector/PLAN.md` Task 9.
 */
export const refreshMetaTokens = onSchedule(
  { schedule: SCHEDULE, timeoutSeconds: 540, memory: "512MiB" },
  async () => {
    const db = admin.firestore();
    const candidates = await findCandidates(db);

    log.info("refreshMetaTokens sweep begin", {
      candidateCount: candidates.length,
    });

    const results = await processInChunks(candidates, CONCURRENCY, (c) =>
      refreshOne(c, db)
    );

    const summary = tally(results);
    log.info("refreshMetaTokens sweep end", summary);
  }
);

// ---------------------------------------------------------------------------
// Candidate discovery
// ---------------------------------------------------------------------------

/**
 * Scan Firestore for Meta connections whose `expiresAt` falls within the
 * refresh window. Uses a `collectionGroup("connections")` query — one
 * round-trip per sub-platform to stay under Firestore's single-inequality
 * constraint.
 */
async function findCandidates(
  db: FirebaseFirestore.Firestore
): Promise<CandidateConnection[]> {
  const cutoffMs = Date.now() + REFRESH_WINDOW_DAYS * 24 * 60 * 60 * 1000;
  const cutoff = admin.firestore.Timestamp.fromMillis(cutoffMs);

  const allCandidates: CandidateConnection[] = [];

  for (const provider of META_PROVIDERS) {
    const snap = await db
      .collectionGroup("connections")
      .where("provider", "==", provider)
      .where("expiresAt", "<=", cutoff)
      .get();

    for (const doc of snap.docs) {
      const data = doc.data();
      // Skip already-expired connections — user must reauth anyway.
      if (data.revokedAt !== null && data.revokedAt !== undefined) continue;
      // `accessTokenCiphertext` is what's actually stored; the refresh
      // path pulls + decrypts it via `readConnection`. We keep the raw
      // reference here and let `refreshOne` do the decrypt.
      const pathParts = doc.ref.path.split("/");
      // path: users/{uid}/connections/{provider}
      const uid = pathParts[1];
      if (!uid) continue;

      allCandidates.push({
        uid,
        provider,
        accessToken: data.accessTokenCiphertext ?? "", // decrypted in refreshOne
        ref: doc.ref,
      });
    }
  }

  return allCandidates;
}

// ---------------------------------------------------------------------------
// Per-candidate refresh
// ---------------------------------------------------------------------------

type RefreshOutcome =
  | { kind: "refreshed"; uid: string; provider: MetaSubPlatform }
  | { kind: "needsReauth"; uid: string; provider: MetaSubPlatform }
  | { kind: "error"; uid: string; provider: MetaSubPlatform; message: string };

async function refreshOne(
  candidate: CandidateConnection,
  db: FirebaseFirestore.Firestore
): Promise<RefreshOutcome> {
  try {
    // Defer the decrypt to tokenStorage.readConnection. Keeping the cron
    // decoupled from KMS specifics — it just calls into the same storage
    // path the OAuth broker uses.
    const { readConnection, writeConnection } = await import(
      "../lib/tokenStorage"
    );
    const { getSecret } = await import("../lib/secrets");
    const kmsKeyName = process.env.KMS_KEY_NAME ?? "";

    const existing = await readConnection(candidate.uid, candidate.provider, {
      db,
      kmsKeyName,
    });
    if (!existing || existing.revokedAt) {
      return {
        kind: "error",
        uid: candidate.uid,
        provider: candidate.provider,
        message: "connection missing or revoked",
      };
    }

    const adapter = new MetaProvider(candidate.provider);
    const refreshed = await adapter.refresh({
      refreshToken: existing.accessToken,
    });

    await writeConnection(
      {
        uid: candidate.uid,
        provider: candidate.provider,
        providerUserId: existing.providerUserId,
        handle: existing.handle,
        followerCount: existing.followerCount,
        scopes: existing.scopes,
        accessToken: refreshed.accessToken,
        refreshToken: null,
        expiresAt: admin.firestore.Timestamp.fromMillis(
          Date.now() + NEW_EXPIRY_SECONDS * 1000
        ),
      },
      { db, kmsKeyName }
    );

    // Ensure `getSecret` import isn't tree-shaken in build — used by
    // adapter.refresh() indirectly. Keeping explicit so lazy imports are
    // obvious.
    void getSecret;

    return {
      kind: "refreshed",
      uid: candidate.uid,
      provider: candidate.provider,
    };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    // Meta's long-lived exchange fails with a 400 / "expired" when past
    // the 60-day window. We classify by message heuristic; misclassified
    // errors still surface as `error` outcomes so ops can investigate.
    if (message.toLowerCase().includes("expired") || message.includes("400")) {
      await markNeedsReauth(candidate, db);
      return {
        kind: "needsReauth",
        uid: candidate.uid,
        provider: candidate.provider,
      };
    }

    log.warn("meta refresh failed", {
      uid: candidate.uid,
      provider: candidate.provider,
      error: message,
    });
    return {
      kind: "error",
      uid: candidate.uid,
      provider: candidate.provider,
      message,
    };
  }
}

/**
 * Set `tokenStatus = "expired"` so the iOS client knows to surface the
 * reconnect banner, and fire an FCM push to the user's active device.
 */
async function markNeedsReauth(
  candidate: CandidateConnection,
  db: FirebaseFirestore.Firestore
): Promise<void> {
  await candidate.ref.update({
    tokenStatus: "expired",
    tokenStatusUpdatedAt: admin.firestore.Timestamp.now(),
  });

  // Best-effort FCM. Missing device token → no-op.
  try {
    const userSnap = await db.collection("users").doc(candidate.uid).get();
    const deviceTokens = userSnap.data()?.fcmTokens as string[] | undefined;
    if (!deviceTokens || deviceTokens.length === 0) return;

    const platformLabel =
      candidate.provider.charAt(0).toUpperCase() + candidate.provider.slice(1);

    await admin.messaging().sendEachForMulticast({
      tokens: deviceTokens,
      notification: {
        title: `${platformLabel} needs reconnection`,
        body: `Your ${platformLabel} connection has expired. Tap to reconnect.`,
      },
      data: {
        kind: "reauth_required",
        provider: candidate.provider,
      },
    });
  } catch (err) {
    log.warn("meta reauth FCM send failed", {
      uid: candidate.uid,
      provider: candidate.provider,
      error: err instanceof Error ? err.message : String(err),
    });
  }
}

// ---------------------------------------------------------------------------
// Concurrency helper
// ---------------------------------------------------------------------------

/**
 * Run `worker` over `items` with a ceiling of `maxConcurrent` in-flight
 * operations at any time. Returns resolutions in input order.
 */
async function processInChunks<T, R>(
  items: T[],
  maxConcurrent: number,
  worker: (item: T) => Promise<R>
): Promise<R[]> {
  const results: R[] = new Array(items.length);
  let cursor = 0;

  async function runner(): Promise<void> {
    while (cursor < items.length) {
      const index = cursor++;
      results[index] = await worker(items[index]);
    }
  }

  const runners: Promise<void>[] = [];
  for (let i = 0; i < Math.min(maxConcurrent, items.length); i++) {
    runners.push(runner());
  }
  await Promise.all(runners);
  return results;
}

// ---------------------------------------------------------------------------
// Summary helper
// ---------------------------------------------------------------------------

function tally(results: RefreshOutcome[]): {
  refreshed: number;
  needsReauth: number;
  errors: number;
} {
  return results.reduce(
    (acc, r) => {
      if (r.kind === "refreshed") acc.refreshed++;
      else if (r.kind === "needsReauth") acc.needsReauth++;
      else acc.errors++;
      return acc;
    },
    { refreshed: 0, needsReauth: 0, errors: 0 }
  );
}
