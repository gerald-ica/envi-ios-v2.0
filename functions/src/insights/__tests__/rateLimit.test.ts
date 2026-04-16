/**
 * rateLimit.test.ts — verifies the token-bucket envelope declared in
 * `rateLimitConfig.ts`.
 *
 * These tests do NOT spin up a Firestore emulator — the bucket logic
 * itself lives inside `insightsSyncBase.ts` and is covered by the
 * sync-base integration tests. Here we lock down the per-provider
 * envelope so accidental tuning changes trip a review.
 */
import {
  RATE_LIMIT_CONFIG,
  effectiveCap,
  backoffWithJitter,
} from "../_shared/rateLimitConfig";

describe("rateLimitConfig", () => {
  test("every supported provider has a policy", () => {
    const providers = ["tiktok", "instagram", "facebook", "threads", "linkedin", "x"] as const;
    for (const p of providers) {
      expect(RATE_LIMIT_CONFIG[p]).toBeDefined();
    }
  });

  test("tiktok + linkedin are daily-capped at 100", () => {
    expect(RATE_LIMIT_CONFIG.tiktok.maxReqPerDay).toBe(100);
    expect(RATE_LIMIT_CONFIG.linkedin.maxReqPerDay).toBe(100);
  });

  test("x Basic-tier cap is 15 / 15min", () => {
    expect(RATE_LIMIT_CONFIG.x.maxReqPer15min).toBe(15);
    expect(RATE_LIMIT_CONFIG.x.windowMs).toBe(900_000);
  });

  test("meta family caps are 200 / hour", () => {
    expect(RATE_LIMIT_CONFIG.instagram.maxReqPerHour).toBe(200);
    expect(RATE_LIMIT_CONFIG.facebook.maxReqPerHour).toBe(200);
    expect(RATE_LIMIT_CONFIG.threads.maxReqPerHour).toBe(200);
  });

  test("effectiveCap returns the single declared cap", () => {
    expect(effectiveCap(RATE_LIMIT_CONFIG.tiktok)).toBe(100);
    expect(effectiveCap(RATE_LIMIT_CONFIG.instagram)).toBe(200);
    expect(effectiveCap(RATE_LIMIT_CONFIG.x)).toBe(15);
  });

  test("backoffWithJitter respects the 10-minute ceiling", () => {
    const policy = RATE_LIMIT_CONFIG.tiktok;
    const big = backoffWithJitter(policy, 20);
    expect(big).toBeLessThanOrEqual(10 * 60_000);
  });

  test("backoffWithJitter produces monotonically-growing bases", () => {
    const policy = RATE_LIMIT_CONFIG.instagram;
    const d1 = Math.floor(backoffWithJitter(policy, 0) / 1000);
    const d5 = Math.floor(backoffWithJitter(policy, 5) / 1000);
    expect(d5).toBeGreaterThan(d1);
  });
});
