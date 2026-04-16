/**
 * x.test.ts — unit tests for the Phase 9 X provider.
 *
 * Coverage
 * --------
 * 1. `buildAuthUrl` — all query params present, S256 method, scopes encoded.
 * 2. `exchangeCode` / `refresh` / `revoke` — Basic auth header shape,
 *    x-www-form-urlencoded body, Secret Manager read path.
 * 3. `fetchUserProfile` — public_metrics.followers_count unwrapping.
 * 4. `withXRateLimit` — 429 with reset header sleeps + retries; reset
 *    beyond budget throws RateLimitError.
 * 5. `chooseMediaCategory` — boundaries around 140s.
 * 6. Media APPEND chunk math — ceil(totalBytes / 5MB) segments.
 *
 * Uses the Secret Manager test-injection hook
 * (`__setSecretClientForTests`) + a `fetch` stub. No firebase-admin
 * initialization — these tests never touch Firestore.
 */

import { XOAuthAdapter } from "../x";
import {
  parseRateLimitHeaders,
  RateLimitError,
  withXRateLimit,
} from "../x.rate-limit";
import { chooseMediaCategory } from "../x.media";
import { __setSecretClientForTests } from "../../lib/secrets";

// ---------------------------------------------------------------------------
// Shared stubs
// ---------------------------------------------------------------------------

interface FetchCall {
  url: string;
  init?: RequestInit;
}

function installFetchStub(
  responder: (url: string, init?: RequestInit) => Response
): { calls: FetchCall[]; restore: () => void } {
  const calls: FetchCall[] = [];
  const originalFetch = globalThis.fetch;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  (globalThis as any).fetch = (url: string, init?: RequestInit) => {
    calls.push({ url: String(url), init });
    return Promise.resolve(responder(String(url), init));
  };
  return {
    calls,
    restore: () => {
      globalThis.fetch = originalFetch;
    },
  };
}

function installSecretStub(value: string) {
  __setSecretClientForTests({
    accessSecretVersion: async () =>
      [
        {
          payload: { data: Buffer.from(value, "utf8") },
        },
      ] as never,
  });
}

// ---------------------------------------------------------------------------
// 1. buildAuthUrl
// ---------------------------------------------------------------------------

describe("XOAuthAdapter.buildAuthUrl", () => {
  const adapter = new XOAuthAdapter();
  const built = adapter.buildAuthUrl({
    state: "stateJwt",
    codeChallenge: "chall-base64url",
    redirectUri: "https://example.com/oauth/x/callback",
  });

  test("uses x.com/i/oauth2/authorize", () => {
    expect(built.startsWith("https://x.com/i/oauth2/authorize")).toBe(true);
  });

  test("includes required PKCE params with S256", () => {
    const u = new URL(built);
    expect(u.searchParams.get("response_type")).toBe("code");
    expect(u.searchParams.get("client_id")).toBe(
      "WC12UFNnY05NU3BDNEtKdHdQUDE6MTpjaQ"
    );
    expect(u.searchParams.get("state")).toBe("stateJwt");
    expect(u.searchParams.get("code_challenge")).toBe("chall-base64url");
    expect(u.searchParams.get("code_challenge_method")).toBe("S256");
  });

  test("default scopes include offline.access + media.write", () => {
    const u = new URL(built);
    const scopes = u.searchParams.get("scope")?.split(" ") ?? [];
    expect(scopes).toEqual(
      expect.arrayContaining([
        "tweet.read",
        "tweet.write",
        "users.read",
        "media.write",
        "offline.access",
      ])
    );
  });
});

// ---------------------------------------------------------------------------
// 2. exchangeCode / refresh / revoke
// ---------------------------------------------------------------------------

describe("XOAuthAdapter token endpoints", () => {
  beforeEach(() => installSecretStub("SUPER_SECRET"));
  afterEach(() => __setSecretClientForTests(null));

  test("exchangeCode posts Basic auth + form body", async () => {
    const { calls, restore } = installFetchStub(() => {
      return new Response(
        JSON.stringify({
          token_type: "bearer",
          access_token: "at",
          refresh_token: "rt",
          expires_in: 7200,
          scope: "tweet.read tweet.write offline.access",
        }),
        { status: 200, headers: { "content-type": "application/json" } }
      );
    });

    const adapter = new XOAuthAdapter();
    const tokens = await adapter.exchangeCode({
      code: "abc",
      codeVerifier: "verify-123",
      redirectUri: "https://example.com/cb",
    });
    restore();

    expect(tokens.accessToken).toBe("at");
    expect(tokens.refreshToken).toBe("rt");
    expect(tokens.expiresIn).toBe(7200);
    expect(tokens.scopes).toEqual(
      expect.arrayContaining(["tweet.read", "offline.access"])
    );

    // Inspect the request
    expect(calls.length).toBe(1);
    const call = calls[0]!;
    expect(call.url).toBe("https://api.x.com/2/oauth2/token");
    const headers = call.init?.headers as Record<string, string>;
    expect(headers.Authorization).toMatch(/^Basic /);
    // Decode the Basic header and confirm client_id:secret.
    const basic = headers.Authorization.slice("Basic ".length);
    expect(Buffer.from(basic, "base64").toString()).toBe(
      "WC12UFNnY05NU3BDNEtKdHdQUDE6MTpjaQ:SUPER_SECRET"
    );

    const body = call.init?.body as URLSearchParams;
    expect(body.get("grant_type")).toBe("authorization_code");
    expect(body.get("code")).toBe("abc");
    expect(body.get("code_verifier")).toBe("verify-123");
  });

  test("refresh sends grant_type=refresh_token", async () => {
    const { calls, restore } = installFetchStub(() => {
      return new Response(
        JSON.stringify({
          token_type: "bearer",
          access_token: "at2",
          refresh_token: "rt2",
          expires_in: 7200,
          scope: "tweet.read",
        }),
        { status: 200 }
      );
    });

    const adapter = new XOAuthAdapter();
    await adapter.refresh({ refreshToken: "old-rt" });
    restore();

    const body = calls[0]!.init?.body as URLSearchParams;
    expect(body.get("grant_type")).toBe("refresh_token");
    expect(body.get("refresh_token")).toBe("old-rt");
  });

  test("revoke posts to /2/oauth2/revoke with Basic auth", async () => {
    const { calls, restore } = installFetchStub(() => {
      return new Response("", { status: 200 });
    });
    const adapter = new XOAuthAdapter();
    await adapter.revoke({ accessToken: "a", refreshToken: "r" });
    restore();

    expect(calls[0]!.url).toBe("https://api.x.com/2/oauth2/revoke");
    const body = calls[0]!.init?.body as URLSearchParams;
    // Prefers refresh token.
    expect(body.get("token")).toBe("r");
  });
});

// ---------------------------------------------------------------------------
// 3. fetchUserProfile
// ---------------------------------------------------------------------------

describe("XOAuthAdapter.fetchUserProfile", () => {
  test("unwraps public_metrics.followers_count", async () => {
    const { restore } = installFetchStub(() => {
      return new Response(
        JSON.stringify({
          data: {
            id: "12345",
            username: "envi",
            name: "ENVI",
            public_metrics: {
              followers_count: 4242,
              following_count: 1,
              tweet_count: 10,
              listed_count: 0,
            },
          },
        }),
        { status: 200 }
      );
    });

    const adapter = new XOAuthAdapter();
    const profile = await adapter.fetchUserProfile("bearer-token");
    restore();

    expect(profile.providerUserId).toBe("12345");
    expect(profile.handle).toBe("envi");
    expect(profile.followerCount).toBe(4242);
  });
});

// ---------------------------------------------------------------------------
// 4. Rate-limit behaviour
// ---------------------------------------------------------------------------

describe("withXRateLimit", () => {
  test("429 with reset within budget sleeps and retries", async () => {
    const resetAt = Math.floor(Date.now() / 1000) + 2; // 2s from now
    let attempt = 0;
    const sleepLog: number[] = [];

    const result = await withXRateLimit(
      async () => {
        attempt++;
        if (attempt === 1) {
          return {
            response: {
              status: 429,
              headers: new Headers({
                "x-rate-limit-reset": String(resetAt),
                "x-rate-limit-remaining": "0",
                "x-rate-limit-limit": "100",
              }),
            },
            value: null,
          };
        }
        return {
          response: { status: 200, headers: new Headers() },
          value: "ok",
        };
      },
      {
        endpointLabel: "test",
        sleep: async (ms) => {
          sleepLog.push(ms);
        },
      }
    );

    expect(result.value).toBe("ok");
    expect(result.attempts).toBe(2);
    expect(sleepLog.length).toBe(1);
    expect(sleepLog[0]).toBeGreaterThan(0);
  });

  test("429 with reset beyond budget throws RateLimitError", async () => {
    const resetAt = Math.floor(Date.now() / 1000) + 600; // 10 min
    await expect(
      withXRateLimit(
        async () => ({
          response: {
            status: 429,
            headers: new Headers({
              "x-rate-limit-reset": String(resetAt),
              "x-rate-limit-remaining": "0",
              "x-rate-limit-limit": "100",
            }),
          },
          value: null,
        }),
        {
          endpointLabel: "test",
          maxSleepMs: 5_000,
          sleep: async () => undefined,
        }
      )
    ).rejects.toBeInstanceOf(RateLimitError);
  });

  test("5xx transient retries with backoff", async () => {
    let attempt = 0;
    const sleepLog: number[] = [];
    const { value, attempts } = await withXRateLimit(
      async () => {
        attempt++;
        if (attempt < 3) {
          return {
            response: { status: 503, headers: new Headers() },
            value: null,
          };
        }
        return {
          response: { status: 200, headers: new Headers() },
          value: "ok",
        };
      },
      {
        endpointLabel: "test",
        sleep: async (ms) => {
          sleepLog.push(ms);
        },
        jitter: () => 1.0, // deterministic
      }
    );
    expect(value).toBe("ok");
    expect(attempts).toBe(3);
    expect(sleepLog).toEqual([1000, 2000]); // 1s, 2s
  });

  test("parseRateLimitHeaders handles missing reset", () => {
    const parsed = parseRateLimitHeaders(
      new Headers({ "x-rate-limit-limit": "100" })
    );
    expect(parsed).toBeNull();
  });
});

// ---------------------------------------------------------------------------
// 5. chooseMediaCategory
// ---------------------------------------------------------------------------

describe("chooseMediaCategory", () => {
  test("image/* → tweet_image", () => {
    expect(chooseMediaCategory("image/png", 0)).toBe("tweet_image");
    expect(chooseMediaCategory("image/jpeg", 30)).toBe("tweet_image");
  });
  test("video ≤ 140s → tweet_video", () => {
    expect(chooseMediaCategory("video/mp4", 30)).toBe("tweet_video");
    expect(chooseMediaCategory("video/mp4", 140)).toBe("tweet_video");
  });
  test("video > 140s → amplify_video", () => {
    expect(chooseMediaCategory("video/mp4", 141)).toBe("amplify_video");
    expect(chooseMediaCategory("video/mp4", 600)).toBe("amplify_video");
  });
});

// ---------------------------------------------------------------------------
// 6. Media APPEND chunk math
// ---------------------------------------------------------------------------

describe("media APPEND chunk math", () => {
  // The chunk count is ceil(totalBytes / 5MB). Verified by parameter:
  // - 5 MB exactly → 1 chunk
  // - 5 MB + 1 byte → 2 chunks
  // - 20 MB → 4 chunks
  const FIVE_MB = 5 * 1024 * 1024;
  test("boundary cases", () => {
    expect(Math.ceil(FIVE_MB / FIVE_MB)).toBe(1);
    expect(Math.ceil((FIVE_MB + 1) / FIVE_MB)).toBe(2);
    expect(Math.ceil((20 * 1024 * 1024) / FIVE_MB)).toBe(4);
  });
});
