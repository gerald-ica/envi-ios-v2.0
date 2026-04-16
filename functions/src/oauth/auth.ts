/**
 * auth.ts — Firebase ID token extraction for OAuth broker handlers.
 *
 * Phase 07.
 *
 * Contract:
 *   - Reads `Authorization: Bearer <firebase-id-token>` from the request.
 *   - Verifies via `admin.auth().verifyIdToken(...)`.
 *   - Returns the decoded uid; throws `OAuthBrokerError(UNAUTHENTICATED)`
 *     on any failure.
 *
 * The `start`, `refresh`, `disconnect`, `status` handlers all require a
 * signed-in user; the `callback` handler does NOT (it's invoked by the
 * provider and authenticates the caller via the state JWT instead).
 */
import type { Request } from "firebase-functions/v2/https";

import { OAuthBrokerError, OAuthBrokerErrorCode } from "./errors";

type IdTokenVerifier = (token: string) => Promise<{ uid: string }>;

let verifierSingleton: IdTokenVerifier | null = null;

/**
 * Injectable for tests so we can bypass firebase-admin entirely.
 * @internal
 */
export function __setIdTokenVerifierForTests(
  verifier: IdTokenVerifier | null
): void {
  verifierSingleton = verifier;
}

function defaultVerifier(): IdTokenVerifier {
  // Lazy-require so tests that mock this never pull firebase-admin at import.
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const admin = require("firebase-admin") as typeof import("firebase-admin");
  if (admin.apps.length === 0) {
    admin.initializeApp();
  }
  return async (token: string) => {
    const decoded = await admin.auth().verifyIdToken(token);
    return { uid: decoded.uid };
  };
}

function getVerifier(): IdTokenVerifier {
  if (!verifierSingleton) {
    verifierSingleton = defaultVerifier();
  }
  return verifierSingleton;
}

/**
 * Extract a Firebase ID token from the request's Authorization header.
 * Returns the verified uid.
 *
 * @throws {OAuthBrokerError} UNAUTHENTICATED on missing/invalid token.
 */
export async function requireFirebaseUid(req: Request): Promise<string> {
  const header =
    req.header("Authorization") ??
    req.header("authorization") ??
    "";
  const match = /^Bearer\s+(.+)$/i.exec(header);
  if (!match) {
    throw new OAuthBrokerError(
      OAuthBrokerErrorCode.UNAUTHENTICATED,
      "missing bearer token"
    );
  }
  const token = match[1].trim();
  if (!token) {
    throw new OAuthBrokerError(
      OAuthBrokerErrorCode.UNAUTHENTICATED,
      "empty bearer token"
    );
  }
  try {
    const { uid } = await getVerifier()(token);
    return uid;
  } catch (err) {
    throw new OAuthBrokerError(
      OAuthBrokerErrorCode.UNAUTHENTICATED,
      "firebase id token verification failed",
      { cause: err }
    );
  }
}
