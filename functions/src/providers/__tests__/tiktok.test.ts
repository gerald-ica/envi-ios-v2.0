/**
 * tiktok.test.ts — unit tests for the Phase 08 TikTok provider adapter +
 * publish helpers + display helpers.
 *
 * Scope: pure function behaviour. Secret Manager + `fetch` are stubbed;
 * Firestore writes in `pollUntilComplete` are exercised against a fake db.
 * No network, no emulator.
 */
import {
  TIKTOK_AUTH_URL,
  TIKTOK_DEFAULT_SCOPES,
  TIKTOK_SANDBOX_CLIENT_KEY,
  TIKTOK_TOKEN_URL,
  tikTokAdapter,
  resolveClientSecretName,
} from "../tiktok";
import { initUpload, pollUntilComplete } from "../tiktok.publish";
import { listVideos } from "../tiktok.display";
import { __setSecretClientForTests } from "../../lib/secrets";

// ---------------------------------------------------------------------------
// Fake Secret Manager client
// ---------------------------------------------------------------------------

beforeAll(() => {
  // Provide a stub Secret Manager that returns a deterministic secret.
  __setSecretClientForTests({
    accessSecretVersion: (async ({ name }: { name: string }) => {
      // `name` looks like `projects/X/secrets/<secretName>/versions/latest`.
      const payload = Buffer.from(`fake-secret-for-${name}`);
      return [{ payload: { data: payload } }];
    }) as any,
  });
  // Secret Manager needs a project id resolvable via env.
  process.env.GCLOUD_PROJECT = "envi-by-informal-staging";
});

afterAll(() => {
  __setSecretClientForTests(null);
});

// ---------------------------------------------------------------------------
// buildAuthUrl
// ---------------------------------------------------------------------------

describe("tiktok adapter: buildAuthUrl", () => {
  it("emits a TikTok auth URL with PKCE S256 + all required params", () => {
    const url = tikTokAdapter.buildAuthUrl({
      state: "state-123",
      codeChallenge: "challenge-abc",
      redirectUri: "https://example.com/cb",
    });

    expect(url.startsWith(TIKTOK_AUTH_URL)).toBe(true);
    const parsed = new URL(url);
    expect(parsed.searchParams.get("client_key")).toBe(
      TIKTOK_SANDBOX_CLIENT_KEY
    );
    expect(parsed.searchParams.get("response_type")).toBe("code");
    expect(parsed.searchParams.get("redirect_uri")).toBe(
      "https://example.com/cb"
    );
    expect(parsed.searchParams.get("state")).toBe("state-123");
    expect(parsed.searchParams.get("code_challenge")).toBe("challenge-abc");
    expect(parsed.searchParams.get("code_challenge_method")).toBe("S256");
    // Scopes comma-separated per TikTok spec.
    const scope = parsed.searchParams.get("scope") ?? "";
    expect(scope.split(",")).toEqual(
      expect.arrayContaining([...TIKTOK_DEFAULT_SCOPES])
    );
  });

  it("honours explicit scope override", () => {
    const url = tikTokAdapter.buildAuthUrl({
      state: "s",
      codeChallenge: "c",
      redirectUri: "https://example.com/cb",
      scopes: ["user.info.basic"],
    });
    const parsed = new URL(url);
    expect(parsed.searchParams.get("scope")).toBe("user.info.basic");
  });
});

// ---------------------------------------------------------------------------
// exchangeCode / refresh — fetch + Secret Manager interplay
// ---------------------------------------------------------------------------

describe("tiktok adapter: exchangeCode", () => {
  const originalFetch = global.fetch;
  afterEach(() => {
    global.fetch = originalFetch;
  });

  it("POSTs to token endpoint with form-encoded body and maps response", async () => {
    const fetchMock = jest.fn(async (url: string | URL, init?: RequestInit) => {
      expect(String(url)).toBe(TIKTOK_TOKEN_URL);
      expect((init?.headers as any)["Content-Type"]).toBe(
        "application/x-www-form-urlencoded"
      );
      const body = String(init?.body);
      // Form params must include client_key, code, grant_type, redirect_uri, code_verifier.
      expect(body).toContain(`client_key=${TIKTOK_SANDBOX_CLIENT_KEY}`);
      expect(body).toContain("code=CODE");
      expect(body).toContain("grant_type=authorization_code");
      expect(body).toContain("code_verifier=VERIFIER");
      return new Response(
        JSON.stringify({
          access_token: "AT",
          refresh_token: "RT",
          scope: "user.info.basic,video.list",
          expires_in: 86400,
          refresh_expires_in: 31536000,
          open_id: "OID",
          token_type: "Bearer",
        }),
        {
          status: 200,
          headers: { "Content-Type": "application/json" },
        }
      );
    });
    global.fetch = fetchMock as any;

    const tokens = await tikTokAdapter.exchangeCode({
      code: "CODE",
      codeVerifier: "VERIFIER",
      redirectUri: "https://example.com/cb",
    });
    expect(tokens.accessToken).toBe("AT");
    expect(tokens.refreshToken).toBe("RT");
    expect(tokens.expiresIn).toBe(86400);
    expect(tokens.scopes).toEqual(
      expect.arrayContaining(["user.info.basic", "video.list"])
    );
    expect(tokens.rawPayload?.open_id).toBe("OID");
  });

  it("throws when TikTok returns an error payload", async () => {
    global.fetch = jest.fn(async () =>
      new Response(
        JSON.stringify({ error: "invalid_grant", error_description: "bad code" }),
        { status: 400 }
      )
    ) as any;

    await expect(
      tikTokAdapter.exchangeCode({
        code: "CODE",
        codeVerifier: "V",
        redirectUri: "https://example.com/cb",
      })
    ).rejects.toThrow(/exchangeCode/);
  });
});

describe("tiktok adapter: refresh", () => {
  const originalFetch = global.fetch;
  afterEach(() => {
    global.fetch = originalFetch;
  });

  it("detects refresh_token rotation", async () => {
    global.fetch = jest.fn(async () =>
      new Response(
        JSON.stringify({
          access_token: "AT2",
          refresh_token: "RT_NEW", // different from input
          scope: "user.info.basic",
          expires_in: 86400,
          open_id: "OID",
          token_type: "Bearer",
        }),
        { status: 200 }
      )
    ) as any;

    const tokens = await tikTokAdapter.refresh({ refreshToken: "RT_OLD" });
    expect(tokens.refreshToken).toBe("RT_NEW");
  });

  it("passes through when refresh_token is unchanged", async () => {
    global.fetch = jest.fn(async () =>
      new Response(
        JSON.stringify({
          access_token: "AT2",
          refresh_token: "RT",
          scope: "user.info.basic",
          expires_in: 86400,
          open_id: "OID",
          token_type: "Bearer",
        }),
        { status: 200 }
      )
    ) as any;

    const tokens = await tikTokAdapter.refresh({ refreshToken: "RT" });
    expect(tokens.refreshToken).toBe("RT");
  });
});

// ---------------------------------------------------------------------------
// resolveClientSecretName — environment switch
// ---------------------------------------------------------------------------

describe("resolveClientSecretName", () => {
  const originalEnv = process.env.ENVI_CONNECTOR_ENV;
  afterEach(() => {
    process.env.ENVI_CONNECTOR_ENV = originalEnv;
  });

  it("defaults to staging", () => {
    delete process.env.ENVI_CONNECTOR_ENV;
    expect(resolveClientSecretName()).toBe(
      "staging-tiktok-sandbox-client-secret"
    );
  });

  it("switches to prod when env says so", () => {
    process.env.ENVI_CONNECTOR_ENV = "prod";
    expect(resolveClientSecretName()).toBe("prod-tiktok-client-secret");
  });
});

// ---------------------------------------------------------------------------
// initUpload
// ---------------------------------------------------------------------------

describe("tiktok.publish.initUpload", () => {
  it("POSTs to inbox init with FILE_UPLOAD source_info and returns mapped result", async () => {
    const fetchMock = jest.fn(async (url: string | URL, init?: RequestInit) => {
      expect(String(url)).toContain("/post/publish/inbox/video/init/");
      const body = JSON.parse(String(init?.body));
      expect(body.source_info.source).toBe("FILE_UPLOAD");
      expect(body.source_info.video_size).toBe(50_000_000);
      expect(body.source_info.chunk_size).toBeGreaterThan(0);
      expect(body.source_info.total_chunk_count).toBeGreaterThanOrEqual(1);
      return new Response(
        JSON.stringify({
          data: {
            publish_id: "pub_123",
            upload_url: "https://upload.example.com/abc",
          },
          error: { code: "ok" },
        }),
        { status: 200 }
      );
    });

    const result = await initUpload(
      "ACCESS_TOKEN",
      50_000_000,
      fetchMock as any
    );
    expect(result.publishID).toBe("pub_123");
    expect(result.uploadURL).toBe("https://upload.example.com/abc");
    expect(result.chunkSize).toBeGreaterThan(0);
  });

  it("throws on HTTP error", async () => {
    const fetchMock = jest.fn(async () =>
      new Response(
        JSON.stringify({ error: { code: "invalid_token", message: "bad" } }),
        { status: 401 }
      )
    );
    await expect(
      initUpload("TOKEN", 10_000_000, fetchMock as any)
    ).rejects.toThrow(/inbox init/);
  });

  it("rejects non-positive video_size", async () => {
    await expect(initUpload("T", 0)).rejects.toThrow(/videoSizeBytes/);
  });
});

// ---------------------------------------------------------------------------
// pollUntilComplete
// ---------------------------------------------------------------------------

describe("tiktok.publish.pollUntilComplete", () => {
  function makeFakeDb() {
    const store = new Map<string, any>();
    const docRef = (path: string): any => ({
      path,
      async set(data: any, opts: any) {
        const prev = opts?.merge ? store.get(path) ?? {} : {};
        store.set(path, { ...prev, ...data });
      },
      collection(name: string) {
        return colRef(`${path}/${name}`);
      },
    });
    const colRef = (path: string): any => ({
      doc: (id: string) => docRef(`${path}/${id}`),
    });
    return {
      db: { collection: (name: string) => colRef(name) } as any,
      store,
    };
  }

  it("writes the terminal state to Firestore when SEND_TO_USER_INBOX", async () => {
    const { db, store } = makeFakeDb();
    let calls = 0;
    const fetchImpl = (async () => {
      calls += 1;
      return new Response(
        JSON.stringify({
          data: { status: "SEND_TO_USER_INBOX" },
          error: { code: "ok" },
        }),
        { status: 200 }
      );
    }) as any;

    const result = await pollUntilComplete({
      uid: "u1",
      userToken: "T",
      publishID: "p1",
      db,
      fetchImpl,
      sleepImpl: async () => {},
      nowImpl: () => 0, // never advance wall clock; terminal bail wins first
    });

    expect(result.terminalState).toBe("SEND_TO_USER_INBOX");
    expect(calls).toBe(1);
    // Firestore doc written at users/u1/connections/tiktok/publishes/p1
    const doc = store.get(
      "users/u1/connections/tiktok/publishes/p1"
    );
    expect(doc?.state).toBe("SEND_TO_USER_INBOX");
    expect(doc?.terminal).toBe(true);
  });

  it("returns FAILED with reason when the wall clock elapses", async () => {
    const { db } = makeFakeDb();
    // Always PROCESSING_UPLOAD — never terminal.
    const fetchImpl = (async () =>
      new Response(
        JSON.stringify({
          data: { status: "PROCESSING_UPLOAD" },
          error: { code: "ok" },
        }),
        { status: 200 }
      )) as any;

    // Advance clock past timeout on the 2nd call.
    let tick = 0;
    const nowImpl = () => {
      tick += 1;
      return tick === 1 ? 0 : 11 * 60 * 1_000;
    };

    const result = await pollUntilComplete({
      uid: "u2",
      userToken: "T",
      publishID: "p2",
      db,
      fetchImpl,
      sleepImpl: async () => {},
      nowImpl,
    });

    expect(result.terminalState).toBe("FAILED");
    expect(result.reason).toMatch(/timeout/);
  });
});

// ---------------------------------------------------------------------------
// listVideos
// ---------------------------------------------------------------------------

describe("tiktok.display.listVideos", () => {
  it("maps TikTok payload to TikTokVideoDTO shape", async () => {
    const fetchImpl = (async (url: string | URL, init?: RequestInit) => {
      expect(String(url)).toContain("/v2/video/list/");
      const body = JSON.parse(String(init?.body));
      expect(body.max_count).toBe(5);
      return new Response(
        JSON.stringify({
          data: {
            videos: [
              {
                id: "v1",
                title: "hello",
                cover_image_url: "https://c.example.com/a.jpg",
                create_time: 1710000000,
                duration: 30,
                view_count: 10,
              },
              { id: "", title: "junk" }, // filtered out (empty id)
            ],
            cursor: 200,
            has_more: true,
          },
          error: { code: "ok" },
        }),
        { status: 200 }
      );
    }) as any;

    const result = await listVideos("TOKEN", null, 5, fetchImpl);
    expect(result.videos).toHaveLength(1);
    expect(result.videos[0].id).toBe("v1");
    expect(result.videos[0].duration).toBe(30);
    expect(result.cursor).toBe(200);
    expect(result.has_more).toBe(true);
  });

  it("clamps max_count to 20", async () => {
    const fetchImpl = (async (_url: any, init?: RequestInit) => {
      const body = JSON.parse(String(init?.body));
      expect(body.max_count).toBe(20);
      return new Response(
        JSON.stringify({ data: { videos: [], has_more: false }, error: { code: "ok" } }),
        { status: 200 }
      );
    }) as any;
    await listVideos("T", null, 9999, fetchImpl);
  });
});
