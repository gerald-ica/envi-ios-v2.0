/**
 * kmsEncryption.test.ts — envelope encryption round-trip tests.
 *
 * We stub Cloud KMS with a deterministic XOR "wrap" so the tests are
 * hermetic and fast. The behaviour we care about is that AES-GCM + the
 * envelope shape round-trips cleanly; the KMS integration itself is
 * smoke-tested by the provision script + an integration test in Phase 7.
 */
import * as crypto from "node:crypto";

import {
  __setKmsClientForTests,
  decryptTokenPair,
  encryptTokenPair,
  kmsKeyName,
} from "../lib/kmsEncryption";

function makeFakeKmsClient() {
  // The "KEK" is a 32-byte buffer used to XOR-wrap the DEK. Not real crypto,
  // but gives us an asymmetric encrypt/decrypt pair that matches the shape
  // of the google-cloud/kms client contract.
  const fakeKek = crypto.randomBytes(32);

  const xorBuffers = (a: Buffer, b: Buffer): Buffer => {
    const out = Buffer.alloc(a.length);
    for (let i = 0; i < a.length; i++) {
      out[i] = a[i]! ^ b[i % b.length]!;
    }
    return out;
  };

  return {
    kek: fakeKek,
    encrypt: jest.fn(async ({ plaintext }: { plaintext: Buffer }) => {
      return [{ ciphertext: xorBuffers(plaintext, fakeKek) }] as const;
    }),
    decrypt: jest.fn(async ({ ciphertext }: { ciphertext: Buffer }) => {
      return [{ plaintext: xorBuffers(ciphertext, fakeKek) }] as const;
    }),
  };
}

const TEST_KEY = "projects/p/locations/global/keyRings/kr/cryptoKeys/k";

describe("encryptTokenPair / decryptTokenPair", () => {
  let fakeClient: ReturnType<typeof makeFakeKmsClient>;

  beforeEach(() => {
    fakeClient = makeFakeKmsClient();
    __setKmsClientForTests(fakeClient as never);
  });

  afterEach(() => {
    __setKmsClientForTests(null);
  });

  it("round-trips an access+refresh token pair", async () => {
    const enc = await encryptTokenPair("access-abc-123", "refresh-xyz-789", TEST_KEY);
    expect(enc.accessTokenCiphertext).toMatch(/^[A-Za-z0-9+/=]+$/);
    expect(enc.refreshTokenCiphertext).toMatch(/^[A-Za-z0-9+/=]+$/);
    expect(enc.dekCiphertext).toMatch(/^[A-Za-z0-9+/=]+$/);

    const dec = await decryptTokenPair(enc, TEST_KEY);
    expect(dec.accessToken).toBe("access-abc-123");
    expect(dec.refreshToken).toBe("refresh-xyz-789");
    expect(fakeClient.encrypt).toHaveBeenCalledTimes(1);
    expect(fakeClient.decrypt).toHaveBeenCalledTimes(1);
  });

  it("round-trips when refresh token is null (e.g. X OAuth 1.0a)", async () => {
    const enc = await encryptTokenPair("access-only", null, TEST_KEY);
    expect(enc.refreshTokenCiphertext).toBeNull();
    const dec = await decryptTokenPair(enc, TEST_KEY);
    expect(dec.accessToken).toBe("access-only");
    expect(dec.refreshToken).toBeNull();
  });

  it("produces a unique DEK per encryption (different ciphertexts for identical inputs)", async () => {
    const a = await encryptTokenPair("same-input", null, TEST_KEY);
    const b = await encryptTokenPair("same-input", null, TEST_KEY);
    expect(a.dekCiphertext).not.toBe(b.dekCiphertext);
    expect(a.accessTokenCiphertext).not.toBe(b.accessTokenCiphertext);
  });

  it("detects tampering via AES-GCM auth tag", async () => {
    const enc = await encryptTokenPair("honest-token", null, TEST_KEY);
    const tampered = Buffer.from(enc.accessTokenCiphertext, "base64");
    // Flip one byte in the middle of the ciphertext segment.
    tampered[tampered.length - 20] = tampered[tampered.length - 20]! ^ 0xff;
    const corrupted = {
      ...enc,
      accessTokenCiphertext: tampered.toString("base64"),
    };
    await expect(decryptTokenPair(corrupted, TEST_KEY)).rejects.toThrow();
  });

  it("rejects empty access tokens", async () => {
    await expect(encryptTokenPair("", null, TEST_KEY)).rejects.toThrow();
  });
});

describe("kmsKeyName", () => {
  it("defaults to the envi-oauth-tokens/token-kek resource", () => {
    expect(
      kmsKeyName({ projectId: "envi-by-informal-staging" })
    ).toBe(
      "projects/envi-by-informal-staging/locations/global/keyRings/envi-oauth-tokens/cryptoKeys/token-kek"
    );
  });

  it("honours custom location/keyring/key overrides", () => {
    expect(
      kmsKeyName({
        projectId: "p",
        location: "us-central1",
        keyRing: "custom-ring",
        keyName: "custom-key",
      })
    ).toBe(
      "projects/p/locations/us-central1/keyRings/custom-ring/cryptoKeys/custom-key"
    );
  });
});
