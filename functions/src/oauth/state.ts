/**
 * state.ts — JWT HS256 signing/verification for the OAuth state parameter.
 *
 * Phase 07.
 *
 * The state JWT is a belt-AND-braces defense:
 *   - Signed: tamper evidence. Provider can't cook up a state that maps
 *     back to a different uid.
 *   - Stored: the PKCE pending doc (keyed by this JWT string) gives us a
 *     second independent check + one-shot consumption.
 *
 * Claims: { uid, provider, nonce, iat, exp }. `exp` mirrors PKCE_TTL so an
 * expired JWT and an expired pending doc trip simultaneously.
 *
 * Key: fetched from Secret Manager (`oauth-state-signing-key`). Cached per
 * container lifetime; rotation is coordinated via the rotation checklist
 * — key rotation requires a dual-overlap window documented separately.
 */
import * as crypto from "node:crypto";
import * as jwt from "jsonwebtoken";

import { getSecret, SecretNotFoundError } from "../lib/secrets";
import { OAuthBrokerError, OAuthBrokerErrorCode } from "./errors";
import type { SupportedProvider } from "../lib/firestoreSchema";
import { PKCE_TTL_SECONDS } from "./pkce";

export const STATE_SIGNING_KEY_SECRET_NAME = "oauth-state-signing-key";

/** JWT claim shape the broker emits + verifies. Stable — don't rename. */
export interface StateClaims {
  uid: string;
  provider: SupportedProvider;
  /** Random per-state nonce (base64url). Defeats JWT replay caching. */
  nonce: string;
  iat: number;
  exp: number;
}

let cachedSigningKey: string | null = null;

/**
 * Test-only reset. Production callers MUST NOT invoke.
 * @internal
 */
export function __resetSigningKeyCacheForTests(value: string | null): void {
  cachedSigningKey = value;
}

/**
 * Fetch the HS256 signing key from Secret Manager, lazily. Throws if the
 * secret is missing — the broker should fail-closed at deploy time rather
 * than issue unsigned state tokens.
 */
async function loadSigningKey(): Promise<string> {
  if (cachedSigningKey !== null) {
    return cachedSigningKey;
  }
  try {
    const value = await getSecret(STATE_SIGNING_KEY_SECRET_NAME);
    if (value.length < 32) {
      throw new OAuthBrokerError(
        OAuthBrokerErrorCode.INTERNAL,
        `${STATE_SIGNING_KEY_SECRET_NAME} is too short; expected >= 32 chars`
      );
    }
    cachedSigningKey = value;
    return value;
  } catch (err) {
    if (err instanceof SecretNotFoundError) {
      throw new OAuthBrokerError(
        OAuthBrokerErrorCode.INTERNAL,
        `secret ${STATE_SIGNING_KEY_SECRET_NAME} not provisioned`,
        { cause: err }
      );
    }
    throw err;
  }
}

function generateNonce(): string {
  return crypto
    .randomBytes(16)
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

export interface SignStateInput {
  uid: string;
  provider: SupportedProvider;
  /** Injectable clock for tests. Seconds since epoch. */
  now?: () => number;
}

/**
 * Produce a signed state JWT. The returned string is both the `state`
 * query-param we send to the provider AND the doc id for the PKCE pending
 * record written by `storeVerifier`.
 */
export async function signState(input: SignStateInput): Promise<string> {
  const key = await loadSigningKey();
  const nowSec = input.now ? input.now() : Math.floor(Date.now() / 1000);
  const claims: StateClaims = {
    uid: input.uid,
    provider: input.provider,
    nonce: generateNonce(),
    iat: nowSec,
    exp: nowSec + PKCE_TTL_SECONDS,
  };
  return jwt.sign(claims, key, { algorithm: "HS256" });
}

/**
 * Verify a state JWT's signature + expiry. Does NOT check the pending
 * Firestore doc — that's `consumeVerifier`'s job.
 *
 * @throws {OAuthBrokerError} STATE_INVALID on signature failure.
 * @throws {OAuthBrokerError} STATE_EXPIRED on expiry.
 */
export async function verifyState(token: string): Promise<StateClaims> {
  const key = await loadSigningKey();
  try {
    const decoded = jwt.verify(token, key, { algorithms: ["HS256"] });
    if (typeof decoded !== "object" || decoded === null) {
      throw new OAuthBrokerError(
        OAuthBrokerErrorCode.STATE_INVALID,
        "decoded state is not an object"
      );
    }
    const claims = decoded as Partial<StateClaims>;
    if (
      typeof claims.uid !== "string" ||
      typeof claims.provider !== "string" ||
      typeof claims.nonce !== "string" ||
      typeof claims.iat !== "number" ||
      typeof claims.exp !== "number"
    ) {
      throw new OAuthBrokerError(
        OAuthBrokerErrorCode.STATE_INVALID,
        "state claims missing required fields"
      );
    }
    return claims as StateClaims;
  } catch (err) {
    if (err instanceof jwt.TokenExpiredError) {
      throw new OAuthBrokerError(
        OAuthBrokerErrorCode.STATE_EXPIRED,
        "state jwt expired",
        { cause: err }
      );
    }
    if (err instanceof jwt.JsonWebTokenError) {
      throw new OAuthBrokerError(
        OAuthBrokerErrorCode.STATE_INVALID,
        "state jwt signature invalid",
        { cause: err }
      );
    }
    throw err;
  }
}
