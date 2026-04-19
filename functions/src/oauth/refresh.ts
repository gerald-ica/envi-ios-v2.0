/**
 * refresh.ts — `POST /oauth/:provider/refresh`
 *
 * Phase 07-03. Auth required.
 *
 * Flow:
 *   1. Verify Firebase ID token → uid.
 *   2. Resolve adapter.
 *   3. Read the connection doc (decrypted).
 *   4. ROTATION-REUSE CHECK: hash the refresh token we hold and check
 *      rotationHistory. If present → this refresh was previously rotated
 *      out — treat as stolen. Delete the connection, write a securityEvents
 *      doc, return 401 REFRESH_TOKEN_REUSE.
 *   5. Call `adapter.refresh(...)`.
 *   6. Record the PRIOR refresh token's hash in rotationHistory (30-day TTL).
 *   7. Persist the fresh access + refresh tokens.
 *   8. Return `OAuthStatusResponse`.
 */
import { onRequest, type Request } from "firebase-functions/v2/https";
import type { Response } from "express";

import { requireAppCheck } from "../lib/appCheck";
import { getRegion } from "../lib/config";
import { logger } from "../lib/logger";
import {
  deleteConnection,
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
} from "./http";
import { resolve as resolveAdapter } from "./registry";
import {
  SUPPORTED_PROVIDERS,
  type SupportedProvider,
} from "../lib/firestoreSchema";
import { buildStatusBody, type OAuthStatusBody } from "./status";

const log = logger.withContext({ phase: "07-03" });

async function writeSecurityEvent(
  uid: string,
  provider: SupportedProvider,
  kind: string,
  detail: Record<string, unknown>
): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const admin = require("firebase-admin") as typeof import("firebase-admin");
  const db = getFirestore();
  await db.collection("securityEvents").add({
    uid,
    provider,
    kind,
    detail,
    createdAt: admin.firestore.Timestamp.now(),
  });
}

export async function handleRefresh(
  req: Request,
  res: Response
): Promise<void> {
  if (req.method !== "POST") {
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

    const adapter = resolveAdapter(provider);

    const db = getFirestore();
    const kmsKey = resolveKmsKeyName();

    const existing = await readConnection(uid, provider, {
      db,
      kmsKeyName: kmsKey,
    });
    if (!existing) {
      throw new OAuthBrokerError(
        OAuthBrokerErrorCode.CONNECTION_NOT_FOUND,
        "no connection doc for user+provider"
      );
    }
    if (!existing.refreshToken) {
      throw new OAuthBrokerError(
        OAuthBrokerErrorCode.REFRESH_FAILED,
        "provider does not support refresh (no refresh token stored)"
      );
    }

    // Rotation-reuse detection.
    const reused = await isRefreshTokenReused(
      { uid, provider, refreshToken: existing.refreshToken },
      { db, kmsKeyName: kmsKey }
    );
    if (reused) {
      log.warn("refresh-token reuse detected; revoking connection", {
        uid,
        provider,
      });
      await writeSecurityEvent(uid, provider, "refresh_token_reuse", {
        refreshTokenHash: hashRefreshToken(existing.refreshToken),
      });
      await deleteConnection(uid, provider, { db, kmsKeyName: kmsKey });
      throw new OAuthBrokerError(
        OAuthBrokerErrorCode.REFRESH_TOKEN_REUSE,
        "refresh token already rotated"
      );
    }

    // Call provider.
    let tokens;
    try {
      tokens = await adapter.refresh({ refreshToken: existing.refreshToken });
    } catch (err) {
      throw new OAuthBrokerError(
        OAuthBrokerErrorCode.REFRESH_FAILED,
        "adapter.refresh rejected",
        { cause: err }
      );
    }

    // Record the prior refresh token hash so future presents trip reuse.
    await recordRotatedRefreshToken(
      { uid, provider, priorRefreshToken: existing.refreshToken },
      { db, kmsKeyName: kmsKey }
    );

    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const admin = require("firebase-admin") as typeof import("firebase-admin");
    const Timestamp = admin.firestore.Timestamp;
    const expiresAt = Timestamp.fromMillis(
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
        refreshToken: tokens.refreshToken ?? existing.refreshToken,
        expiresAt,
      },
      { db, kmsKeyName: kmsKey }
    );

    log.info("oauth connection refreshed", { uid, provider });

    const body: OAuthStatusBody = await buildStatusBody({
      uid,
      provider,
      db,
      kmsKeyName: kmsKey,
    });
    res.status(200).json(body);
  } catch (err) {
    handleBrokerError(res, err);
  }
}

export const oauthRefresh = onRequest(
  { region: getRegion(), cors: false },
  requireAppCheck(handleRefresh)
);
