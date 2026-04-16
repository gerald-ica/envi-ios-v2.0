/**
 * rateLimitConfig.ts — per-provider rate-limit envelope used by the
 * nightly insights sync.
 *
 * Units
 * -----
 * Each provider exposes ONE of `maxReqPerDay`, `maxReqPerHour`, or
 * `maxReqPer15min`. `windowMs` matches that cap exactly so the token
 * bucket inside `insightsSyncBase.ts` can decide `max / window`.
 *
 * Why daily vs hourly vs 15-minute
 * --------------------------------
 * - TikTok Display API: 100 calls / app / day for non-commercial tier.
 *   Tight, so we batch all videos in one request (`video.query`).
 * - IG/FB/Threads Graph: 200 calls / app / hour (standard rate class).
 *   Easy headroom; we still track a bucket so bursts don't trip rate
 *   limiting on high-volume staging cohorts.
 * - LinkedIn Marketing Developer Platform: ~100 req / app / day for
 *   `/memberCreatorPostAnalytics`. Hard cap → batch per UID.
 * - X (Basic tier): 15 req / 15 min for `GET /2/users/:id/tweets`.
 *   Hard cap: one batch per user, every 15 min.
 *
 * Backoff strategy
 * ----------------
 * `backoffBaseMs` + 30% jitter, exponential up to `maxRetries`. When the
 * bucket is depleted, remaining UIDs are deferred to Cloud Tasks with a
 * delay of `min(backoffBaseMs << retryCount, 10min) + jitter`.
 */
import type { SupportedProvider } from "../../lib/firestoreSchema";

export interface RateLimitPolicy {
  maxReqPerDay?: number;
  maxReqPerHour?: number;
  maxReqPer15min?: number;
  /** Duration of the counter window in milliseconds. */
  windowMs: number;
  /** Base for `backoffBaseMs * 2^n` exponential delay. */
  backoffBaseMs: number;
  /** Total retry attempts before hard-failing a UID for the day. */
  maxRetries: number;
  /** Human-readable note for ops; never consumed by runtime. */
  note?: string;
}

export const RATE_LIMIT_CONFIG: Record<SupportedProvider, RateLimitPolicy> = {
  tiktok: {
    maxReqPerDay: 100,
    windowMs: 86_400_000,
    backoffBaseMs: 2_000,
    maxRetries: 3,
    note: "Display API non-commercial tier; batch video.query per UID.",
  },
  instagram: {
    maxReqPerHour: 200,
    windowMs: 3_600_000,
    backoffBaseMs: 1_000,
    maxRetries: 5,
  },
  facebook: {
    maxReqPerHour: 200,
    windowMs: 3_600_000,
    backoffBaseMs: 1_000,
    maxRetries: 5,
  },
  threads: {
    maxReqPerHour: 200,
    windowMs: 3_600_000,
    backoffBaseMs: 1_000,
    maxRetries: 5,
  },
  linkedin: {
    maxReqPerDay: 100,
    windowMs: 86_400_000,
    backoffBaseMs: 3_000,
    maxRetries: 3,
    note: "Tight daily cap — always batch per UID, never per-post.",
  },
  x: {
    maxReqPer15min: 15,
    windowMs: 900_000,
    backoffBaseMs: 5_000,
    maxRetries: 2,
    note: "Basic tier; Pro tier required for full impression metrics.",
  },
};

/** Returns the provider's effective per-window cap regardless of unit. */
export function effectiveCap(policy: RateLimitPolicy): number {
  return policy.maxReqPerDay
    ?? policy.maxReqPerHour
    ?? policy.maxReqPer15min
    ?? 0;
}

/**
 * Compute a jittered exponential backoff. Returns milliseconds.
 *
 * Example: base=2000, attempt=2 → [4000, 5200) ms.
 */
export function backoffWithJitter(policy: RateLimitPolicy, attempt: number): number {
  const raw = policy.backoffBaseMs * Math.pow(2, Math.max(0, attempt));
  const jitter = raw * 0.3 * Math.random();
  return Math.min(raw + jitter, 10 * 60_000);  // cap at 10m
}
