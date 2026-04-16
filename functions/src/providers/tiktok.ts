/**
 * tiktok.ts — `ProviderOAuthAdapter` implementation for TikTok Login Kit v2.
 *
 * Phase 08 — first REAL provider adapter under the Phase 7 broker.
 *
 * References
 * ----------
 *   Auth:    https://www.tiktok.com/v2/auth/authorize/
 *   Token:   POST https://open.tiktokapis.com/v2/oauth/token/
 *   Revoke:  POST https://open.tiktokapis.com/v2/oauth/revoke/
 *   User:    GET  https://open.tiktokapis.com/v2/user/info/?fields=...
 *
 * Key invariants
 * --------------
 * - Client key (`CLIENT_KEY`) is public and hardcoded. Client secret lives
 *   in Secret Manager under `staging-tiktok-sandbox-client-secret`; never
 *   logged, never returned to the client.
 * - PKCE S256 is mandated by TikTok — `buildAuthUrl` requires a
 *   `codeChallenge` and passes `code_challenge_method=S256`.
 * - Token endpoint is `application/x-www-form-urlencoded`. JSON bodies
 *   silently 400 with `invalid_request`.
 * - TikTok's refresh endpoint MAY return a new `refresh_token`. We detect
 *   rotation by comparing against the input and log a warning so the
 *   caller knows to overwrite storage.
 * - Access token TTL: 86400s. Refresh TTL: 31536000s (1 year).
 * - Provider user id is TikTok's `open_id`, echoed both in the token
 *   response and `/v2/user/info/`.
 *
 * Error surface
 * -------------
 * Any non-2xx from TikTok throws a plain `Error` with the message
 *   `tiktok: <endpoint> responded HTTP <status>: <body snippet>`
 * The broker layer wraps this in `OAuthBrokerError(CODE_EXCHANGE_FAILED | ...)`.
 */
import type {
  BuildAuthUrlParams,
  ExchangeCodeParams,
  ProviderOAuthAdapter,
  ProviderProfile,
  RawTokenSet,
  RefreshParams,
  RevokeParams,
} from "../oauth/adapter";
import { getSecret } from "../lib/secrets";
import { logger } from "../lib/logger";
import { getConnectorEnv } from "../lib/config";

const log = logger.withContext({ phase: "08", provider: "tiktok" });

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

export const TIKTOK_AUTH_URL = "https://www.tiktok.com/v2/auth/authorize/";
export const TIKTOK_TOKEN_URL = "https://open.tiktokapis.com/v2/oauth/token/";
export const TIKTOK_REVOKE_URL = "https://open.tiktokapis.com/v2/oauth/revoke/";
export const TIKTOK_USER_INFO_URL = "https://open.tiktokapis.com/v2/user/info/";

/** Public sandbox client key. Hardcoding here is intentional — it is not a secret. */
export const TIKTOK_SANDBOX_CLIENT_KEY = "sbaw4c49dgx7odxlai";

/** Scope set requested for v1.1. Comma-separated per TikTok spec. */
export const TIKTOK_DEFAULT_SCOPES = [
  "user.info.basic",
  "video.list",
  "video.upload",
  "video.publish",
] as const;

/** `fields` query param for user info endpoint. Dictates the response shape. */
const USER_INFO_FIELDS = [
  "open_id",
  "union_id",
  "display_name",
  "avatar_url",
  "follower_count",
  "video_count",
].join(",");

/** Secret Manager key. Prefix flips per environment (`staging-` / `prod-`). */
export function resolveClientSecretName(): string {
  return getConnectorEnv() === "prod"
    ? "prod-tiktok-client-secret"
    : "staging-tiktok-sandbox-client-secret";
}

// ---------------------------------------------------------------------------
// Token endpoint response shape
// ---------------------------------------------------------------------------

interface TikTokTokenResponse {
  access_token: string;
  refresh_token: string;
  /** Scope is space- OR comma-separated depending on TikTok's mood. */
  scope: string;
  /** Seconds. */
  expires_in: number;
  /** Refresh token lifetime. */
  refresh_expires_in?: number;
  open_id: string;
  token_type: "Bearer";
  /** Error payload present on failure. */
  error?: string;
  error_description?: string;
}

interface TikTokUserInfoResponse {
  data: {
    user: {
      open_id: string;
      union_id?: string;
      display_name?: string;
      avatar_url?: string;
      follower_count?: number;
      video_count?: number;
    };
  };
  error: {
    code: string;
    message?: string;
  };
}

// ---------------------------------------------------------------------------
// Adapter implementation
// ---------------------------------------------------------------------------

/**
 * Concrete adapter. Exported as a singleton `tikTokAdapter` at module
 * bottom; importing this module performs the `register(...)` call.
 */
class TikTokAdapter implements ProviderOAuthAdapter {
  readonly provider = "tiktok" as const;
  readonly defaultScopes: string[] = [...TIKTOK_DEFAULT_SCOPES];

  private readonly clientKey: string;

  constructor(clientKey: string = TIKTOK_SANDBOX_CLIENT_KEY) {
    this.clientKey = clientKey;
  }

  // ---------------- buildAuthUrl ----------------

  buildAuthUrl(params: BuildAuthUrlParams): string {
    const scopes = (params.scopes ?? this.defaultScopes).join(",");
    const url = new URL(TIKTOK_AUTH_URL);
    url.searchParams.set("client_key", this.clientKey);
    url.searchParams.set("scope", scopes);
    url.searchParams.set("response_type", "code");
    url.searchParams.set("redirect_uri", params.redirectUri);
    url.searchParams.set("state", params.state);
    url.searchParams.set("code_challenge", params.codeChallenge);
    url.searchParams.set("code_challenge_method", "S256");
    return url.toString();
  }

  // ---------------- exchangeCode ----------------

  async exchangeCode(params: ExchangeCodeParams): Promise<RawTokenSet> {
    const secret = await getSecret(resolveClientSecretName());
    const body = new URLSearchParams({
      client_key: this.clientKey,
      client_secret: secret,
      code: params.code,
      grant_type: "authorization_code",
      redirect_uri: params.redirectUri,
      code_verifier: params.codeVerifier,
    });
    const data = await this.postForm<TikTokTokenResponse>(
      TIKTOK_TOKEN_URL,
      body,
      "exchangeCode"
    );
    return this.toRawTokenSet(data);
  }

  // ---------------- refresh ----------------

  async refresh(params: RefreshParams): Promise<RawTokenSet> {
    const secret = await getSecret(resolveClientSecretName());
    const body = new URLSearchParams({
      client_key: this.clientKey,
      client_secret: secret,
      grant_type: "refresh_token",
      refresh_token: params.refreshToken,
    });
    const data = await this.postForm<TikTokTokenResponse>(
      TIKTOK_TOKEN_URL,
      body,
      "refresh"
    );

    // Rotation detection. TikTok MAY return the same refresh token back,
    // MAY return a new one, OR (rarely) null. The broker's rotation logic
    // sits above us; we just log the signal.
    if (data.refresh_token && data.refresh_token !== params.refreshToken) {
      log.warn("tiktok refresh rotated refresh_token", {
        rotated: true,
      });
    }

    return this.toRawTokenSet(data);
  }

  // ---------------- revoke ----------------

  async revoke(params: RevokeParams): Promise<void> {
    // TikTok's revoke endpoint supports revoking by access OR refresh token.
    // We prefer the refresh token (longer-lived, more useful to kill) and
    // fall back to the access token if the caller didn't supply one.
    const token = params.refreshToken ?? params.accessToken;
    if (!token) {
      log.warn("tiktok revoke skipped — no token provided");
      return;
    }
    const secret = await getSecret(resolveClientSecretName());
    const body = new URLSearchParams({
      client_key: this.clientKey,
      client_secret: secret,
      token,
    });
    await this.postForm<Record<string, unknown>>(
      TIKTOK_REVOKE_URL,
      body,
      "revoke"
    );
  }

  // ---------------- fetchUserProfile ----------------

  async fetchUserProfile(accessToken: string): Promise<ProviderProfile> {
    const url = `${TIKTOK_USER_INFO_URL}?fields=${encodeURIComponent(
      USER_INFO_FIELDS
    )}`;

    const response = await fetch(url, {
      method: "GET",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
    });

    const raw = (await response.json()) as TikTokUserInfoResponse;
    if (!response.ok || raw.error?.code !== "ok") {
      throw new Error(
        `tiktok: user/info/ responded HTTP ${response.status}: ${
          raw.error?.message ?? "unknown error"
        }`
      );
    }

    const user = raw.data.user;
    if (!user?.open_id) {
      throw new Error("tiktok: user/info/ missing open_id");
    }

    return {
      providerUserId: user.open_id,
      handle: user.display_name ?? null,
      followerCount:
        typeof user.follower_count === "number" ? user.follower_count : null,
    };
  }

  // ---------------- helpers ----------------

  /**
   * Shared POST helper for the token + revoke endpoints. TikTok insists on
   * `application/x-www-form-urlencoded` — any deviation returns a cryptic
   * `invalid_request`.
   *
   * @param url       Absolute endpoint.
   * @param body      URL-encoded form params.
   * @param operation Short tag for log + error messages.
   */
  private async postForm<T>(
    url: string,
    body: URLSearchParams,
    operation: string
  ): Promise<T> {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        Accept: "application/json",
      },
      body: body.toString(),
    });

    const textBody = await response.text();
    let parsed: unknown;
    try {
      parsed = textBody.length > 0 ? JSON.parse(textBody) : {};
    } catch {
      parsed = {};
    }

    if (!response.ok) {
      const snippet = textBody.slice(0, 200).replace(/[\r\n]+/g, " ");
      throw new Error(
        `tiktok: ${operation} responded HTTP ${response.status}: ${snippet}`
      );
    }

    // Some endpoints (revoke) return `{}` on success; token endpoint carries
    // an `error` string on soft failures (e.g. invalid_grant). Promote those
    // to thrown errors so the broker maps them to CODE_EXCHANGE_FAILED.
    const pMaybeErr = parsed as { error?: unknown; error_description?: unknown };
    if (
      typeof pMaybeErr.error === "string" &&
      pMaybeErr.error !== "" &&
      pMaybeErr.error !== "ok"
    ) {
      const desc =
        typeof pMaybeErr.error_description === "string"
          ? pMaybeErr.error_description
          : pMaybeErr.error;
      throw new Error(
        `tiktok: ${operation} soft-failed: ${String(pMaybeErr.error)}: ${desc}`
      );
    }

    return parsed as T;
  }

  /** Normalize TikTok's token response onto the broker's `RawTokenSet`. */
  private toRawTokenSet(data: TikTokTokenResponse): RawTokenSet {
    // Scope comes back as a space- OR comma-separated string depending on
    // which TikTok app variant issued it. Handle both.
    const rawScope = (data.scope ?? "").trim();
    const scopes = rawScope.length > 0
      ? rawScope.split(/[,\s]+/).filter((s) => s.length > 0)
      : [];

    return {
      accessToken: data.access_token,
      refreshToken: data.refresh_token ?? null,
      expiresIn: data.expires_in,
      scopes,
      rawPayload: {
        open_id: data.open_id,
        refresh_expires_in: data.refresh_expires_in,
      },
    };
  }
}

// ---------------------------------------------------------------------------
// Singleton + self-register at module load
// ---------------------------------------------------------------------------

export const tikTokAdapter = new TikTokAdapter();

// Side-effectful registration. Importing this module makes the adapter
// available under `resolve("tiktok")`. Tests can bypass by calling
// `__resetRegistryForTests()`.
import { register } from "../oauth/registry";
register(tikTokAdapter);
