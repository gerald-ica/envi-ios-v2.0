/**
 * disconnect.ts — `POST /oauth/:provider/disconnect`
 *
 * Phase 07-04. Auth required.
 *
 * Flow:
 *   1. Verify Firebase ID token → uid.
 *   2. Resolve adapter.
 *   3. Read connection doc (decrypted).
 *   4. Best-effort: `adapter.revoke(...)`. Failures are logged but NOT
 *      propagated — the user disconnected on our side, we should
 *      complete the local teardown even if the provider is slow/down.
 *   5. Hard-delete the connection doc + rotation history subcollection.
 *   6. 204 No Content.
 *
 * A missing connection doc returns 204 — idempotent semantics so the
 * client can safely retry a disconnect on a flaky network.
 */
import { onRequest, type Request } from "firebase-functions/v2/https";
import type { Response } from "express";

import { requireAppCheck } from "../lib/appCheck";
import { getRegion } from "../lib/config";
import { logger } from "../lib/logger";
import {
  deleteConnection,
  readConnection,
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

const log = logger.withContext({ phase: "07-04" });

export async function handleDisconnect(
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

    if (existing) {
      try {
        await adapter.revoke({
          accessToken: existing.accessToken,
          refreshToken: existing.refreshToken,
        });
      } catch (err) {
        // Best-effort revocation — do not block local teardown.
        log.warn("adapter.revoke failed; proceeding with local disconnect", {
          uid,
          provider,
          message: (err as Error).message,
        });
      }
    }

    await deleteConnection(uid, provider, { db, kmsKeyName: kmsKey });

    log.info("oauth disconnect complete", { uid, provider });
    res.status(204).send("");
  } catch (err) {
    handleBrokerError(res, err);
  }
}

export const oauthDisconnect = onRequest(
  { region: getRegion(), cors: false },
  requireAppCheck(handleDisconnect)
);
