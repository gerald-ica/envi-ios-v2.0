/**
 * pkce.test.ts — exercise the PKCE helpers + the Firestore-backed pending store.
 *
 * Shape covered:
 *   - generateVerifier length / charset
 *   - deriveChallenge deterministic + correct shape
 *   - storeVerifier + consumeVerifier happy path
 *   - consumeVerifier rejects missing doc → STATE_MISMATCH
 *   - consumeVerifier rejects expired doc → STATE_EXPIRED
 *
 * The Firestore doc is faked with an in-memory stub — we don't bring up the
 * emulator here; integration happens in `oauthBroker.test.ts`.
 */
import {
  consumeVerifier,
  deriveChallenge,
  generateVerifier,
  PKCE_TTL_SECONDS,
  storeVerifier,
} from "../oauth/pkce";
import { OAuthBrokerError, OAuthBrokerErrorCode } from "../oauth/errors";

// Minimal firestore shim. Enough for the code paths we exercise.
function makeFakeDb(): {
  db: import("firebase-admin").firestore.Firestore;
  state: {
    docs: Map<string, Record<string, unknown>>;
    createCalls: number;
    deleteCalls: number;
  };
} {
  const docs = new Map<string, Record<string, unknown>>();
  const state = { docs, createCalls: 0, deleteCalls: 0 };

  const makeDocRef = (id: string) => {
    const ref = {
      id,
      create: jest.fn(async (data: Record<string, unknown>) => {
        state.createCalls += 1;
        if (docs.has(id)) {
          throw new Error("already exists");
        }
        docs.set(id, data);
      }),
      get: jest.fn(async () => {
        const data = docs.get(id);
        return {
          exists: data !== undefined,
          data: () => data,
        };
      }),
      delete: jest.fn(async () => {
        state.deleteCalls += 1;
        docs.delete(id);
      }),
    };
    return ref;
  };

  const db = {
    collection: jest.fn((name: string) => ({
      doc: jest.fn((id: string) => makeDocRef(`${name}/${id}`)),
    })),
    runTransaction: jest.fn(async (fn) => {
      // Our transaction stub: pass `tx` that mirrors the same interface.
      const tx = {
        get: jest.fn(async (ref: ReturnType<typeof makeDocRef>) => {
          return ref.get();
        }),
        delete: jest.fn((ref: ReturnType<typeof makeDocRef>) => {
          return ref.delete();
        }),
      };
      return fn(tx);
    }),
  } as unknown as import("firebase-admin").firestore.Firestore;

  return { db, state };
}

describe("pkce — verifier generation", () => {
  it("generateVerifier returns 64 URL-safe chars each call", () => {
    const a = generateVerifier();
    const b = generateVerifier();
    expect(a).toHaveLength(64);
    expect(b).toHaveLength(64);
    expect(a).not.toEqual(b);
    expect(a).toMatch(/^[A-Za-z0-9_-]+$/);
  });

  it("deriveChallenge is deterministic + URL-safe base64", () => {
    const verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk";
    const challenge = deriveChallenge(verifier);
    expect(challenge).toBe(deriveChallenge(verifier));
    expect(challenge).toMatch(/^[A-Za-z0-9_-]+$/);
    expect(challenge).not.toContain("=");
  });
});

describe("pkce — Firestore store", () => {
  it("storeVerifier + consumeVerifier round-trip on happy path", async () => {
    const { db } = makeFakeDb();
    const now = new Date("2026-04-16T12:00:00Z");

    await storeVerifier(
      {
        stateToken: "state-jwt-1",
        uid: "alice",
        provider: "tiktok",
        verifier: "abc",
        redirectUrl: "https://fn/callback/tiktok",
      },
      { db, now: () => now }
    );

    const pending = await consumeVerifier("state-jwt-1", {
      db,
      now: () => new Date(now.getTime() + 1000),
    });
    expect(pending).toEqual({
      codeVerifier: "abc",
      uid: "alice",
      provider: "tiktok",
      redirectUrl: "https://fn/callback/tiktok",
    });
  });

  it("consumeVerifier throws STATE_MISMATCH when doc is missing", async () => {
    const { db } = makeFakeDb();
    await expect(
      consumeVerifier("never-existed", { db })
    ).rejects.toMatchObject({
      code: OAuthBrokerErrorCode.STATE_MISMATCH,
    });
  });

  it("consumeVerifier throws STATE_EXPIRED when doc is past TTL", async () => {
    const { db } = makeFakeDb();
    const now = new Date("2026-04-16T12:00:00Z");
    await storeVerifier(
      {
        stateToken: "state-jwt-2",
        uid: "bob",
        provider: "x",
        verifier: "v",
        redirectUrl: "https://fn/callback/x",
      },
      { db, now: () => now }
    );
    const later = new Date(now.getTime() + (PKCE_TTL_SECONDS + 10) * 1000);
    await expect(
      consumeVerifier("state-jwt-2", { db, now: () => later })
    ).rejects.toMatchObject({
      code: OAuthBrokerErrorCode.STATE_EXPIRED,
    });
  });

  it("OAuthBrokerError marshals to JSON body", () => {
    const err = new OAuthBrokerError(
      OAuthBrokerErrorCode.STATE_MISMATCH,
      "test detail"
    );
    expect(err.toResponseBody()).toEqual({
      error: "STATE_MISMATCH",
      detail: "test detail",
    });
    expect(err.httpStatus).toBe(400);
  });
});
