/**
 * status.ts — `GET /oauth/:provider/status`
 *
 * Phase 07-05. Auth required.
 *
 * Flow:
 *   1. Verify Firebase ID token → uid.
 *   2. Read the connection doc (decrypted).
 *   3. If not present or `revokedAt` is set → `{ isConnected: false }`.
 *   4. If access token expires within 5 minutes, perform an inline silent
 *      refresh (go through the same broker invariants: rotation detect,
 *      persist). Failures during silent refresh are swallowed — the
 *      response still returns `isConnected: true` but with a flag the
 *      client can use to trigger an explicit re-auth soon.
 *   5. Return `OAuthStatusBody`.
 *
 * Response shape matches `OAuthConnectionResponse` on iOS. Don't rename
 * fields without a coordinated change to `SocialOAuthManager`.
 */
import { onRequest, type Request } from "firebase-functions/v2/https";
import type { Response } from "express";
import type { firestore } from "firebase-admin";

import { requireAppCheck } from "../lib/appCheck";
import { getRegion } from "../lib/config";
import { logger } from "../lib/logger";
import {
  hashRefreshToken,
  isRefreshTokenReused,
  readConnection,
  recordRotatedRefreshToken,
  writeConnection,
} from "../lib/tokenStorage";
import { requireFirebaseUid } from "./auth";
import { OAuthBrokerError, OAuthBrokerErrorCode } from "./errors";
import {
  extractProviderParam,
  getFirestore,
  handleBrokerError,
  resolveKmsKeyName,
  timestampToIso,
} from "./http";
import { resolve as resolveAdapter } from "./registry";
import {
  SUPPORTED_PROVIDERS,
  type SupportedProvider,
} from "../lib/firestoreSchema";

const log = logger.withContext({ phase: "07-05" });

/** Threshold for inline silent refresh — 5 minutes. */
const SILENT_REFRESH_WINDOW_MS = 5 * 60 * 1000;

/**
 * Wire shape returned to iOS. Stable — `SocialOAuthManager`'s
 * `OAuthConnectionResponse` decodes this exact shape.
 */
export interface OAuthStatusBody {
  isConnected: boolean;
  handle: string | null;
  followerCount: number | null;
  tokenExpiresAt: string | null;
  lastRefreshedAt: string | null;
  scopes: string[];
  /** Set when silent refresh was attempted and failed; iOS surfaces banner. */
  requiresReauth?: boolean;
}

export interface BuildStatusBodyInput {
  uid: string;
  provider: SupportedProvider;
  db: firestore.Firestore;
  kmsKeyName: string;
}

/** Non-refreshing status read. Reused by refresh.ts after a successful rotation. */
export async function buildStatusBody(
  input: BuildStatusBodyInput
): Promise<OAuthStatusBody> {
  const existing = await readConnection(input.uid, input.provider, {
    db: input.db,
    kmsKeyName: input.kmsKeyName,
  });
  if (!existing || existing.revokedAt) {
    return emptyBody();
  }
  return {
    isConnected: true,
    handle: existing.handle,
    followerCount: existing.followerCount,
    tokenExpiresAt: timestampToIso(existing.expiresAt),
    lastRefreshedAt: timestampToIso(existing.lastRefreshedAt),
    scopes: existing.scopes,
  };
}

function emptyBody(): OAuthStatusBody {
  return {
    isConnected: false,
    handle: null,
    followerCount: null,
    tokenExpiresAt: null,
    lastRefreshedAt: null,
    scopes: [],
  };
}

export async function handleStatus(
  req: Request,
  res: Response
): Promise<void> {
  if (req.method !== "GET") {
    res.status(405).json({ error: "method_not_allowed" });
    return;
  }

  try {
    const uid = await requireFirebaseUid(req);
    const providerSlug = extractProviderParam(req);

    if (!SUPPORTED_PROVIDERS.includes(providerSlug as SupportedProvider)) {
      throw new OAuthBrokerError(
        OAuthBrokerErrorCode.PROVIDER_NOT_REGISTERED,
        providerSlug
      );
    }
    const provider = providerSlug as SupportedProvider;

    const db = getFirestore();
    const kmsKey = resolveKmsKeyName();

    const existing = await readConnection(uid, provider, {
      db,
      kmsKeyName: kmsKey,
    });

    if (!existing || existing.revokedAt) {
      res.status(200).json(emptyBody());
      return;
    }

    const expiresAtMs = existing.expiresAt.toMillis();
    const now = Date.now();
    const shouldSilentRefresh =
      expiresAtMs - now <= SILENT_REFRESH_WINDOW_MS &&
      existing.refreshToken !== null;

    if (!shouldSilentRefresh) {
      const body = await buildStatusBody({
        uid,
        provider,
        db,
        kmsKeyName: kmsKey,
      });
      res.status(200).json(body);
      return;
    }

    // Inline silent refresh — same invariants as refresh.ts but any failure
    // surfaces as `requiresReauth: true` instead of an error status.
    try {
      const adapter = resolveAdapter(provider);
      const priorRefresh = existing.refreshToken as string;

      const reused = await isRefreshTokenReused(
        { uid, provider, refreshToken: priorRefresh },
        { db, kmsKeyName: kmsKey }
      );
      if (reused) {
        log.warn("status: refresh-token reuse detected during silent refresh", {
          uid,
          provider,
        });
        res.status(200).json({ ...emptyBody(), requiresReauth: true });
        return;
      }

      const tokens = await adapter.refresh({ refreshToken: priorRefresh });
      await recordRotatedRefreshToken(
        { uid, provider, priorRefreshToken: priorRefresh },
        { db, kmsKeyName: kmsKey }
      );

      // eslint-disable-next-line @typescript-eslint/no-var-requires
      const admin = require("firebase-admin") as typeof import("firebase-admin");
      const Timestamp = admin.firestore.Timestamp;
      const newExpiresAt = Timestamp.fromMillis(
        Date.now() + tokens.expiresIn * 1000
      );

      await writeConnection(
        {
          uid,
          provider,
          providerUserId: existing.providerUserId,
          handle: existing.handle,
          followerCount: existing.followerCount,
          scopes: tokens.scopes.length > 0 ? tokens.scopes : existing.scopes,
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken ?? priorRefresh,
          expiresAt: newExpiresAt,
        },
        { db, kmsKeyName: kmsKey }
      );

      log.info("status: silent refresh succeeded", { uid, provider });

      const body = await buildStatusBody({
        uid,
        provider,
        db,
        kmsKeyName: kmsKey,
      });
      res.status(200).json(body);
    } catch (err) {
      log.warn("status: silent refresh failed", {
        uid,
        provider,
        message: (err as Error).message,
        // Hash, not plaintext — defensive in case logger schema changes.
        priorRefreshHash: existing.refreshToken
          ? hashRefreshToken(existing.refreshToken)
          : null,
      });
      // Return current status with reauth flag.
      const body = await buildStatusBody({
        uid,
        provider,
        db,
        kmsKeyName: kmsKey,
      });
      res.status(200).json({ ...body, requiresReauth: true });
    }
  } catch (err) {
    handleBrokerError(res, err);
  }
}

export const oauthStatus = onRequest(
  { region: getRegion(), cors: false },
  requireAppCheck(handleStatus)
);
