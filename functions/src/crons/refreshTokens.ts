/**
 * refreshTokens.ts — Phase 12-04 global refresh-token cron.
 *
 * Cloud Scheduler → Pub/Sub → `onSchedule`. Runs daily at 02:00 UTC (quiet
 * window to avoid contention with user-facing publish traffic).
 *
 * Scope
 * -----
 * Collection-group query across `connections` for docs where:
 *   - `isConnected == true`
 *   - `revokedAt == null`
 *   - `expiresAt <= now + 24h`
 *
 * For each candidate we call the Phase 7 per-provider adapter directly
 * (bypassing the HTTP broker) since we're already inside Firebase Admin
 * territory. One provider-specific strategy per row decides how to refresh
 * — see `RefreshStrategy` below.
 *
 * Meta special case
 * -----------------
 * Meta doesn't return a new `expires_in` on refresh. We explicitly set
 * `tokenExpiresAt = now + 60d` after a successful `fb_exchange_token` /
 * `th_exchange_token` grant. `MetaRefreshStrategy` encapsulates that.
 *
 * LinkedIn special case
 * ---------------------
 * LinkedIn tokens do not support refresh at all. When `expiresAt < now + 7d`
 * we write `requiresReauth = true` on the connection doc (read by the iOS
 * `ConnectedAccountsView` to surface RECONNECT). We do NOT call any
 * refresh endpoint for linkedin.
 *
 * Failure handling
 * ----------------
 * - Single failure: `refreshFailureCount += 1`. Retry next day.
 * - 3 consecutive failures: write `revokedAt = now`. iOS flips the badge
 *   to red RECONNECT. User must manually reconnect (unavoidable —
 *   refresh token is stale or revoked upstream).
 * - Emit `oauth_refresh_success` / `oauth_refresh_failure` to
 *   `telemetry_events`.
 */
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";

import { logger } from "../lib/logger";
import { getRegion } from "../lib/config";
import { resolve as resolveAdapter } from "../oauth/registry";
import { resolveKmsKeyName } from "../oauth/http";
import {
  readConnection,
  writeConnection,
} from "../lib/tokenStorage";
import type { SupportedProvider } from "../lib/firestoreSchema";

const log = logger.withContext({ phase: "12-04", cron: "refreshTokens" });

// ---------------------------------------------------------------------------
// Tuning knobs
// ---------------------------------------------------------------------------

const REFRESH_WINDOW_MS = 24 * 60 * 60 * 1000;  // 24h ahead of expiry
const LINKEDIN_REAUTH_WINDOW_MS = 7 * 24 * 60 * 60 * 1000;  // 7d
const MAX_FAILURES_BEFORE_REVOKE = 3;
const META_TOKEN_TTL_SECONDS = 60 * 24 * 60 * 60;  // 60 days

// ---------------------------------------------------------------------------
// Refresh strategy per provider
// ---------------------------------------------------------------------------

/**
 * Returns `null` when the provider was revoked inline (e.g. reuse detected
 * or provider said "needsReauth"), else the newly-persisted expiry.
 */
interface RefreshStrategy {
  run(uid: string, ref: FirebaseFirestore.DocumentReference): Promise<void>;
}

function strategyFor(provider: SupportedProvider): RefreshStrategy {
  switch (provider) {
    case "facebook":
    case "instagram":
    case "threads":
      return new MetaRefreshStrategy(provider);
    case "linkedin":
      return new LinkedInReauthFlagStrategy();
    default:
      return new StandardRefreshStrategy(provider);
  }
}

/** Calls adapter.refresh and writes the returned token set. */
class StandardRefreshStrategy implements RefreshStrategy {
  constructor(private readonly provider: SupportedProvider) {}
  async run(uid: string, _ref: FirebaseFirestore.DocumentReference): Promise<void> {
    const db = admin.firestore();
    const adapter = resolveAdapter(this.provider);
    const conn = await readConnection(uid, this.provider, {
      db, kmsKeyName: resolveKmsKeyName(),
    });
    if (!conn) throw new Error(`${this.provider}: connection missing`);
    if (!conn.refreshToken) {
      throw new Error(`${this.provider}: no refresh_token to rotate`);
    }
    const tokens = await adapter.refresh({
      refreshToken: conn.refreshToken,
    });
    // Persist fresh tokens. `expiresAt` comes from the adapter's
    // `expiresInSeconds`; caller (`writeConnection`) wraps it.
    await writeConnection(
      {
        uid,
        provider: this.provider,
        providerUserId: conn.providerUserId,
        handle: conn.handle,
        followerCount: conn.followerCount,
        scopes: conn.scopes,
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken ?? conn.refreshToken,
        expiresAt: admin.firestore.Timestamp.fromMillis(
          Date.now() + (tokens.expiresIn ?? 3600) * 1000
        ),
      },
      { db, kmsKeyName: resolveKmsKeyName() }
    );
  }
}

/**
 * Meta's `fb_exchange_token` (and the Threads equivalent) is the refresh
 * path. Explicitly stamp a 60-day expiry because Meta doesn't return
 * `expires_in` on the refresh response.
 */
class MetaRefreshStrategy implements RefreshStrategy {
  constructor(private readonly provider: SupportedProvider) {}
  async run(uid: string, _ref: FirebaseFirestore.DocumentReference): Promise<void> {
    const db = admin.firestore();
    const adapter = resolveAdapter(this.provider);
    const conn = await readConnection(uid, this.provider, {
      db, kmsKeyName: resolveKmsKeyName(),
    });
    if (!conn) throw new Error(`${this.provider}: connection missing`);
    const tokens = await adapter.refresh({
      // Meta uses the access token itself as the refresh input.
      refreshToken: conn.accessToken,
    });
    await writeConnection(
      {
        uid,
        provider: this.provider,
        providerUserId: conn.providerUserId,
        handle: conn.handle,
        followerCount: conn.followerCount,
        scopes: conn.scopes,
        accessToken: tokens.accessToken,
        refreshToken: null,
        // Meta doesn't return expires_in — explicit 60d per PLAN.md.
        expiresAt: admin.firestore.Timestamp.fromMillis(
          Date.now() + META_TOKEN_TTL_SECONDS * 1000
        ),
      },
      { db, kmsKeyName: resolveKmsKeyName() }
    );
  }
}

/**
 * LinkedIn has no refresh endpoint. Flag `requiresReauth = true` so iOS can
 * surface the state; no token mutation. Also schedules an FCM push if
 * `users/{uid}.fcmToken` is present.
 */
class LinkedInReauthFlagStrategy implements RefreshStrategy {
  async run(uid: string, ref: FirebaseFirestore.DocumentReference): Promise<void> {
    await ref.update({ requiresReauth: true });
    await sendReauthPush(uid, "LinkedIn");
  }
}

// ---------------------------------------------------------------------------
// Main cron
// ---------------------------------------------------------------------------

export const refreshTokens = onSchedule(
  {
    schedule: "0 2 * * *",
    region: getRegion(),
    timeZone: "Etc/UTC",
  },
  async () => {
    if (admin.apps.length === 0) admin.initializeApp();
    const db = admin.firestore();
    const nowMs = Date.now();
    const cutoff = admin.firestore.Timestamp.fromMillis(nowMs + REFRESH_WINDOW_MS);

    // Collection-group query — one query sweeps all providers at once.
    const snap = await db
      .collectionGroup("connections")
      .where("isConnected", "==", true)
      .where("revokedAt", "==", null)
      .where("expiresAt", "<=", cutoff)
      .get();

    log.info("candidates for refresh", { count: snap.size });

    for (const doc of snap.docs) {
      const data = doc.data();
      const provider = data.provider as SupportedProvider | undefined;
      if (!provider) continue;
      const uid = doc.ref.parent.parent?.id;
      if (!uid) continue;

      // LinkedIn 7-day reauth window is stricter than the 24h default.
      if (provider === "linkedin") {
        const expiresAtMs =
          (data.expiresAt as FirebaseFirestore.Timestamp | undefined)?.toMillis() ?? 0;
        if (expiresAtMs - nowMs > LINKEDIN_REAUTH_WINDOW_MS) {
          continue;
        }
      }

      const strategy = strategyFor(provider);
      try {
        await strategy.run(uid, doc.ref);
        await doc.ref.update({
          refreshFailureCount: 0,
          lastRefreshedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        await writeTelemetry(uid, provider, "oauth_refresh_success");
        log.info("refresh ok", { uid, provider });
      } catch (err) {
        const raw = err instanceof Error ? err.message : String(err);
        log.warn("refresh failed", { uid, provider, raw });
        const failures = ((data.refreshFailureCount as number | undefined) ?? 0) + 1;
        const patch: Record<string, unknown> = {
          refreshFailureCount: failures,
        };
        if (failures >= MAX_FAILURES_BEFORE_REVOKE) {
          patch.revokedAt = admin.firestore.FieldValue.serverTimestamp();
          await sendReauthPush(uid, provider);
        }
        await doc.ref.update(patch);
        await writeTelemetry(uid, provider, "oauth_refresh_failure", raw);
      }
    }
  }
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function writeTelemetry(
  uid: string,
  provider: SupportedProvider,
  name: "oauth_refresh_success" | "oauth_refresh_failure",
  rawError?: string
): Promise<void> {
  try {
    await admin.firestore().collection("telemetry_events").add({
      name,
      uid,
      params: {
        platform: provider,
        ...(rawError ? { error: sanitize(rawError) } : {}),
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (err) {
    log.warn("telemetry write failed", { err: String(err) });
  }
}

function sanitize(raw: string): string {
  const lower = raw.toLowerCase();
  if (lower.includes("rate") || lower.includes("429")) return "rate_limited";
  if (lower.includes("401") || lower.includes("403") || lower.includes("expired")) {
    return "auth_expired";
  }
  if (lower.includes("reuse")) return "refresh_token_reuse";
  return "unknown";
}

async function sendReauthPush(uid: string, provider: string): Promise<void> {
  try {
    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    const fcmToken = (userDoc.data() ?? {}).fcmToken as string | undefined;
    if (!fcmToken) return;
    await admin.messaging().send({
      token: fcmToken,
      notification: {
        title: `Reconnect your ${provider} account`,
        body: "ENVI can't refresh your access token. Tap to reauthorise.",
      },
      data: {
        type: "reauth_required",
        provider,
      },
    });
  } catch (err) {
    // FCM is best-effort — user will still see the in-app RECONNECT pill.
    log.warn("fcm push failed", { uid, provider, err: String(err) });
  }
}
