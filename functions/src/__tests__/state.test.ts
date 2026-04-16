/**
 * state.test.ts — JWT signing/verification for the OAuth state parameter.
 */
import {
  __resetSigningKeyCacheForTests,
  signState,
  verifyState,
} from "../oauth/state";
import { OAuthBrokerErrorCode } from "../oauth/errors";
import { __setSecretClientForTests } from "../lib/secrets";

function useStubSigningKey(value: string) {
  __resetSigningKeyCacheForTests(value);
  // Also clear secret-manager cache so we don't leak keys between tests.
}

describe("state — sign + verify round-trip", () => {
  const savedEnv = { ...process.env };

  afterEach(() => {
    __resetSigningKeyCacheForTests(null);
    __setSecretClientForTests(null);
    process.env = { ...savedEnv };
  });

  it("signs claims and verifies back to the same uid/provider", async () => {
    useStubSigningKey("a-very-long-testing-signing-key-12345");
    const now = 1_700_000_000;
    const token = await signState({
      uid: "alice",
      provider: "tiktok",
      now: () => now,
    });
    expect(typeof token).toBe("string");
    const claims = await verifyState(token);
    expect(claims.uid).toBe("alice");
    expect(claims.provider).toBe("tiktok");
    expect(claims.iat).toBe(now);
    expect(claims.exp).toBe(now + 600);
    expect(typeof claims.nonce).toBe("string");
  });

  it("verifyState rejects a mangled token with STATE_INVALID", async () => {
    useStubSigningKey("a-very-long-testing-signing-key-12345");
    await expect(verifyState("not.a.jwt")).rejects.toMatchObject({
      code: OAuthBrokerErrorCode.STATE_INVALID,
    });
  });

  it("verifyState rejects an expired token with STATE_EXPIRED", async () => {
    useStubSigningKey("a-very-long-testing-signing-key-12345");
    const token = await signState({
      uid: "alice",
      provider: "x",
      // Use a historical `now` so the generated JWT is already expired.
      now: () => Math.floor(Date.now() / 1000) - 86400,
    });
    await expect(verifyState(token)).rejects.toMatchObject({
      code: OAuthBrokerErrorCode.STATE_EXPIRED,
    });
  });

  it("verifyState rejects a token signed with a different key", async () => {
    useStubSigningKey("original-testing-key-long-enough-123456");
    const token = await signState({
      uid: "a",
      provider: "linkedin",
    });
    // Rotate the cached key to simulate verifying with a mismatched secret.
    useStubSigningKey("different-testing-key-long-enough-xyz-12");
    await expect(verifyState(token)).rejects.toMatchObject({
      code: OAuthBrokerErrorCode.STATE_INVALID,
    });
  });
});
