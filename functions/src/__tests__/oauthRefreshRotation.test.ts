/**
 * oauthRefreshRotation.test.ts — reuse detection on the refresh endpoint.
 *
 * Scenario:
 *   1. Seed a connection doc with refreshToken="A".
 *   2. Call handleRefresh → provider rotates to "B". Prior hash recorded.
 *   3. Replay the same old refresh token "A": should trip reuse →
 *      connection deleted + 401 REFRESH_TOKEN_REUSE + security event written.
 */
import type { Request } from "firebase-functions/v2/https";

import { __setAppCheckVerifierForTests } from "../lib/appCheck";
import { __setKmsClientForTests } from "../lib/kmsEncryption";
import { __setSecretClientForTests } from "../lib/secrets";
import { __setIdTokenVerifierForTests } from "../oauth/auth";
import {
  __resetRegistryForTests,
  register,
} from "../oauth/registry";
import { __setFirestoreForTests } from "../oauth/http";
import { handleRefresh } from "../oauth/refresh";
import type { ProviderOAuthAdapter } from "../oauth/adapter";
import { writeConnection, hashRefreshToken } from "../lib/tokenStorage";

// Reuse the fakes from oauthBroker.test — copied inline so the tests stay
// independently runnable.

function makeFakeFirestore() {
  const store = new Map<string, { data: Record<string, unknown> }>();

  function docRef(path: string): any {
    return {
      path,
      async get() {
        const doc = store.get(path);
        return { exists: !!doc, data: () => doc?.data };
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
  }

  function colRef(path: string): any {
    return {
      path,
      doc(id: string) {
        return docRef(`${path}/${id}`);
      },
      async add(data: Record<string, unknown>) {
        const id = `auto-${store.size}`;
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
      return fn({ async get(ref: any) { return ref.get(); }, delete(ref: any) { return ref.delete(); } });
    },
    batch() {
      const ops: Array<() => Promise<void>> = [];
      return {
        delete(ref: any) { ops.push(() => ref.delete()); },
        async commit() { for (const op of ops) await op(); },
      };
    },
  } as any;
  return { db, store };
}

function makeFakeKms() {
  return {
    async encrypt(req: { plaintext: Buffer }) {
      return [{ ciphertext: Buffer.concat([Buffer.from("kms:"), Buffer.from(req.plaintext)]) }];
    },
    async decrypt(req: { ciphertext: Buffer }) {
      const b = Buffer.from(req.ciphertext);
      return [{ plaintext: b.subarray(4) }];
    },
  };
}

function makeReq(path: string): Request {
  return {
    method: "POST",
    path,
    query: {},
    header: (name: string) => {
      if (name.toLowerCase() === "authorization") return "Bearer fake";
      if (name.toLowerCase() === "x-firebase-appcheck") return "stub";
      return undefined;
    },
  } as unknown as Request;
}

function makeRes() {
  const res: any = {
    statusCode: 0,
    body: null,
    status(code: number) { this.statusCode = code; return this; },
    json(body: unknown) { this.body = body; return this; },
    send() { return this; },
    redirect() { return this; },
  };
  return res;
}

function makeStubAdapterWithRefresh(
  nextTokens: { accessToken: string; refreshToken: string }
): ProviderOAuthAdapter {
  return {
    provider: "tiktok",
    defaultScopes: ["user.info.basic"],
    buildAuthUrl: () => "https://provider.test",
    exchangeCode: async () => ({
      accessToken: "seed",
      refreshToken: "seed",
      expiresIn: 3600,
      scopes: ["user.info.basic"],
    }),
    refresh: async () => ({
      accessToken: nextTokens.accessToken,
      refreshToken: nextTokens.refreshToken,
      expiresIn: 3600,
      scopes: ["user.info.basic"],
    }),
    revoke: async () => {},
    fetchUserProfile: async () => ({
      providerUserId: "tt-1",
      handle: "alice",
      followerCount: 0,
    }),
  };
}

describe("oauth refresh — rotation reuse detection", () => {
  let fakeDb: ReturnType<typeof makeFakeFirestore>;

  beforeEach(async () => {
    fakeDb = makeFakeFirestore();
    __setFirestoreForTests(fakeDb.db);
    __setIdTokenVerifierForTests(async () => ({ uid: "alice" }));
    __setAppCheckVerifierForTests(async () => ({ appId: "t" }));
    __setKmsClientForTests(makeFakeKms() as any);
    __setSecretClientForTests({
      accessSecretVersion: jest.fn(async () => [
        { payload: { data: Buffer.from("oauth-state-long-enough-test-12345", "utf8") } },
      ]),
    } as any);
    __resetRegistryForTests();
    process.env.GCLOUD_PROJECT = "test-project";
  });

  afterEach(() => {
    __setFirestoreForTests(null);
    __setIdTokenVerifierForTests(null);
    __setAppCheckVerifierForTests(null);
    __setKmsClientForTests(null);
    __setSecretClientForTests(null);
    __resetRegistryForTests();
    delete process.env.GCLOUD_PROJECT;
  });

  async function seedConnection() {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const admin = require("firebase-admin") as typeof import("firebase-admin");
    await writeConnection(
      {
        uid: "alice",
        provider: "tiktok",
        providerUserId: "tt-1",
        handle: "alice",
        followerCount: 0,
        scopes: ["user.info.basic"],
        accessToken: "access-1",
        refreshToken: "refresh-A",
        expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + 3600_000),
      },
      {
        db: fakeDb.db,
        kmsKeyName: "projects/test-project/locations/global/keyRings/envi-oauth-tokens/cryptoKeys/token-kek",
      }
    );
  }

  it("first refresh rotates successfully and records prior hash", async () => {
    register(makeStubAdapterWithRefresh({
      accessToken: "access-2",
      refreshToken: "refresh-B",
    }));
    await seedConnection();

    const res = makeRes();
    await handleRefresh(makeReq("/tiktok/refresh"), res);

    expect(res.statusCode).toBe(200);
    const priorHash = hashRefreshToken("refresh-A");
    expect(
      fakeDb.store.has(
        `users/alice/connections/tiktok/rotationHistory/${priorHash}`
      )
    ).toBe(true);
  });

  it("refresh twice with same token → REFRESH_TOKEN_REUSE + connection deleted", async () => {
    register(makeStubAdapterWithRefresh({
      accessToken: "access-2",
      refreshToken: "refresh-B",
    }));
    await seedConnection();

    // First refresh: legitimate rotation. Writes rotationHistory for
    // "refresh-A" and replaces the connection refresh token with "refresh-B".
    const firstRes = makeRes();
    await handleRefresh(makeReq("/tiktok/refresh"), firstRes);
    expect(firstRes.statusCode).toBe(200);

    // Now simulate an attacker who captured "refresh-A" and replays it:
    // we roll back the connection doc's refresh token to "refresh-A" so the
    // broker treats it as an inbound replay.
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const admin = require("firebase-admin") as typeof import("firebase-admin");
    await writeConnection(
      {
        uid: "alice",
        provider: "tiktok",
        providerUserId: "tt-1",
        handle: "alice",
        followerCount: 0,
        scopes: ["user.info.basic"],
        accessToken: "access-1",
        refreshToken: "refresh-A", // ← replayed (already in rotationHistory)
        expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + 3600_000),
      },
      {
        db: fakeDb.db,
        kmsKeyName: "projects/test-project/locations/global/keyRings/envi-oauth-tokens/cryptoKeys/token-kek",
      }
    );

    const replayRes = makeRes();
    await handleRefresh(makeReq("/tiktok/refresh"), replayRes);
    expect(replayRes.statusCode).toBe(401);
    expect(replayRes.body).toEqual(
      expect.objectContaining({ error: "REFRESH_TOKEN_REUSE" })
    );
    // Connection doc deleted.
    expect(fakeDb.store.has("users/alice/connections/tiktok")).toBe(false);
    // A securityEvents entry was written.
    const securityKeys = Array.from(fakeDb.store.keys()).filter((k) =>
      k.startsWith("securityEvents/")
    );
    expect(securityKeys.length).toBeGreaterThanOrEqual(1);
  });
});
