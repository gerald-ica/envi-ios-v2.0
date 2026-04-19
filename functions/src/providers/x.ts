/**
 * x.ts — X (Twitter) `ProviderOAuthAdapter` + proxy routes.
 *
 * Phase 9. Implements the Phase 7 `ProviderOAuthAdapter` contract for
 * the provider slug `"x"` AND registers three iOS-facing proxy routes
 * for tweet creation, media upload, and account lookup.
 *
 * OAuth 2.0 PKCE parameters
 * -------------------------
 * - Authorize URL: https://x.com/i/oauth2/authorize
 * - Token URL:     https://api.x.com/2/oauth2/token    (Basic auth)
 * - Revoke URL:    https://api.x.com/2/oauth2/revoke   (Basic auth)
 * - Client ID:     WC12UFNnY05NU3BDNEtKdHdQUDE6MTpjaQ
 * - Client secret: Secret Manager `staging-x-oauth2-client-secret`
 *                  (never leaves the Cloud Function; iOS never sees it)
 * - Scopes:        tweet.read tweet.write users.read media.write offline.access
 *
 * v1.1 retention note
 * -------------------
 * The OAuth 1.0a Consumer Key + Access Token Secret remain provisioned
 * in Secret Manager (`staging-x-oauth1-consumer-secret`,
 * `staging-x-oauth1-access-token-secret`, `staging-x-bearer-token`) but
 * are UNUSED in Phase 9. They're retained dormant for two reasons:
 *   1. Some legacy v1.1 endpoints (Account Activity API webhooks) do
 *      not have v2 equivalents and may become relevant in a later
 *      milestone.
 *   2. Rolling the keys now would require a re-registration step on
 *      X's developer portal with no immediate functional benefit.
 * Security follow-up: if unused 90 days post-Phase-9 ship, remove IAM
 * binding (tracked in STATE.md security notes).
 *
 * Basic tier rate limits (2026 docs)
 * ----------------------------------
 * - POST /2/tweets:             100 / 15min / user,  10k / 24hr / app
 * - POST /2/media/upload (all): 500 / 15min / user,  50k / 24hr / app
 * - GET  /2/users/me:            25 / 15min / user
 *
 * Handling: `withXRateLimit` respects `x-rate-limit-reset` up to a 90s
 * budget, then surfaces `RateLimitError`. Route handlers translate that
 * to the iOS envelope `{ error: "rate_limited", retryAfter: ISO }` with
 * HTTP 429. iOS maps via `XConnectorError.rateLimited(retryAfter:)`.
 */
import { onRequest, type Request } from "firebase-functions/v2/https";
import type { Response } from "express";
import { requireAppCheck } from "../lib/appCheck";
import { getRegion } from "../lib/config";
import { logger } from "../lib/logger";
import { getSecret } from "../lib/secrets";
import { readConnection } from "../lib/tokenStorage";
import { requireFirebaseUid } from "../oauth/auth";
import type {
  BuildAuthUrlParams,
  ExchangeCodeParams,
  ProviderOAuthAdapter,
  ProviderProfile,
  RawTokenSet,
  RefreshParams,
  RevokeParams,
} from "../oauth/adapter";
import { OAuthBrokerError, OAuthBrokerErrorCode } from "../oauth/errors";
import {
  extractProviderParam,
  getFirestore,
  handleBrokerError,
  resolveKmsKeyName,
} from "../oauth/http";
import { register } from "../oauth/registry";
import {
  chooseMediaCategory,
  MediaProcessingError,
  uploadMediaChunked,
} from "./x.media";
import { RateLimitError, withXRateLimit } from "./x.rate-limit";
import type {
  RateLimitedCall,
} from "./x.rate-limit";
import type {
  XAccountResponse,
  XErrorEnvelope,
  XProxyMediaRequest,
  XProxyMediaResponse,
  XProxyTweetRequest,
  XProxyTweetResponse,
  XTokenResponse,
  XTweetCreateRequest,
  XTweetCreateResponse,
  XUserResponse,
} from "./x.types";

const log = logger.withContext({ phase: "09", provider: "x" });

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const X_CLIENT_ID = "WC12UFNnY05NU3BDNEtKdHdQUDE6MTpjaQ";
const X_CLIENT_SECRET_NAME = "staging-x-oauth2-client-secret";

const X_AUTHORIZE_URL = "https://x.com/i/oauth2/authorize";
const X_TOKEN_URL = "https://api.x.com/2/oauth2/token";
const X_REVOKE_URL = "https://api.x.com/2/oauth2/revoke";
const X_USERS_ME_URL =
  "https://api.x.com/2/users/me?user.fields=username,name,public_metrics,profile_image_url";
const X_TWEETS_URL = "https://api.x.com/2/tweets";

const X_DEFAULT_SCOPES = [
  "tweet.read",
  "tweet.write",
  "users.read",
  "media.write",
  "offline.access",
];

// ---------------------------------------------------------------------------
// Secret helpers
// ---------------------------------------------------------------------------

async function getXClientSecret(): Promise<string> {
  return getSecret(X_CLIENT_SECRET_NAME);
}

function basicAuthHeader(clientId: string, clientSecret: string): string {
  const base64 = Buffer.from(`${clientId}:${clientSecret}`, "utf8").toString(
    "base64"
  );
  return `Basic ${base64}`;
}

// ---------------------------------------------------------------------------
// Adapter
// ---------------------------------------------------------------------------

export class XOAuthAdapter implements ProviderOAuthAdapter {
  readonly provider = "x" as const;
  readonly defaultScopes = X_DEFAULT_SCOPES;

  buildAuthUrl(params: BuildAuthUrlParams): string {
    const scopes = (params.scopes ?? this.defaultScopes).join(" ");
    const url = new URL(X_AUTHORIZE_URL);
    url.searchParams.set("response_type", "code");
    url.searchParams.set("client_id", X_CLIENT_ID);
    url.searchParams.set("redirect_uri", params.redirectUri);
    url.searchParams.set("scope", scopes);
    url.searchParams.set("state", params.state);
    url.searchParams.set("code_challenge", params.codeChallenge);
    url.searchParams.set("code_challenge_method", "S256");
    return url.toString();
  }

  async exchangeCode(params: ExchangeCodeParams): Promise<RawTokenSet> {
    const secret = await getXClientSecret();
    const body = new URLSearchParams({
      code: params.code,
      grant_type: "authorization_code",
      client_id: X_CLIENT_ID,
      redirect_uri: params.redirectUri,
      code_verifier: params.codeVerifier,
    });
    return await postToken(body, secret);
  }

  async refresh(params: RefreshParams): Promise<RawTokenSet> {
    const secret = await getXClientSecret();
    const body = new URLSearchParams({
      refresh_token: params.refreshToken,
      grant_type: "refresh_token",
      client_id: X_CLIENT_ID,
    });
    return await postToken(body, secret);
  }

  async revoke(params: RevokeParams): Promise<void> {
    const secret = await getXClientSecret();
    // X's revoke endpoint accepts access OR refresh tokens; we prefer
    // the refresh token (longer-lived, also invalidates derived access
    // tokens server-side).
    const token = params.refreshToken ?? params.accessToken;
    const body = new URLSearchParams({
      token,
      client_id: X_CLIENT_ID,
    });
    const response = await fetch(X_REVOKE_URL, {
      method: "POST",
      headers: {
        Authorization: basicAuthHeader(X_CLIENT_ID, secret),
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body,
    });
    if (!response.ok) {
      // Best-effort — broker logs and moves on; we don't block the
      // disconnect handler on a revoke failure.
      log.warn("x.revoke non-2xx", { status: response.status });
    }
  }

  async fetchUserProfile(accessToken: string): Promise<ProviderProfile> {
    const call: RateLimitedCall<XUserResponse> = async ({ signal }) => {
      const response = await fetch(X_USERS_ME_URL, {
        method: "GET",
        headers: { Authorization: `Bearer ${accessToken}` },
        signal,
      });
      const value = response.ok
        ? ((await response.json()) as XUserResponse)
        : ({ data: { id: "", username: "", name: "" } } as XUserResponse);
      return { response, value };
    };

    const { value } = await withXRateLimit(call, {
      endpointLabel: "users.me",
    });

    const data = value.data;
    return {
      providerUserId: data.id,
      handle: data.username,
      followerCount: data.public_metrics?.followers_count ?? null,
    };
  }
}

async function postToken(
  body: URLSearchParams,
  clientSecret: string
): Promise<RawTokenSet> {
  const call: RateLimitedCall<XTokenResponse> = async ({ signal }) => {
    const response = await fetch(X_TOKEN_URL, {
      method: "POST",
      headers: {
        Authorization: basicAuthHeader(X_CLIENT_ID, clientSecret),
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body,
      signal,
    });
    if (!response.ok) {
      const text = await response.text().catch(() => "");
      log.warn("x.token non-2xx", {
        status: response.status,
        bodyLen: text.length,
      });
      return {
        response,
        value: {
          token_type: "bearer",
          access_token: "",
          expires_in: 0,
          scope: "",
        } as XTokenResponse,
      };
    }
    const value = (await response.json()) as XTokenResponse;
    return { response, value };
  };

  const { value } = await withXRateLimit(call, {
    endpointLabel: "oauth2.token",
  });

  if (!value.access_token) {
    throw new Error("x.postToken: empty access_token");
  }

  return {
    accessToken: value.access_token,
    refreshToken: value.refresh_token ?? null,
    expiresIn: value.expires_in,
    scopes: value.scope.split(/\s+/).filter(Boolean),
  };
}

// ---------------------------------------------------------------------------
// iOS proxy routes
// ---------------------------------------------------------------------------

/**
 * Serialize a `RateLimitError` (or other X-typed error) into the iOS
 * envelope and emit an appropriate HTTP status.
 */
function emitError(res: Response, err: unknown): void {
  if (err instanceof RateLimitError) {
    const envelope: XErrorEnvelope = {
      error: "rate_limited",
      retryAfter: err.retryAfter.toISOString(),
    };
    res.status(429).json(envelope);
    return;
  }
  if (err instanceof MediaProcessingError) {
    const envelope: XErrorEnvelope = {
      error: "media_processing",
      detail: err.reason,
    };
    res.status(502).json(envelope);
    return;
  }
  if (err instanceof OAuthBrokerError) {
    handleBrokerError(res, err);
    return;
  }
  log.error("x proxy unhandled", {
    message: (err as Error).message,
  });
  const envelope: XErrorEnvelope = { error: "internal" };
  res.status(500).json(envelope);
}

async function loadConnectionAccessToken(uid: string): Promise<string> {
  const existing = await readConnection(uid, "x", {
    db: getFirestore(),
    kmsKeyName: resolveKmsKeyName(),
  });
  if (!existing) {
    throw new OAuthBrokerError(
      OAuthBrokerErrorCode.CONNECTION_NOT_FOUND,
      "x connection not found"
    );
  }
  return existing.accessToken;
}

// ---------------------------------------------------------------------------
// POST /connectors/x/tweet
// ---------------------------------------------------------------------------

export async function handleTweet(
  req: Request,
  res: Response
): Promise<void> {
  if (req.method !== "POST") {
    res.status(405).json({ error: "method_not_allowed" });
    return;
  }

  try {
    const uid = await requireFirebaseUid(req);
    const accessToken = await loadConnectionAccessToken(uid);

    const body = req.body as XProxyTweetRequest;
    if (!body?.text || typeof body.text !== "string") {
      throw new OAuthBrokerError(
        OAuthBrokerErrorCode.INTERNAL,
        "tweet.text missing"
      );
    }

    const xBody: XTweetCreateRequest = { text: body.text };
    if (body.mediaID) {
      xBody.media = { media_ids: [body.mediaID] };
    }
    if (body.replyToID) {
      xBody.reply = { in_reply_to_tweet_id: body.replyToID };
    }

    const call: RateLimitedCall<XTweetCreateResponse> = async ({
      signal,
    }) => {
      const response = await fetch(X_TWEETS_URL, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(xBody),
        signal,
      });
      if (!response.ok && response.status !== 429 && response.status < 500) {
        const text = await response.text().catch(() => "");
        log.warn("x.tweets non-retryable", {
          status: response.status,
          bodyLen: text.length,
        });
        const envelope: XErrorEnvelope = {
          error: "tweet_rejected",
          detail: text.slice(0, 500),
        };
        res.status(response.status).json(envelope);
        // Short-circuit the rate-limit wrapper with a synthetic 200 so
        // the loop exits; the response has already been written.
        return {
          response: {
            status: 200,
            headers: response.headers,
          },
          value: { data: { id: "", text: "" } } as XTweetCreateResponse,
        };
      }
      const value = response.ok
        ? ((await response.json()) as XTweetCreateResponse)
        : ({ data: { id: "", text: "" } } as XTweetCreateResponse);
      return { response, value };
    };

    const { value } = await withXRateLimit(call, {
      endpointLabel: "tweets.create",
    });

    if (!value.data.id) {
      // Response already written by the short-circuit branch above.
      return;
    }

    const payload: XProxyTweetResponse = {
      id: value.data.id,
      text: value.data.text,
    };
    res.status(200).json(payload);
  } catch (err) {
    emitError(res, err);
  }
}

// ---------------------------------------------------------------------------
// POST /connectors/x/media
// ---------------------------------------------------------------------------

export async function handleMedia(
  req: Request,
  res: Response
): Promise<void> {
  if (req.method !== "POST") {
    res.status(405).json({ error: "method_not_allowed" });
    return;
  }

  try {
    const uid = await requireFirebaseUid(req);
    const accessToken = await loadConnectionAccessToken(uid);

    const body = req.body as XProxyMediaRequest;
    if (!body?.storagePath || !body.mimeType) {
      throw new OAuthBrokerError(
        OAuthBrokerErrorCode.INTERNAL,
        "media request incomplete"
      );
    }

    // iOS-side validation already ran; this is a defense-in-depth cap.
    if (body.totalBytes > 512 * 1024 * 1024) {
      const envelope: XErrorEnvelope = { error: "media_too_large" };
      res.status(413).json(envelope);
      return;
    }

    const category = chooseMediaCategory(body.mimeType, body.durationSeconds);
    log.info("x.media dispatch", {
      category,
      totalBytes: body.totalBytes,
      durationSeconds: body.durationSeconds,
    });

    const ticket = await uploadMediaChunked({
      accessToken,
      totalBytes: body.totalBytes,
      mimeType: body.mimeType,
      durationSeconds: body.durationSeconds,
      readChunk: makeChunkReader(body.storagePath),
    });

    const payload: XProxyMediaResponse = {
      mediaID: ticket.mediaID,
      mediaKey: ticket.mediaKey,
      expiresAfterSecs: ticket.expiresAfterSecs,
    };
    res.status(200).json(payload);
  } catch (err) {
    emitError(res, err);
  }
}

/**
 * Build a chunk reader for a given storage reference. In production this
 * streams from Cloud Storage; for `file://` paths we read from disk
 * (useful in the emulator). A future iteration will replace this with
 * a streaming Buffer pump once Phase 12's staging pipeline lands.
 *
 * @internal
 */
function makeChunkReader(
  storagePath: string
): (offset: number, length: number) => Promise<Buffer> {
  if (storagePath.startsWith("gs://")) {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const admin = require("firebase-admin") as typeof import("firebase-admin");
    const { bucketName, objectPath } = parseGsUri(storagePath);
    const file = admin.storage().bucket(bucketName).file(objectPath);
    return async (offset, length) => {
      const [buf] = await file.download({
        start: offset,
        end: offset + length - 1,
      });
      return buf;
    };
  }

  // Fallback: local file (emulator path). Kept simple — the production
  // path is always gs://.
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const fs = require("node:fs") as typeof import("node:fs");
  const filePath = storagePath.replace(/^file:\/\//, "");
  return async (offset, length) => {
    const fd = await fs.promises.open(filePath, "r");
    try {
      const buf = Buffer.alloc(length);
      await fd.read(buf, 0, length, offset);
      return buf;
    } finally {
      await fd.close();
    }
  };
}

function parseGsUri(uri: string): { bucketName: string; objectPath: string } {
  const stripped = uri.slice("gs://".length);
  const slash = stripped.indexOf("/");
  if (slash < 0) {
    throw new Error(`invalid gs:// uri: ${uri}`);
  }
  return {
    bucketName: stripped.slice(0, slash),
    objectPath: stripped.slice(slash + 1),
  };
}

// ---------------------------------------------------------------------------
// GET /connectors/x/account
// ---------------------------------------------------------------------------

export async function handleAccount(
  req: Request,
  res: Response
): Promise<void> {
  if (req.method !== "GET") {
    res.status(405).json({ error: "method_not_allowed" });
    return;
  }

  try {
    const uid = await requireFirebaseUid(req);
    const accessToken = await loadConnectionAccessToken(uid);

    const adapter = new XOAuthAdapter();
    const profile = await adapter.fetchUserProfile(accessToken);

    // Re-call the raw users/me to pick up `name` + profile image which
    // aren't part of the `ProviderProfile` flat shape.
    const call: RateLimitedCall<XUserResponse> = async ({ signal }) => {
      const response = await fetch(X_USERS_ME_URL, {
        method: "GET",
        headers: { Authorization: `Bearer ${accessToken}` },
        signal,
      });
      const value = response.ok
        ? ((await response.json()) as XUserResponse)
        : ({ data: { id: "", username: "", name: "" } } as XUserResponse);
      return { response, value };
    };
    const { value } = await withXRateLimit(call, {
      endpointLabel: "users.me.full",
    });

    const payload: XAccountResponse = {
      id: value.data.id || profile.providerUserId,
      username: value.data.username || profile.handle || "",
      name: value.data.name ?? "",
      followerCount: value.data.public_metrics?.followers_count ?? 0,
      profileImageURL: value.data.profile_image_url ?? null,
    };
    res.status(200).json(payload);
  } catch (err) {
    emitError(res, err);
  }
}

// ---------------------------------------------------------------------------
// Dispatcher + export
// ---------------------------------------------------------------------------

/**
 * Path-based dispatcher for `/connectors/x/*`. Firebase Functions v2
 * routes by path prefix, so a single `onRequest` handler multiplexes
 * the three sub-routes based on the trailing segment. We use the
 * same parser helper the OAuth broker uses to stay consistent.
 */
export async function handleConnectorsX(
  req: Request,
  res: Response
): Promise<void> {
  const segments = (req.path || "/")
    .split("/")
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
  // Expected: /connectors/x/<sub>  or  /x/<sub>
  const stripped =
    segments[0]?.toLowerCase() === "connectors" ? segments.slice(2)
    : segments[0]?.toLowerCase() === "x" ? segments.slice(1)
    : segments;
  const sub = (stripped[0] ?? "").toLowerCase();

  switch (sub) {
    case "tweet":
      return handleTweet(req, res);
    case "media":
      return handleMedia(req, res);
    case "account":
      return handleAccount(req, res);
    default:
      res.status(404).json({ error: "not_found" });
      return;
  }
}

// Single exported function — `firebase deploy --only functions:connectorsX`.
export const connectorsX = onRequest(
  { region: getRegion(), cors: false },
  requireAppCheck(handleConnectorsX)
);

// ---------------------------------------------------------------------------
// Register at module load (Phase 7 pattern)
// ---------------------------------------------------------------------------

register(new XOAuthAdapter());

// Re-export for test access.
export { extractProviderParam };
