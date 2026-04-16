/**
 * meta.test.ts — Jest assertions for the Meta family provider.
 *
 * Coverage
 * --------
 * 1. Auth URL construction per sub-platform:
 *    - facebook / instagram → facebook.com/dialog/oauth with correct `client_id`
 *    - threads → threads.net/oauth/authorize with its standalone client_id
 * 2. Long-lived token exchange via `fb_exchange_token` / `th_exchange_token`.
 * 3. IG account-type detection normalization (PERSONAL / BUSINESS / UNKNOWN).
 *
 * Strategy
 * --------
 * Fetch is stubbed via `global.fetch`; Secret Manager is stubbed via
 * `__setSecretClientForTests`. No network calls.
 */
import {
  META_APP_IDS,
  META_DEFAULT_SCOPES,
  MetaProvider,
} from "./meta";
import { __setSecretClientForTests } from "../lib/secrets";

// ---------------------------------------------------------------------------
// Fetch stub
// ---------------------------------------------------------------------------

type FetchImpl = (url: string, init?: RequestInit) => Promise<Response>;

function stubFetch(impl: FetchImpl): jest.SpyInstance {
  return jest.spyOn(globalThis, "fetch").mockImplementation(((
    input: string | URL | Request,
    init?: RequestInit
  ) => {
    const url = typeof input === "string" ? input : input.toString();
    return impl(url, init);
  }) as typeof fetch);
}

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

// ---------------------------------------------------------------------------
// Secret stub
// ---------------------------------------------------------------------------

beforeEach(() => {
  process.env.GCLOUD_PROJECT = "envi-tests";
  __setSecretClientForTests({
    accessSecretVersion: async () => [
      { payload: { data: Buffer.from("mock-secret") } },
    ],
  } as never);
});

afterEach(() => {
  jest.restoreAllMocks();
  __setSecretClientForTests(null);
});

// ---------------------------------------------------------------------------
// buildAuthUrl
// ---------------------------------------------------------------------------

describe("MetaProvider.buildAuthUrl", () => {
  const commonParams = {
    state: "state-token",
    codeChallenge: "ignored-meta-doesnt-use-pkce",
    redirectUri: "https://enviapp.example/oauth/facebook/callback",
  };

  it("builds facebook.com/dialog/oauth URL with FB client_id for facebook", () => {
    const adapter = new MetaProvider("facebook");
    const url = new URL(adapter.buildAuthUrl(commonParams));

    expect(url.origin + url.pathname).toBe("https://www.facebook.com/dialog/oauth");
    expect(url.searchParams.get("client_id")).toBe(META_APP_IDS.facebook);
    expect(url.searchParams.get("scope")).toContain("pages_show_list");
    expect(url.searchParams.get("redirect_uri")).toBe(commonParams.redirectUri);
    expect(url.searchParams.get("state")).toBe(commonParams.state);
  });

  it("builds facebook.com/dialog/oauth URL with IG client_id for instagram", () => {
    const adapter = new MetaProvider("instagram");
    const url = new URL(adapter.buildAuthUrl(commonParams));

    expect(url.origin + url.pathname).toBe("https://www.facebook.com/dialog/oauth");
    expect(url.searchParams.get("client_id")).toBe(META_APP_IDS.instagram);
    expect(url.searchParams.get("scope")).toContain("instagram_content_publish");
  });

  it("builds threads.net/oauth/authorize URL with Threads client_id", () => {
    const adapter = new MetaProvider("threads");
    const url = new URL(adapter.buildAuthUrl(commonParams));

    expect(url.origin + url.pathname).toBe("https://threads.net/oauth/authorize");
    expect(url.searchParams.get("client_id")).toBe(META_APP_IDS.threads);
    expect(url.searchParams.get("scope")).toContain("threads_content_publish");
  });

  it("uses caller-supplied scopes when provided", () => {
    const adapter = new MetaProvider("facebook");
    const custom = ["public_profile", "email"];
    const url = new URL(adapter.buildAuthUrl({ ...commonParams, scopes: custom }));
    expect(url.searchParams.get("scope")).toBe(custom.join(","));
  });
});

// ---------------------------------------------------------------------------
// Long-lived token exchange
// ---------------------------------------------------------------------------

describe("MetaProvider.exchangeCode + long-lived exchange", () => {
  it("immediately swaps FB/IG short-lived tokens for long-lived via fb_exchange_token", async () => {
    const calls: string[] = [];
    stubFetch(async (url) => {
      calls.push(url);
      if (calls.length === 1) {
        return jsonResponse(200, { access_token: "short-token", expires_in: 3600 });
      }
      // Long-lived swap
      expect(url).toContain("grant_type=fb_exchange_token");
      expect(url).toContain("fb_exchange_token=short-token");
      return jsonResponse(200, {
        access_token: "long-token",
        expires_in: 60 * 24 * 60 * 60,
      });
    });

    const adapter = new MetaProvider("facebook");
    const tokens = await adapter.exchangeCode({
      code: "auth-code",
      codeVerifier: "ignored",
      redirectUri: "https://enviapp.example/callback",
    });

    expect(tokens.accessToken).toBe("long-token");
    expect(tokens.refreshToken).toBeNull();
    expect(tokens.expiresIn).toBe(60 * 24 * 60 * 60);
    expect(calls).toHaveLength(2);
  });

  it("uses th_exchange_token for threads long-lived swap", async () => {
    const calls: string[] = [];
    stubFetch(async (url) => {
      calls.push(url);
      if (calls.length === 1) {
        return jsonResponse(200, { access_token: "short-th-token", expires_in: 3600 });
      }
      expect(url).toContain("graph.threads.net/oauth/access_token");
      expect(url).toContain("grant_type=th_exchange_token");
      expect(url).toContain("access_token=short-th-token");
      return jsonResponse(200, { access_token: "long-th-token" });
    });

    const adapter = new MetaProvider("threads");
    const tokens = await adapter.exchangeCode({
      code: "auth-code",
      codeVerifier: "ignored",
      redirectUri: "https://enviapp.example/callback",
    });

    expect(tokens.accessToken).toBe("long-th-token");
    // Defaults to 60 days when provider omits expires_in.
    expect(tokens.expiresIn).toBe(60 * 24 * 60 * 60);
  });
});

// ---------------------------------------------------------------------------
// IG account-type detection
// ---------------------------------------------------------------------------

describe("MetaProvider.detectIGAccountType", () => {
  it("returns BUSINESS account type unchanged", async () => {
    stubFetch(async () =>
      jsonResponse(200, {
        id: "ig-user-1",
        account_type: "BUSINESS",
        username: "envi_brand",
        media_count: 42,
      })
    );

    const adapter = new MetaProvider("instagram");
    const result = await adapter.detectIGAccountType("ig-user-1", "page-access-token");

    expect(result.accountType).toBe("BUSINESS");
    expect(result.username).toBe("envi_brand");
    expect(result.mediaCount).toBe(42);
  });

  it("normalizes missing account_type to UNKNOWN", async () => {
    stubFetch(async () =>
      jsonResponse(200, { id: "ig-user-2", username: "no_type" })
    );

    const adapter = new MetaProvider("instagram");
    const result = await adapter.detectIGAccountType("ig-user-2", "page-access-token");

    expect(result.accountType).toBe("UNKNOWN");
    expect(result.username).toBe("no_type");
    expect(result.mediaCount).toBeNull();
  });

  it("rejects when called on a non-IG sub-platform", async () => {
    const fbAdapter = new MetaProvider("facebook");
    await expect(
      fbAdapter.detectIGAccountType("ig-user", "token")
    ).rejects.toThrow(/instagram subPlatform/);
  });
});

// ---------------------------------------------------------------------------
// Default scopes sanity
// ---------------------------------------------------------------------------

describe("Default scope sets", () => {
  it("facebook requests pages_manage_posts (App Review gated)", () => {
    expect(META_DEFAULT_SCOPES.facebook).toContain("pages_manage_posts");
  });

  it("instagram requests instagram_content_publish", () => {
    expect(META_DEFAULT_SCOPES.instagram).toContain("instagram_content_publish");
  });

  it("threads requests threads_content_publish", () => {
    expect(META_DEFAULT_SCOPES.threads).toContain("threads_content_publish");
  });
});
