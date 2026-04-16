/**
 * linkedin.ts — LinkedIn OAuth 2.0 adapter + profile helpers.
 *
 * Phase 11. Implements the `ProviderOAuthAdapter` contract for LinkedIn,
 * plus the two LinkedIn-specific fetchers the broker layer leans on at
 * profile-persist time:
 *   - `fetchMemberProfile` — called from `exchangeCode` so we can persist
 *     `personUrn` + `handle` alongside the encrypted token pair.
 *   - `fetchAdminOrganizations` — called by the connectors route to
 *     surface the company-page list to the iOS author picker.
 *
 * API shape (verified 2026-04-16)
 * -------------------------------
 * - Auth:    GET  https://www.linkedin.com/oauth/v2/authorization
 * - Token:   POST https://www.linkedin.com/oauth/v2/accessToken
 *              Content-Type: application/x-www-form-urlencoded
 *              body: grant_type=authorization_code & code & client_id
 *                    & client_secret & redirect_uri
 *            Response: { access_token, expires_in, scope }
 *            Refresh tokens are NOT issued by default (contrast with
 *            Google / Twitter). Rely on the 60-day access-token TTL and
 *            force a reauth on expiry.
 * - Revoke:  no endpoint. Documented; we log and delete the Firestore
 *            row on `disconnect`.
 * - PKCE:    unsupported; the broker skips the S256 challenge for
 *            LinkedIn specifically. State-only CSRF is sufficient per
 *            the Phase 07 threat model.
 * - Profile: GET https://api.linkedin.com/v2/me
 *              returns: { id, localizedFirstName, localizedLastName }
 *            Handle is composed as `${firstName} ${lastName}`. The
 *            stable provider user id is the `id` field; we persist it as
 *            `urn:li:person:{id}` so the publish layer can feed it
 *            straight into the `author` field of /rest/posts without a
 *            second string concat.
 *
 * MDP approval
 * ------------
 * `r_organization_social` + `w_organization_social` are gated behind
 * LinkedIn's Marketing Developer Platform approval (email form,
 * 1–5 business days). The adapter requests only the member pair by
 * default; the iOS author picker triggers a re-consent round trip with
 * the expanded scope set when the user wants to post as an organization.
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
import { OAuthBrokerError, OAuthBrokerErrorCode } from "../oauth/errors";
import { logger } from "../lib/logger";
import { getSecret } from "../lib/secrets";

const log = logger.withContext({ phase: "11", provider: "linkedin" });

// ---------------------------------------------------------------------------
// Module constants
// ---------------------------------------------------------------------------

export const LINKEDIN_CLIENT_ID = "86geh6d7rzwu11";
export const LINKEDIN_AUTH_URL =
  "https://www.linkedin.com/oauth/v2/authorization";
export const LINKEDIN_TOKEN_URL =
  "https://www.linkedin.com/oauth/v2/accessToken";
export const LINKEDIN_SECRET_NAME = "staging-linkedin-primary-client-secret";

/**
 * Headers every call to `api.linkedin.com/rest/*` must carry. The
 * `Linkedin-Version: 202505` pin is deliberate — LinkedIn sunsets
 * versions ~12 months after release, and 202504 and earlier are already
 * past their sunset date as of 2026-04-16.
 *
 * Review cadence: revisit on 2027-04-01. When bumping, grep this file
 * AND `linkedin-publish.ts` — the constant appears in both.
 */
export const LINKEDIN_API_HEADERS = {
  "Linkedin-Version": "202505",
  "X-Restli-Protocol-Version": "2.0.0",
  "Content-Type": "application/json",
} as const;

/** Member-tier scopes the broker requests by default. */
export const LINKEDIN_MEMBER_SCOPES = [
  "r_liteprofile",
  "w_member_social",
] as const;

/** Organization-tier scopes (MDP-gated). Requested on-demand. */
export const LINKEDIN_ORG_SCOPES = [
  "r_organization_social",
  "w_organization_social",
] as const;

/**
 * LinkedIn's access tokens last 60 days (5,184,000 seconds). Tokens are
 * long-lived specifically so apps don't need a refresh cadence — we
 * surface a reauth prompt when the persisted `expiresAt` falls below 7
 * days (handled in Phase 12's refresh cron; see LinkedIn branch in
 * `cron-refresh.ts`).
 */
export const LINKEDIN_ACCESS_TOKEN_TTL_SECONDS = 60 * 24 * 60 * 60;

// ---------------------------------------------------------------------------
// Static provider config (shape consumed by the broker registry)
// ---------------------------------------------------------------------------

export interface OAuthProviderConfig {
  provider: "linkedin";
  clientId: string;
  authUrl: string;
  tokenUrl: string;
  tokenGrantType: "authorization_code";
  scopes: string[];
}

export const linkedInProvider: OAuthProviderConfig = {
  provider: "linkedin",
  clientId: LINKEDIN_CLIENT_ID,
  authUrl: LINKEDIN_AUTH_URL,
  tokenUrl: LINKEDIN_TOKEN_URL,
  tokenGrantType: "authorization_code",
  scopes: [...LINKEDIN_MEMBER_SCOPES],
};

// ---------------------------------------------------------------------------
// Fetch injection (for tests)
// ---------------------------------------------------------------------------

type FetchLike = typeof fetch;
let fetchImpl: FetchLike = fetch;

/** @internal test-only override */
export function __setFetchForTests(impl: FetchLike | null): void {
  fetchImpl = impl ?? fetch;
}

/** Fetch the client secret at call time. Cached by `secrets.ts`. */
async function loadClientSecret(): Promise<string> {
  return getSecret(LINKEDIN_SECRET_NAME);
}

// ---------------------------------------------------------------------------
// Profile types
// ---------------------------------------------------------------------------

/** Normalized LinkedIn member profile returned by `fetchMemberProfile`. */
export interface LinkedInMemberProfile {
  /** Bare member id. */
  providerUserId: string;
  /** `urn:li:person:{id}` — ready for direct use as `author` field. */
  personUrn: string;
  /** Composed `"{firstName} {lastName}"`. */
  handle: string;
}

/** One entry in the admin-organization list returned by the broker. */
export interface LinkedInOrganizationSummary {
  id: string;
  urn: string;
  localizedName: string;
  logoImageUrn: string | null;
}

// ---------------------------------------------------------------------------
// Adapter implementation
// ---------------------------------------------------------------------------

export const linkedInAdapter: ProviderOAuthAdapter = {
  provider: "linkedin",
  defaultScopes: [...LINKEDIN_MEMBER_SCOPES],

  buildAuthUrl(params: BuildAuthUrlParams): string {
    // LinkedIn does NOT honor PKCE (`code_challenge`). We omit the
    // challenge from the URL deliberately; CSRF protection relies on
    // the signed `state` JWT the broker mints.
    const scopes = params.scopes ?? [...LINKEDIN_MEMBER_SCOPES];
    const query = new URLSearchParams({
      response_type: "code",
      client_id: LINKEDIN_CLIENT_ID,
      redirect_uri: params.redirectUri,
      state: params.state,
      scope: scopes.join(" "),
    });
    return `${LINKEDIN_AUTH_URL}?${query.toString()}`;
  },

  async exchangeCode(params: ExchangeCodeParams): Promise<RawTokenSet> {
    const clientSecret = await loadClientSecret();
    const body = new URLSearchParams({
      grant_type: "authorization_code",
      code: params.code,
      redirect_uri: params.redirectUri,
      client_id: LINKEDIN_CLIENT_ID,
      client_secret: clientSecret,
    });

    const response = await fetchImpl(LINKEDIN_TOKEN_URL, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: body.toString(),
    });

    if (!response.ok) {
      const text = await safeReadText(response);
      log.error("linkedin exchangeCode failed", {
        status: response.status,
        bodyPreview: text.slice(0, 200),
      });
      throw new OAuthBrokerError(
        OAuthBrokerErrorCode.CODE_EXCHANGE_FAILED,
        `linkedin token endpoint returned ${response.status}`
      );
    }

    const payload = (await response.json()) as {
      access_token: string;
      expires_in: number;
      scope?: string;
      refresh_token?: string;
    };

    // Scope echo may arrive space- OR comma-separated depending on the
    // app configuration. Normalize to an array.
    const rawScope = payload.scope ?? LINKEDIN_MEMBER_SCOPES.join(" ");
    const scopes = rawScope
      .split(/[\s,]+/)
      .map((s) => s.trim())
      .filter((s) => s.length > 0);

    return {
      accessToken: payload.access_token,
      // LinkedIn does NOT issue refresh tokens under the default product
      // configuration. When absent, persist `null`; the broker handles
      // this via the reauth-on-expiry flow.
      refreshToken: payload.refresh_token ?? null,
      expiresIn: payload.expires_in ?? LINKEDIN_ACCESS_TOKEN_TTL_SECONDS,
      scopes,
    };
  },

  async refresh(_params: RefreshParams): Promise<RawTokenSet> {
    // Intentionally unsupported. Phase 12's refresh cron special-cases
    // LinkedIn — the scheduled job writes a `requiresReauth: true` flag
    // on the connection doc instead of calling this path.
    throw new OAuthBrokerError(
      OAuthBrokerErrorCode.REFRESH_FAILED,
      "linkedin does not issue refresh tokens; force reauth on expiry"
    );
  },

  async revoke(_params: RevokeParams): Promise<void> {
    // LinkedIn ships no programmatic revocation endpoint. We log for
    // audit purposes; the disconnect handler still deletes the
    // encrypted Firestore row so the token is unreachable from ENVI.
    log.warn(
      "linkedin revokeToken: no revocation endpoint exists; firestore doc deleted by caller"
    );
  },

  async fetchUserProfile(accessToken: string): Promise<ProviderProfile> {
    const profile = await fetchMemberProfile(accessToken);
    return {
      providerUserId: profile.providerUserId,
      handle: profile.handle,
      // LinkedIn does not expose follower counts on `r_liteprofile`.
      followerCount: null,
    };
  },
};

// ---------------------------------------------------------------------------
// Profile fetcher
// ---------------------------------------------------------------------------

/**
 * `/v2/me` returns a typed subset of the member's profile. We only need
 * the id + localized name pair; everything else is dropped.
 *
 * @throws OAuthBrokerError CODE_EXCHANGE_FAILED on non-2xx (shared code,
 *         since this runs as part of the post-code-exchange persist step).
 */
export async function fetchMemberProfile(
  accessToken: string
): Promise<LinkedInMemberProfile> {
  const response = await fetchImpl("https://api.linkedin.com/v2/me", {
    method: "GET",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      // `/v2/me` pre-dates the `Linkedin-Version` header; sending it is
      // harmless but not required.
    },
  });

  if (!response.ok) {
    throw new OAuthBrokerError(
      OAuthBrokerErrorCode.CODE_EXCHANGE_FAILED,
      `linkedin /v2/me returned ${response.status}`
    );
  }

  const payload = (await response.json()) as {
    id: string;
    localizedFirstName?: string;
    localizedLastName?: string;
  };

  const firstName = payload.localizedFirstName ?? "";
  const lastName = payload.localizedLastName ?? "";
  const handle = `${firstName} ${lastName}`.trim() || "LinkedIn Member";

  return {
    providerUserId: payload.id,
    personUrn: `urn:li:person:${payload.id}`,
    handle,
  };
}

// ---------------------------------------------------------------------------
// Admin-organization fetcher
// ---------------------------------------------------------------------------

/**
 * Two-step fetch:
 *  1. `GET /rest/organizationAcls?q=roleAssignee&role=ADMINISTRATOR&state=APPROVED&count=100`
 *     → `elements[]` where each entry includes `organization` (a URN).
 *  2. `GET /rest/organizationsLookup?ids=List({id1},{id2},…)` → `results`
 *     map keyed by the bare id, with `localizedName` + `logoV2`.
 *
 * Returns an empty array when the token lacks `r_organization_social`
 * (LinkedIn answers with a 403 that we swallow into `[]` so the iOS
 * picker can still render the member row without an error banner).
 */
export async function fetchAdminOrganizations(
  accessToken: string
): Promise<LinkedInOrganizationSummary[]> {
  const aclResponse = await fetchImpl(
    "https://api.linkedin.com/rest/organizationAcls" +
      "?q=roleAssignee&role=ADMINISTRATOR&state=APPROVED&count=100",
    {
      method: "GET",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Linkedin-Version": LINKEDIN_API_HEADERS["Linkedin-Version"],
        "X-Restli-Protocol-Version":
          LINKEDIN_API_HEADERS["X-Restli-Protocol-Version"],
      },
    }
  );

  if (aclResponse.status === 403) {
    log.info("linkedin organizationAcls 403 — token missing org scope");
    return [];
  }
  if (!aclResponse.ok) {
    throw new OAuthBrokerError(
      OAuthBrokerErrorCode.CODE_EXCHANGE_FAILED,
      `linkedin organizationAcls returned ${aclResponse.status}`
    );
  }

  const aclPayload = (await aclResponse.json()) as {
    elements?: Array<{ organization?: string }>;
  };
  const urns = (aclPayload.elements ?? [])
    .map((el) => el.organization)
    .filter((v): v is string => typeof v === "string" && v.length > 0);

  if (urns.length === 0) {
    return [];
  }

  // Extract bare ids for the lookup call.
  const ids = urns.map((urn) => {
    const parts = urn.split(":");
    return parts[parts.length - 1];
  });

  const idsListExpr = `List(${ids.join(",")})`;
  const lookupResponse = await fetchImpl(
    `https://api.linkedin.com/rest/organizationsLookup?ids=${encodeURIComponent(idsListExpr)}`,
    {
      method: "GET",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Linkedin-Version": LINKEDIN_API_HEADERS["Linkedin-Version"],
        "X-Restli-Protocol-Version":
          LINKEDIN_API_HEADERS["X-Restli-Protocol-Version"],
      },
    }
  );

  if (!lookupResponse.ok) {
    throw new OAuthBrokerError(
      OAuthBrokerErrorCode.CODE_EXCHANGE_FAILED,
      `linkedin organizationsLookup returned ${lookupResponse.status}`
    );
  }

  const lookupPayload = (await lookupResponse.json()) as {
    results?: Record<
      string,
      {
        localizedName?: string;
        logoV2?: { cropped?: string };
      }
    >;
  };

  return ids.map((id, i): LinkedInOrganizationSummary => {
    const entry = lookupPayload.results?.[id];
    return {
      id,
      urn: urns[i],
      localizedName: entry?.localizedName ?? `Organization ${id}`,
      logoImageUrn: entry?.logoV2?.cropped ?? null,
    };
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function safeReadText(response: Response): Promise<string> {
  try {
    return await response.text();
  } catch {
    return "";
  }
}
