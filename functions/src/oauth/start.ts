/**
 * start.ts — `POST /oauth/:provider/start`
 *
 * Phase 07-01. Auth required: Firebase ID token.
 *
 * Flow:
 *   1. Verify Firebase ID token → uid.
 *   2. Resolve provider adapter (404 if unregistered).
 *   3. Generate PKCE verifier + S256 challenge.
 *   4. Sign state JWT (uid, provider, nonce).
 *   5. Persist pending doc `oauth_pending/{stateJwt}` with verifier + TTL.
 *   6. Ask adapter to build the provider authorize URL.
 *   7. Return `{ authorizationUrl, stateToken }`.
 *
 * The authorizationUrl is rendered in a system web context on iOS
 * (`ASWebAuthenticationSession`). Provider redirects back to Cloud
 * Functions → `callback.ts` completes the exchange.
 */
import { onRequest, type Request, type Response } from "firebase-functions/v2/https";

import { requireAppCheck } from "../lib/appCheck";
import { getRegion } from "../lib/config";
import { logger } from "../lib/logger";
import { requireFirebaseUid } from "./auth";
import { OAuthBrokerError } from "./errors";
import {
  buildFunctionsCallbackUrl,
  extractProviderParam,
  getFirestore,
  handleBrokerError,
} from "./http";
import { deriveChallenge, generateVerifier, storeVerifier } from "./pkce";
import { resolve as resolveAdapter } from "./registry";
import { signState } from "./state";
import type { SupportedProvider } from "../lib/firestoreSchema";

const log = logger.withContext({ phase: "07-01" });

interface StartResponseBody {
  authorizationUrl: string;
  stateToken: string;
}

/**
 * Functions base URL. The provider redirects to `<this>/oauth/<p>/callback`.
 * Configured via `ENVI_FUNCTIONS_BASE_URL` env var (set in
 * functions/.env.staging / .env.prod). Falls back to the canonical
 * staging default.
 */
function functionsBaseUrl(): string {
  const raw = process.env.ENVI_FUNCTIONS_BASE_URL?.trim();
  if (raw && raw.length > 0) return raw;
  return "https://us-central1-envi-by-informal-staging.cloudfunctions.net";
}

export async function handleStart(req: Request, res: Response): Promise<void> {
  if (req.method !== "POST") {
    res.status(405).json({ error: "method_not_allowed" });
    return;
  }

  try {
    const uid = await requireFirebaseUid(req);
    const provider = extractProviderParam(req);
    const adapter = resolveAdapter(provider);

    // PKCE
    const verifier = generateVerifier();
    const challenge = deriveChallenge(verifier);

    // State JWT — used both as the `state` URL param AND as the Firestore
    // doc id for the pending PKCE record.
    const stateToken = await signState({
      uid,
      provider: adapter.provider as SupportedProvider,
    });

    const redirectUri = buildFunctionsCallbackUrl({
      functionsBaseUrl: functionsBaseUrl(),
      provider: adapter.provider,
    });

    await storeVerifier(
      {
        stateToken,
        uid,
        provider: adapter.provider as SupportedProvider,
        verifier,
        redirectUrl: redirectUri,
      },
      { db: getFirestore() }
    );

    const authorizationUrl = adapter.buildAuthUrl({
      state: stateToken,
      codeChallenge: challenge,
      redirectUri,
    });

    log.info("oauth start issued", { provider: adapter.provider, uid });

    const body: StartResponseBody = { authorizationUrl, stateToken };
    res.status(200).json(body);
  } catch (err) {
    if (!(err instanceof OAuthBrokerError)) {
      log.error("oauth start failed unexpectedly", {
        message: (err as Error).message,
      });
    }
    handleBrokerError(res, err);
  }
}

export const oauthStart = onRequest(
  { region: getRegion(), cors: false },
  requireAppCheck(handleStart)
);
