/**
 * pkce.ts — PKCE helpers + transactional Firestore store for pending OAuth.
 *
 * Phase 07.
 *
 * PKCE (RFC 7636) S256 only:
 *   - verifier:  43–128 chars, URL-safe alphabet [A-Z a-z 0-9 - . _ ~]
 *   - challenge: base64url(SHA-256(verifier))
 *
 * Pending store: `oauth_pending/{stateToken}` holds the PKCE verifier,
 * resolved uid, provider, redirect URL, and TTL. On the callback hop we
 * consume (= read + delete) the document in a single Firestore transaction
 * so a stolen state+code pair can be burned exactly once.
 *
 * TTL: Firestore native TTL on `expiresAt` field cleans up abandoned docs
 * after ~24h (see firestore.indexes.json). Handler-level check rejects docs
 * already past `expiresAt` even if TTL hasn't reaped them yet.
 */
import * as crypto from "node:crypto";
import type { firestore } from "firebase-admin";

import { OAuthBrokerError, OAuthBrokerErrorCode } from "./errors";
import type { SupportedProvider } from "../lib/firestoreSchema";

/** 10-minute PKCE window. Provider auth UI rarely needs longer. */
export const PKCE_TTL_SECONDS = 10 * 60;

/**
 * Generate a 64-char URL-safe PKCE verifier.
 *
 * RFC 7636 allows 43–128 chars; 64 is comfortably in the sweet spot
 * (forces 384 bits of entropy before base64url encoding collisions).
 */
export function generateVerifier(): string {
  // 48 random bytes → 64-char base64url (no padding).
  const buf = crypto.randomBytes(48);
  return base64UrlEncode(buf);
}

/**
 * Derive the S256 PKCE challenge for `verifier`. base64url(SHA-256(verifier)).
 */
export function deriveChallenge(verifier: string): string {
  const digest = crypto.createHash("sha256").update(verifier, "ascii").digest();
  return base64UrlEncode(digest);
}

function base64UrlEncode(buf: Buffer): string {
  return buf
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

// ---------------------------------------------------------------------------
// Firestore persistence
// ---------------------------------------------------------------------------

/**
 * Raw shape of `oauth_pending/{stateToken}`. We persist only what the
 * callback hop needs to complete the code exchange — NOT the access token
 * (that's exchanged later).
 */
export interface PendingOAuthDocument {
  codeVerifier: string;
  uid: string;
  provider: SupportedProvider;
  redirectUrl: string;
  createdAt: firestore.Timestamp;
  /** Absolute expiry. Firestore TTL policy targets this field. */
  expiresAt: firestore.Timestamp;
}

/** Result of `consumeVerifier` — decrypted PKCE context for the callback. */
export interface PendingOAuth {
  codeVerifier: string;
  uid: string;
  provider: SupportedProvider;
  redirectUrl: string;
}

export interface PkceStoreContext {
  db: firestore.Firestore;
  /** Injectable "now" for tests. */
  now?: () => Date;
}

const COLLECTION = "oauth_pending";

/**
 * Persist a PKCE verifier keyed by the caller-supplied stateToken.
 *
 * The broker's `start.ts` generates the state JWT FIRST, then calls this
 * function with the JWT as the doc id. We use the JWT as the key so the
 * callback can both (a) verify the JWT signature and (b) confirm the doc
 * hasn't been consumed yet. Double-safety.
 *
 * @throws {OAuthBrokerError} INTERNAL if the doc already exists.
 */
export async function storeVerifier(
  params: {
    stateToken: string;
    uid: string;
    provider: SupportedProvider;
    verifier: string;
    redirectUrl: string;
  },
  context: PkceStoreContext
): Promise<void> {
  const { stateToken, uid, provider, verifier, redirectUrl } = params;
  const now = context.now?.() ?? new Date();
  const expiresAtDate = new Date(now.getTime() + PKCE_TTL_SECONDS * 1000);

  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const admin = require("firebase-admin") as typeof import("firebase-admin");
  const Timestamp = admin.firestore.Timestamp;

  const ref = context.db.collection(COLLECTION).doc(stateToken);

  // `create()` throws if doc already exists — protects against replay from
  // a buggy caller passing the same stateToken twice.
  await ref.create({
    codeVerifier: verifier,
    uid,
    provider,
    redirectUrl,
    createdAt: Timestamp.fromDate(now),
    expiresAt: Timestamp.fromDate(expiresAtDate),
  } satisfies PendingOAuthDocument);
}

/**
 * Transactionally read + delete the pending PKCE document for `stateToken`.
 *
 * The single-transaction read-delete gives us exactly-once consumption:
 * two concurrent callback attempts for the same state can't both succeed.
 *
 * @throws {OAuthBrokerError} STATE_MISMATCH if the doc is missing.
 * @throws {OAuthBrokerError} STATE_EXPIRED if the doc is past its TTL.
 */
export async function consumeVerifier(
  stateToken: string,
  context: PkceStoreContext
): Promise<PendingOAuth> {
  const ref = context.db.collection(COLLECTION).doc(stateToken);
  const now = context.now?.() ?? new Date();

  return await context.db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      throw new OAuthBrokerError(
        OAuthBrokerErrorCode.STATE_MISMATCH,
        "pending oauth document not found"
      );
    }
    const data = snap.data() as PendingOAuthDocument | undefined;
    if (!data) {
      throw new OAuthBrokerError(
        OAuthBrokerErrorCode.STATE_MISMATCH,
        "pending oauth document empty"
      );
    }

    const expiresAt = data.expiresAt.toDate();
    if (expiresAt.getTime() <= now.getTime()) {
      tx.delete(ref);
      throw new OAuthBrokerError(
        OAuthBrokerErrorCode.STATE_EXPIRED,
        "pending oauth document past expiry"
      );
    }

    tx.delete(ref);

    return {
      codeVerifier: data.codeVerifier,
      uid: data.uid,
      provider: data.provider,
      redirectUrl: data.redirectUrl,
    };
  });
}
