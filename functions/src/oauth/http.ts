/**
 * http.ts — shared HTTP helpers for OAuth broker handlers.
 *
 * Keeps the per-endpoint handlers focused on business logic:
 *   - `extractProviderParam(req)`   — parse `:provider` from the URL path.
 *   - `handleBrokerError(res, err)` — JSON 4xx/5xx responder.
 *   - `getFirestore()`              — memoized admin firestore handle.
 *   - `buildRedirectUri(provider)`  — canonical `enviapp://oauth-callback/<provider>`.
 *   - `resolveKmsKeyName()`         — fully qualified KMS key path.
 */
import type { Request, Response } from "firebase-functions/v2/https";
import type { firestore } from "firebase-admin";

import {
  OAuthBrokerError,
  OAuthBrokerErrorCode,
  isOAuthBrokerError,
} from "./errors";
import { logger } from "../lib/logger";
import { kmsKeyName } from "../lib/kmsEncryption";
import { getProjectId } from "../lib/config";

const log = logger.withContext({ phase: "07" });

let dbSingleton: firestore.Firestore | null = null;

/**
 * Test-only: inject a firestore instance. Production MUST NOT call.
 * @internal
 */
export function __setFirestoreForTests(db: firestore.Firestore | null): void {
  dbSingleton = db;
}

export function getFirestore(): firestore.Firestore {
  if (dbSingleton) return dbSingleton;
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const admin = require("firebase-admin") as typeof import("firebase-admin");
  if (admin.apps.length === 0) {
    admin.initializeApp();
  }
  dbSingleton = admin.firestore();
  return dbSingleton;
}

/**
 * Extract the `{provider}` segment from the URL. We mount the broker at
 * `/oauth/:provider/*` but Firebase `onRequest` routes are path-based, so
 * we parse by hand.
 *
 * Accepts both the Cloud Functions form (`/oauth/tiktok/start`) and the
 * local emulator form which may strip the leading `/oauth`.
 */
export function extractProviderParam(req: Request): string {
  // req.path example: "/tiktok/start" (local) or "/oauth/tiktok/start"
  // (when the function is deployed behind a path rewrite).
  const segments = (req.path || "/")
    .split("/")
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
  // If first segment is literally "oauth" strip it.
  const stripped =
    segments[0]?.toLowerCase() === "oauth" ? segments.slice(1) : segments;
  const provider = stripped[0];
  if (!provider) {
    throw new OAuthBrokerError(
      OAuthBrokerErrorCode.PROVIDER_NOT_REGISTERED,
      "missing :provider path segment"
    );
  }
  return provider.toLowerCase();
}

/**
 * Canonical iOS callback URL for a given provider. This string is what we
 * register with the provider, what the broker advertises, and what
 * `OAuthCallbackHandler.parse(...)` expects on iOS.
 */
export function buildRedirectUri(provider: string): string {
  return `enviapp://oauth-callback/${provider}`;
}

/**
 * HTTPS callback URL the provider actually hits. The provider redirects
 * to THIS url (hosted by Cloud Functions), which then 302s the browser
 * onto the custom-scheme URI above. Provider consoles register this
 * HTTPS form.
 */
export interface CallbackBaseInput {
  functionsBaseUrl: string;
  provider: string;
}
export function buildFunctionsCallbackUrl(input: CallbackBaseInput): string {
  // Trim trailing slash, append canonical path.
  const base = input.functionsBaseUrl.replace(/\/+$/, "");
  return `${base}/oauth/${input.provider}/callback`;
}

/**
 * Map an error to a JSON response. Safe for all JSON endpoints
 * (start, refresh, disconnect, status). The callback handler uses its
 * own 302-based responder.
 */
export function handleBrokerError(res: Response, err: unknown): void {
  if (isOAuthBrokerError(err)) {
    log.warn("oauth broker error", {
      code: err.code,
      detail: err.detail,
      status: err.httpStatus,
    });
    res.status(err.httpStatus).json(err.toResponseBody());
    return;
  }
  log.error("oauth broker unhandled error", {
    message: (err as Error).message,
  });
  res.status(500).json({
    error: OAuthBrokerErrorCode.INTERNAL,
    detail: null,
  });
}

/**
 * Resolve the canonical KMS key name for this deployment. Reads the GCP
 * project id from the environment (see `config.ts`).
 */
export function resolveKmsKeyName(): string {
  return kmsKeyName({ projectId: getProjectId() });
}

/**
 * Narrow helper. Converts a `Timestamp` to an ISO-8601 string in a
 * null-tolerant way.
 */
export function timestampToIso(
  value: firestore.Timestamp | null | undefined
): string | null {
  if (!value) return null;
  return value.toDate().toISOString();
}
