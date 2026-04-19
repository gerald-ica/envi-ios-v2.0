/**
 * callback.ts — `GET /oauth/:provider/callback`
 *
 * Phase 07-02. No auth header (the provider invokes this). CSRF + user
 * identity are established via the signed state JWT.
 *
 * Flow:
 *   1. Parse `code` + `state` query params.
 *   2. Verify state JWT → claims { uid, provider }.
 *   3. `consumeVerifier(state)` — transactional read-delete of pending doc.
 *   4. Adapter exchanges code for tokens.
 *   5. Adapter fetches user profile.
 *   6. KMS-encrypt + write `users/{uid}/connections/{provider}` via
 *      `tokenStorage.writeConnection`.
 *   7. 302 the browser to `enviapp://oauth-callback/<provider>?status=success`.
 *
 * On any failure, 302 to `enviapp://oauth-callback/<provider>?status=error&code=<X>`
 * so the iOS `ASWebAuthenticationSession` completion handler still fires
 * and the app can surface a user-readable error.
 *
 * App Check is enforced per Phase 06-07. The provider's browser may not
 * carry an App Check token; we accept the header either from the same
 * origin (rare) or from an x-forwarded relay. In practice the callback
 * hits from the user's browser after the provider's 302 — so we run in
 * soft-fail mode here and rely on state JWT for identity binding.
 */
import { onRequest, type Request } from "firebase-functions/v2/https";
import type { Response } from "express";

import { requireAppCheck } from "../lib/appCheck";
import { getRegion } from "../lib/config";
import {
  SUPPORTED_PROVIDERS,
  type SupportedProvider,
} from "../lib/firestoreSchema";
import { logger } from "../lib/logger";
import { writeConnection } from "../lib/tokenStorage";
import { OAuthBrokerError, OAuthBrokerErrorCode, isOAuthBrokerError } from "./errors";
import {
  buildRedirectUri,
  extractProviderParam,
  getFirestore,
  resolveKmsKeyName,
} from "./http";
import { consumeVerifier } from "./pkce";
import { resolve as resolveAdapter } from "./registry";
import { verifyState } from "./state";

const log = logger.withContext({ phase: "07-02" });

/**
 * Build the post-callback redirect URL into the iOS app. Always includes
 * `status=success` | `status=error&code=<X>` so the caller can branch.
 */
function appCallbackUrl(
  provider: string,
  outcome: { status: "success" } | { status: "error"; code: string }
): string {
  const base = buildRedirectUri(provider);
  if (outcome.status === "success") {
    return `${base}?status=success`;
  }
  const code = encodeURIComponent(outcome.code);
  return `${base}?status=error&code=${code}`;
}

function getQueryParam(req: Request, name: string): string | null {
  const raw = req.query[name];
  if (typeof raw === "string" && raw.length > 0) return raw;
  if (Array.isArray(raw) && typeof raw[0] === "string") return raw[0];
  return null;
}

export async function handleCallback(
  req: Request,
  res: Response
): Promise<void> {
  if (req.method !== "GET") {
    res.status(405).json({ error: "method_not_allowed" });
    return;
  }

  let providerSlug = "unknown";
  try {
    providerSlug = extractProviderParam(req);
  } catch (err) {
    // Can't even parse the provider — can't deep-link back. JSON error.
    log.warn("callback: unparseable provider", {
      message: (err as Error).message,
    });
    res.status(400).json({ error: OAuthBrokerErrorCode.PROVIDER_NOT_REGISTERED });
    return;
  }

  const providerError = getQueryParam(req, "error");
  if (providerError) {
    // Provider-side failure (e.g. user denied). Relay intent to app.
    log.info("callback: provider returned error", {
      provider: providerSlug,
      providerError,
    });
    res.redirect(
      302,
      appCallbackUrl(providerSlug, {
        status: "error",
        code: OAuthBrokerErrorCode.CODE_EXCHANGE_FAILED,
      })
    );
    return;
  }

  const code = getQueryParam(req, "code");
  const state = getQueryParam(req, "state");
  if (!code || !state) {
    log.warn("callback: missing code or state", { provider: providerSlug });
    res.redirect(
      302,
      appCallbackUrl(providerSlug, {
        status: "error",
        code: code
          ? OAuthBrokerErrorCode.STATE_INVALID
          : OAuthBrokerErrorCode.CODE_MISSING,
      })
    );
    return;
  }

  try {
    // 1. Verify JWT.
    const claims = await verifyState(state);

    // 2. Provider slug from URL must match the slug from JWT.
    if (claims.provider !== providerSlug) {
      throw new OAuthBrokerError(
        OAuthBrokerErrorCode.STATE_MISMATCH,
        "state claim provider does not match URL"
      );
    }
    if (!SUPPORTED_PROVIDERS.includes(claims.provider)) {
      throw new OAuthBrokerError(
        OAuthBrokerErrorCode.PROVIDER_NOT_REGISTERED,
        `unsupported provider in state: ${claims.provider}`
      );
    }

    const adapter = resolveAdapter(claims.provider);

    // 3. Consume PKCE verifier (transactional — one-shot).
    const pending = await consumeVerifier(state, { db: getFirestore() });

    // Defence-in-depth: pending doc agrees with JWT.
    if (pending.uid !== claims.uid || pending.provider !== claims.provider) {
      throw new OAuthBrokerError(
        OAuthBrokerErrorCode.STATE_MISMATCH,
        "pending doc uid/provider mismatch"
      );
    }

    // 4. Exchange code for tokens.
    let tokens;
    try {
      tokens = await adapter.exchangeCode({
        code,
        codeVerifier: pending.codeVerifier,
        redirectUri: pending.redirectUrl,
      });
    } catch (err) {
      throw new OAuthBrokerError(
        OAuthBrokerErrorCode.CODE_EXCHANGE_FAILED,
        "adapter.exchangeCode rejected",
        { cause: err }
      );
    }

    // 5. Fetch user profile.
    const profile = await adapter.fetchUserProfile(tokens.accessToken);

    // 6. Persist.
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const admin = require("firebase-admin") as typeof import("firebase-admin");
    const Timestamp = admin.firestore.Timestamp;
    const expiresAt = Timestamp.fromMillis(
      Date.now() + tokens.expiresIn * 1000
    );

    await writeConnection(
      {
        uid: pending.uid,
        provider: pending.provider as SupportedProvider,
        providerUserId: profile.providerUserId,
        handle: profile.handle,
        followerCount: profile.followerCount,
        scopes: tokens.scopes.length > 0 ? tokens.scopes : adapter.defaultScopes,
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        expiresAt,
      },
      {
        db: getFirestore(),
        kmsKeyName: resolveKmsKeyName(),
      }
    );

    log.info("oauth connection established", {
      provider: providerSlug,
      uid: claims.uid,
    });

    res.redirect(302, appCallbackUrl(providerSlug, { status: "success" }));
  } catch (err) {
    const code = isOAuthBrokerError(err) ? err.code : OAuthBrokerErrorCode.INTERNAL;
    if (!isOAuthBrokerError(err)) {
      log.error("callback: unhandled failure", {
        provider: providerSlug,
        message: (err as Error).message,
      });
    } else {
      log.warn("callback: broker error", {
        provider: providerSlug,
        code: err.code,
        detail: err.detail,
      });
    }
    res.redirect(
      302,
      appCallbackUrl(providerSlug, { status: "error", code })
    );
  }
}

export const oauthCallback = onRequest(
  { region: getRegion(), cors: false },
  requireAppCheck(handleCallback, { enforceSoftFail: true })
);
