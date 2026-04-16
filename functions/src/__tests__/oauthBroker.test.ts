/**
 * oauthBroker.test.ts — round-trip the broker handlers against a stub adapter
 * + in-memory Firestore/KMS/App Check stubs.
 *
 * No emulator needed. Exercises:
 *   - start → returns { authorizationUrl, stateToken }
 *   - callback → writes connection doc, 302s to custom-scheme URL
 *   - status → returns OAuthStatusBody with decrypted metadata
 *   - disconnect → 204, doc deleted
 */
import type { Request } from "firebase-functions/v2/https";

import { __setAppCheckVerifierForTests } from "../lib/appCheck";
import {
  __setKmsClientForTests,
} from "../lib/kmsEncryption";
import { __setSecretClientForTests } from "../lib/secrets";
import { __setIdTokenVerifierForTests } from "../oauth/auth";
import {
  __resetRegistryForTests,
  register,
} from "../oauth/registry";
import {
  __setFirestoreForTests,
} from "../oauth/http";
import { __resetSigningKeyCacheForTests } from "../oauth/state";
import { handleStart } from "../oauth/start";
import { handleCallback } from "../oauth/callback";
import { handleStatus } from "../oauth/status";
import { handleDisconnect } from "../oauth/disconnect";
import type { ProviderOAuthAdapter } from "../oauth/adapter";

// -- Fake Firestore --------------------------------------------------------

interface FakeDoc {
  data: Record<string, unknown>;
}
function makeFakeFirestore() {
  // Flat key → doc store so we can reason about paths easily.
  const store = new Map<string, FakeDoc>();

  function docRef(path: string) {
    const ref: any = {
      path,
      async get() {
        const doc = store.get(path);
        return { exists: !!doc, data: () => (doc ? doc.data : undefined) };
      },
      async set(data: Record<string, unknown>) {
        store.set(path, { data });
      },
      async create(data: Record<string, unknown>) {
        if (store.has(path)) throw new Error("already exists");
        store.set(path, { data });
      },
      async update(patch: Record<string, unknown>) {
        const existing = store.get(path)?.data ?? {};
        store.set(path, { data: { ...existing, ...patch } });
      },
      async delete() {
        store.delete(path);
      },
      collection(name: string) {
        return colRef(`${path}/${name}`);
      },
    };
    return ref;
  }

  function colRef(path: string): any {
    return {
      path,
      doc(id: string) {
        return docRef(`${path}/${id}`);
      },
      async add(data: Record<string, unknown>) {
        const id = `auto-${store.size}-${Math.random().toString(36).slice(2, 8)}`;
        store.set(`${path}/${id}`, { data });
        return { id };
      },
      limit(n: number) {
        return {
          async get() {
            const docs = Array.from(store.entries())
              .filter(([k]) => k.startsWith(`${path}/`))
              .slice(0, n)
              .map(([k, v]) => ({
                ref: docRef(k),
                data: () => v.data,
                id: k,
              }));
            return { empty: docs.length === 0, size: docs.length, docs };
          },
        };
      },
    };
  }

  const db = {
    collection: (name: string) => colRef(name),
    async runTransaction(fn: any) {
      const tx = {
        async get(ref: any) {
          return ref.get();
        },
        delete(ref: any) {
          return ref.delete();
        },
      };
      return fn(tx);
    },
    batch() {
      const ops: Array<() => Promise<void>> = [];
      return {
        delete(ref: any) {
          ops.push(() => ref.delete());
        },
        async commit() {
          for (const op of ops) await op();
        },
      };
    },
  };

  return { db: db as any, store };
}

// -- Fake KMS --------------------------------------------------------------

function makeFakeKms() {
  return {
    async encrypt(req: { name: string; plaintext: Buffer }) {
      // Reversible "encryption": just base64 with a prefix.
      const wrapped = Buffer.concat([
        Buffer.from("kms:"),
        Buffer.from(req.plaintext),
      ]);
      return [{ ciphertext: wrapped }];
    },
    async decrypt(req: { name: string; ciphertext: Buffer }) {
      const prefix = Buffer.from("kms:");
      const buf = Buffer.from(req.ciphertext);
      if (!buf.subarray(0, prefix.length).equals(prefix)) {
        throw new Error("fake-kms: bad wrap");
      }
      return [{ plaintext: buf.subarray(prefix.length) }];
    },
  };
}

// -- Fake HTTP plumbing -----------------------------------------------------

function makeReq(init: {
  method: string;
  path: string;
  query?: Record<string, string>;
  authHeader?: string;
}): Request {
  const headers: Record<string, string> = {};
  if (init.authHeader) headers["authorization"] = init.authHeader;
  headers["x-firebase-appcheck"] = "stub-app-check";
  return {
    method: init.method,
    path: init.path,
    query: init.query ?? {},
    header: (name: string) => headers[name.toLowerCase()],
  } as unknown as Request;
}

function makeRes() {
  const res: any = {
    statusCode: 0,
    body: null,
    redirectLocation: null as string | null,
    status(code: number) {
      this.statusCode = code;
      return this;
    },
    json(body: unknown) {
      this.body = body;
      return this;
    },
    send() {
      return this;
    },
    redirect(code: number, location: string) {
      this.statusCode = code;
      this.redirectLocation = location;
      return this;
    },
  };
  return res;
}

// -- Stub adapter -----------------------------------------------------------

function makeStubAdapter(): ProviderOAuthAdapter {
  return {
    provider: "tiktok",
    defaultScopes: ["user.info.basic"],
    buildAuthUrl: ({ state, codeChallenge, redirectUri }) =>
      `https://provider.test/authorize?state=${state}&code_challenge=${codeChallenge}&redirect_uri=${encodeURIComponent(redirectUri)}`,
    exchangeCode: async () => ({
      accessToken: "fresh-access",
      refreshToken: "fresh-refresh",
      expiresIn: 3600,
      scopes: ["user.info.basic"],
    }),
    refresh: async () => ({
      accessToken: "rotated-access",
      refreshToken: "rotated-refresh",
      expiresIn: 3600,
      scopes: ["user.info.basic"],
    }),
    revoke: async () => {},
    fetchUserProfile: async () => ({
      providerUserId: "tt-user-1",
      handle: "alice_on_tiktok",
      followerCount: 123,
    }),
  };
}

// -- Tests ------------------------------------------------------------------

describe("oauth broker — round trip", () => {
  let fakeDb: ReturnType<typeof makeFakeFirestore>;

  beforeEach(() => {
    fakeDb = makeFakeFirestore();
    __setFirestoreForTests(fakeDb.db);
    __setIdTokenVerifierForTests(async () => ({ uid: "alice" }));
    __setAppCheckVerifierForTests(async () => ({ appId: "test-app" }));
    __setKmsClientForTests(makeFakeKms() as any);
    __setSecretClientForTests({
      accessSecretVersion: jest.fn(async () => [
        { payload: { data: Buffer.from("oauth-state-key-long-enough-for-test", "utf8") } },
      ]),
    } as any);
    __resetSigningKeyCacheForTests(null);
    __resetRegistryForTests();
    register(makeStubAdapter());

    process.env.GCLOUD_PROJECT = "test-project";
    process.env.ENVI_FUNCTIONS_BASE_URL = "https://fn.test";
  });

  afterEach(() => {
    __setFirestoreForTests(null);
    __setIdTokenVerifierForTests(null);
    __setAppCheckVerifierForTests(null);
    __setKmsClientForTests(null);
    __setSecretClientForTests(null);
    __resetSigningKeyCacheForTests(null);
    __resetRegistryForTests();
    delete process.env.GCLOUD_PROJECT;
    delete process.env.ENVI_FUNCTIONS_BASE_URL;
  });

  it("completes start → callback → status → disconnect happy path", async () => {
    // ---- start ----
    const startReq = makeReq({
      method: "POST",
      path: "/tiktok/start",
      authHeader: "Bearer fake-id-token",
    });
    const startRes = makeRes();
    await handleStart(startReq, startRes);
    expect(startRes.statusCode).toBe(200);
    expect(startRes.body).toEqual(
      expect.objectContaining({
        authorizationUrl: expect.stringContaining("provider.test"),
        stateToken: expect.any(String),
      })
    );
    const stateToken = (startRes.body as { stateToken: string }).stateToken;

    // Pending doc exists.
    const pendingKey = `oauth_pending/${stateToken}`;
    expect(fakeDb.store.has(pendingKey)).toBe(true);

    // ---- callback ----
    const callbackReq = makeReq({
      method: "GET",
      path: "/tiktok/callback",
      query: { code: "provider-auth-code", state: stateToken },
    });
    const callbackRes = makeRes();
    await handleCallback(callbackReq, callbackRes);
    expect(callbackRes.statusCode).toBe(302);
    expect(callbackRes.redirectLocation).toBe(
      "enviapp://oauth-callback/tiktok?status=success"
    );
    // Pending doc consumed.
    expect(fakeDb.store.has(pendingKey)).toBe(false);
    // Connection doc written.
    expect(fakeDb.store.has("users/alice/connections/tiktok")).toBe(true);

    // ---- status ----
    const statusReq = makeReq({
      method: "GET",
      path: "/tiktok/status",
      authHeader: "Bearer fake-id-token",
    });
    const statusRes = makeRes();
    await handleStatus(statusReq, statusRes);
    expect(statusRes.statusCode).toBe(200);
    expect(statusRes.body).toEqual(
      expect.objectContaining({
        isConnected: true,
        handle: "alice_on_tiktok",
        followerCount: 123,
        scopes: ["user.info.basic"],
      })
    );

    // ---- disconnect ----
    const disconnectReq = makeReq({
      method: "POST",
      path: "/tiktok/disconnect",
      authHeader: "Bearer fake-id-token",
    });
    const disconnectRes = makeRes();
    await handleDisconnect(disconnectReq, disconnectRes);
    expect(disconnectRes.statusCode).toBe(204);
    expect(fakeDb.store.has("users/alice/connections/tiktok")).toBe(false);
  });

  it("start rejects when no auth header is present", async () => {
    __setIdTokenVerifierForTests(async () => {
      throw new Error("missing");
    });
    const req = makeReq({
      method: "POST",
      path: "/tiktok/start",
    });
    const res = makeRes();
    await handleStart(req, res);
    expect(res.statusCode).toBe(401);
  });

  it("status returns empty body for users with no connection", async () => {
    const req = makeReq({
      method: "GET",
      path: "/tiktok/status",
      authHeader: "Bearer fake-id-token",
    });
    const res = makeRes();
    await handleStatus(req, res);
    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual(
      expect.objectContaining({
        isConnected: false,
        handle: null,
      })
    );
  });

  it("start → callback with mismatched provider path rejects via STATE_MISMATCH redirect", async () => {
    // Mint a state for tiktok.
    const startReq = makeReq({
      method: "POST",
      path: "/tiktok/start",
      authHeader: "Bearer fake-id-token",
    });
    const startRes = makeRes();
    await handleStart(startReq, startRes);
    const stateToken = (startRes.body as { stateToken: string }).stateToken;

    // Try to consume it on the /x callback — but first register an x adapter
    // so the provider resolves. We still expect a state-mismatch 302.
    register({ ...makeStubAdapter(), provider: "x" });

    const callbackReq = makeReq({
      method: "GET",
      path: "/x/callback",
      query: { code: "c", state: stateToken },
    });
    const callbackRes = makeRes();
    await handleCallback(callbackReq, callbackRes);
    expect(callbackRes.statusCode).toBe(302);
    expect(callbackRes.redirectLocation).toBe(
      "enviapp://oauth-callback/x?status=error&code=STATE_MISMATCH"
    );
  });
});
