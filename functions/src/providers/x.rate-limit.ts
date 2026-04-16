/**
 * x.rate-limit.ts — rate-limit–aware retry wrapper for X v2 calls.
 *
 * Phase 9. Wraps every fetch in `x.ts` + `x.media.ts` so the broker's
 * high-level handlers don't have to think about 429 / 5xx at all.
 *
 * Invariants
 * ----------
 * 1. On 429: consult `x-rate-limit-reset`. If the reset is within our
 *    retry budget (default 90s), sleep until `reset + 1s` and retry.
 *    Otherwise throw `RateLimitError` — the HTTP handler translates it
 *    to the iOS-facing `{ error: "rate_limited", retryAfter: ISO }`
 *    envelope.
 * 2. On 5xx transient: exp-backoff (1s → 2s → 4s) with ±30% jitter.
 *    `maxRetries` caps the attempt count (default 3).
 * 3. On 4xx non-429: no retry. The adapter layer re-throws.
 * 4. Successful calls are returned as-is.
 *
 * Budget rationale
 * ----------------
 * Cloud Functions have a 60s / 540s deadline depending on config.
 * Sleeping through a 15-minute `x-rate-limit-reset` inside the
 * function would burn through the whole budget for a single request
 * and block the event loop. Hence the 90s cap — longer resets bubble
 * up as structured errors, and iOS handles the UI retry.
 */
import type { XRateLimitHeaders } from "./x.types";

// ---------------------------------------------------------------------------
// RateLimitError
// ---------------------------------------------------------------------------

/**
 * Thrown by `withXRateLimit` when a 429 response's `x-rate-limit-reset`
 * exceeds the retry budget. The handler in `x.ts` catches this and
 * emits the `{ error: "rate_limited", retryAfter }` envelope.
 */
export class RateLimitError extends Error {
  readonly retryAfter: Date;
  readonly endpoint: string;
  readonly limit: number | null;

  constructor(args: {
    retryAfter: Date;
    endpoint: string;
    limit?: number | null;
  }) {
    super(
      `X rate-limit: retryAfter=${args.retryAfter.toISOString()} endpoint=${args.endpoint}`
    );
    this.name = "RateLimitError";
    this.retryAfter = args.retryAfter;
    this.endpoint = args.endpoint;
    this.limit = args.limit ?? null;
  }
}

// ---------------------------------------------------------------------------
// Header parsing
// ---------------------------------------------------------------------------

/**
 * Parse the three standard X rate-limit response headers. Returns `null`
 * if the minimum `reset` header is absent — callers treat a missing
 * reset as "no usable rate-limit info, fall back to exp-backoff".
 *
 * `x-rate-limit-reset` is a unix timestamp (seconds since epoch).
 */
export function parseRateLimitHeaders(
  headers: Headers | Record<string, string | string[] | undefined>
): XRateLimitHeaders | null {
  const get = (name: string): string | null => {
    if (headers instanceof Headers) {
      return headers.get(name);
    }
    const raw = headers[name] ?? headers[name.toLowerCase()];
    if (raw === undefined) return null;
    return Array.isArray(raw) ? (raw[0] ?? null) : raw;
  };

  const resetRaw = get("x-rate-limit-reset");
  if (!resetRaw) return null;
  const resetSecs = Number.parseInt(resetRaw, 10);
  if (!Number.isFinite(resetSecs)) return null;

  const limit = Number.parseInt(get("x-rate-limit-limit") ?? "0", 10);
  const remaining = Number.parseInt(
    get("x-rate-limit-remaining") ?? "0",
    10
  );

  return {
    limit: Number.isFinite(limit) ? limit : 0,
    remaining: Number.isFinite(remaining) ? remaining : 0,
    reset: new Date(resetSecs * 1000),
  };
}

// ---------------------------------------------------------------------------
// withXRateLimit
// ---------------------------------------------------------------------------

export interface WithRateLimitOptions {
  /** Attempt count; default 3. */
  maxRetries?: number;

  /** Maximum time we'll sleep on a 429 before bubbling up. Default 90s. */
  maxSleepMs?: number;

  /**
   * Label used in thrown `RateLimitError.endpoint`. Keeps telemetry
   * meaningful across the many call-sites that share this wrapper.
   */
  endpointLabel: string;

  /** Test hook — inject deterministic sleeps. Default uses setTimeout. */
  sleep?: (ms: number) => Promise<void>;

  /**
   * Test hook — override the jitter distribution. Default is `Math.random`
   * mapped to `[0.7, 1.3]`. Keeping the API explicit avoids test flake.
   */
  jitter?: () => number;
}

export interface RateLimitedResult<T> {
  /** Parsed value from the final successful call. */
  value: T;

  /** Attempts consumed (1 = first try). */
  attempts: number;
}

/**
 * Function the caller passes to `withXRateLimit`. Receives an
 * `AbortSignal` for future cancellation support (not wired in Phase 9)
 * and returns the raw `Response` PLUS its parsed body. We take the body
 * as an argument (rather than calling `.json()` ourselves) because some
 * X responses are binary (e.g. the APPEND command returns 204 with no
 * body) and we don't want to force every call site through `.json()`.
 */
export type RateLimitedCall<T> = (ctx: {
  signal: AbortSignal;
  attempt: number;
}) => Promise<{
  response: Pick<Response, "status" | "headers">;
  value: T;
}>;

/**
 * Run `fn` with full 429 + 5xx retry behaviour.
 *
 * @throws {RateLimitError} when a 429 reset is outside our sleep budget
 *                          or maxRetries is exhausted on a 429.
 * @throws original fn error when the final attempt rejects with something
 *                          other than a 429 / transient 5xx.
 */
export async function withXRateLimit<T>(
  fn: RateLimitedCall<T>,
  options: WithRateLimitOptions
): Promise<RateLimitedResult<T>> {
  const maxRetries = options.maxRetries ?? 3;
  const maxSleepMs = options.maxSleepMs ?? 90_000;
  const sleep = options.sleep ?? defaultSleep;
  const jitter = options.jitter ?? defaultJitter;
  const controller = new AbortController();

  let lastError: unknown;
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const { response, value } = await fn({
        signal: controller.signal,
        attempt,
      });

      if (response.status === 429) {
        const parsed = parseRateLimitHeaders(response.headers);
        if (!parsed) {
          // Fall through to exp-backoff — no reset header means we have
          // no principled sleep target. Treat as transient.
          lastError = new Error("429 without x-rate-limit-reset");
          if (attempt === maxRetries) {
            // Final attempt — surface a RateLimitError with a
            // best-effort retryAfter of 15 minutes from now, matching
            // the Basic tier window.
            throw new RateLimitError({
              retryAfter: new Date(Date.now() + 15 * 60 * 1000),
              endpoint: options.endpointLabel,
            });
          }
          await sleep(backoffMs(attempt, jitter));
          continue;
        }

        const sleepMs = parsed.reset.getTime() - Date.now() + 1_000;
        if (sleepMs > maxSleepMs || attempt === maxRetries) {
          throw new RateLimitError({
            retryAfter: parsed.reset,
            endpoint: options.endpointLabel,
            limit: parsed.limit,
          });
        }
        await sleep(Math.max(sleepMs, 0));
        continue;
      }

      if (response.status >= 500 && response.status < 600) {
        // Transient 5xx — exp-backoff with jitter.
        lastError = new Error(`X 5xx: status=${response.status}`);
        if (attempt === maxRetries) {
          throw lastError;
        }
        await sleep(backoffMs(attempt, jitter));
        continue;
      }

      // Non-retryable: 2xx returns value; 4xx (non-429) falls through
      // to the adapter-layer error translation.
      return { value, attempts: attempt };
    } catch (err) {
      if (err instanceof RateLimitError) throw err;
      // Network-layer failure (connection reset, DNS, etc.). Treat as
      // transient; exp-backoff up to maxRetries.
      lastError = err;
      if (attempt === maxRetries) {
        throw err;
      }
      await sleep(backoffMs(attempt, jitter));
    }
  }

  // Unreachable: the loop always either returns, throws, or continues.
  throw lastError ?? new Error("withXRateLimit: exhausted without error");
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Exponential-backoff milliseconds for attempt N: 1s, 2s, 4s, 8s, ...
 * multiplied by a jitter factor ∈ [0.7, 1.3].
 */
function backoffMs(attempt: number, jitter: () => number): number {
  const base = 1_000 * Math.pow(2, attempt - 1);
  const factor = jitter();
  return Math.round(base * factor);
}

function defaultSleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function defaultJitter(): number {
  // 0.7 to 1.3 — symmetric ±30%.
  return 0.7 + Math.random() * 0.6;
}
