/**
 * linkedin.test.ts — unit tests for the LinkedIn OAuth adapter.
 *
 * Phase 11. Exercises:
 *   - `buildAuthUrl` shape (scope join, state passthrough, no PKCE).
 *   - `exchangeCode` → RawTokenSet normalization, refresh-token null
 *     fallback, scope string parsing.
 *   - `refresh` throws `REFRESH_FAILED` (LinkedIn has no refresh flow).
 *   - `revoke` is a no-op that logs but does not throw.
 *   - `fetchMemberProfile` shapes `{providerUserId, personUrn, handle}`.
 *   - `fetchAdminOrganizations` composes the two-call fetch; returns
 *     empty array on 403 rather than throwing.
 *
 * Network is fully stubbed via `__setFetchForTests`.
 */
import {
  __setFetchForTests,
  fetchAdminOrganizations,
  fetchMemberProfile,
  linkedInAdapter,
  linkedInProvider,
  LINKEDIN_API_HEADERS,
  LINKEDIN_CLIENT_ID,
  LINKEDIN_MEMBER_SCOPES,
} from "./linkedin";
import { __setSecretClientForTests } from "../lib/secrets";
import { OAuthBrokerErrorCode } from "../oauth/errors";

// ---------------------------------------------------------------------------
// Fetch stub helpers
// ---------------------------------------------------------------------------

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

// Secret-manager stub returns a constant client secret for every test.
beforeAll(() => {
  __setSecretClientForTests({
    accessSecretVersion: async () => [
      { payload: { data: "stub-client-secret" } },
    ],
  } as unknown as Parameters<typeof __setSecretClientForTests>[0]);
});

afterAll(() => {
  __setSecretClientForTests(null);
  __setFetchForTests(null);
});

afterEach(() => {
  __setFetchForTests(null);
});

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("linkedInProvider static shape", () => {
  it("matches the Phase 11 spec exactly", () => {
    expect(linkedInProvider).toEqual({
      provider: "linkedin",
      clientId: LINKEDIN_CLIENT_ID,
      authUrl: "https://www.linkedin.com/oauth/v2/authorization",
      tokenUrl: "https://www.linkedin.com/oauth/v2/accessToken",
      tokenGrantType: "authorization_code",
      scopes: [...LINKEDIN_MEMBER_SCOPES],
    });
  });

  it("pins LinkedIn-Version to a non-sunset YYYYMM", () => {
    // 202504 and earlier are sunset as of 2026-04. Any future bump needs
    // to keep the regex-match on a 6-digit YYYYMM string.
    expect(LINKEDIN_API_HEADERS["Linkedin-Version"]).toMatch(/^\d{6}$/);
    const year = Number(LINKEDIN_API_HEADERS["Linkedin-Version"].slice(0, 4));
    expect(year).toBeGreaterThanOrEqual(2025);
  });
});

describe("linkedInAdapter.buildAuthUrl", () => {
  it("composes a LinkedIn authorize URL with state + scopes (no PKCE)", () => {
    const url = linkedInAdapter.buildAuthUrl({
      state: "signed-state-jwt",
      codeChallenge: "IGNORED-linkedin-no-pkce",
      redirectUri: "enviapp://oauth-callback/linkedin",
      scopes: ["r_liteprofile", "w_member_social"],
    });
    expect(url.startsWith("https://www.linkedin.com/oauth/v2/authorization?")).toBe(true);
    expect(url).toContain("client_id=86geh6d7rzwu11");
    expect(url).toContain("state=signed-state-jwt");
    expect(url).toContain("scope=r_liteprofile+w_member_social");
    expect(url).toContain("redirect_uri=enviapp%3A%2F%2Foauth-callback%2Flinkedin");
    // PKCE challenge MUST NOT leak into the URL.
    expect(url).not.toContain("code_challenge");
  });

  it("falls back to default member scopes when caller passes none", () => {
    const url = linkedInAdapter.buildAuthUrl({
      state: "state",
      codeChallenge: "c",
      redirectUri: "enviapp://oauth-callback/linkedin",
    });
    expect(url).toContain("scope=r_liteprofile+w_member_social");
  });
});

describe("linkedInAdapter.exchangeCode", () => {
  it("normalizes the access token response into RawTokenSet", async () => {
    __setFetchForTests(async (_url, init) => {
      const body = (init as RequestInit).body as string;
      expect(body).toContain("grant_type=authorization_code");
      expect(body).toContain("client_secret=stub-client-secret");
      return jsonResponse({
        access_token: "ya29-token",
        expires_in: 5184000,
        scope: "r_liteprofile w_member_social",
      });
    });

    const token = await linkedInAdapter.exchangeCode({
      code: "abc",
      codeVerifier: "ignored",
      redirectUri: "enviapp://oauth-callback/linkedin",
    });
    expect(token.accessToken).toBe("ya29-token");
    expect(token.refreshToken).toBeNull();
    expect(token.expiresIn).toBe(5184000);
    expect(token.scopes).toEqual(["r_liteprofile", "w_member_social"]);
  });

  it("accepts comma-separated scope strings", async () => {
    __setFetchForTests(async () =>
      jsonResponse({
        access_token: "t",
        expires_in: 1,
        scope: "r_liteprofile,w_member_social",
      })
    );
    const token = await linkedInAdapter.exchangeCode({
      code: "abc",
      codeVerifier: "ignored",
      redirectUri: "enviapp://oauth-callback/linkedin",
    });
    expect(token.scopes).toEqual(["r_liteprofile", "w_member_social"]);
  });

  it("throws CODE_EXCHANGE_FAILED on non-2xx", async () => {
    __setFetchForTests(async () => jsonResponse({ error: "bad" }, 400));
    await expect(
      linkedInAdapter.exchangeCode({
        code: "abc",
        codeVerifier: "ignored",
        redirectUri: "enviapp://oauth-callback/linkedin",
      })
    ).rejects.toMatchObject({ code: OAuthBrokerErrorCode.CODE_EXCHANGE_FAILED });
  });
});

describe("linkedInAdapter.refresh", () => {
  it("throws REFRESH_FAILED because LinkedIn issues no refresh tokens", async () => {
    await expect(
      linkedInAdapter.refresh({ refreshToken: "never-issued" })
    ).rejects.toMatchObject({ code: OAuthBrokerErrorCode.REFRESH_FAILED });
  });
});

describe("linkedInAdapter.revoke", () => {
  it("is a no-op (LinkedIn has no revocation endpoint)", async () => {
    // Must not throw, must not touch fetch.
    __setFetchForTests(async () => {
      throw new Error("revoke should not touch the network");
    });
    await expect(
      linkedInAdapter.revoke({ accessToken: "tok" })
    ).resolves.toBeUndefined();
  });
});

describe("fetchMemberProfile", () => {
  it("composes personUrn + handle from /v2/me", async () => {
    __setFetchForTests(async (url) => {
      expect(String(url)).toBe("https://api.linkedin.com/v2/me");
      return jsonResponse({
        id: "abc123",
        localizedFirstName: "Jane",
        localizedLastName: "Doe",
      });
    });
    const profile = await fetchMemberProfile("tok");
    expect(profile).toEqual({
      providerUserId: "abc123",
      personUrn: "urn:li:person:abc123",
      handle: "Jane Doe",
    });
  });

  it("falls back to 'LinkedIn Member' when both names are absent", async () => {
    __setFetchForTests(async () => jsonResponse({ id: "abc123" }));
    const profile = await fetchMemberProfile("tok");
    expect(profile.handle).toBe("LinkedIn Member");
  });
});

describe("fetchAdminOrganizations", () => {
  it("returns empty array on 403 without throwing", async () => {
    __setFetchForTests(async () => jsonResponse({}, 403));
    const orgs = await fetchAdminOrganizations("tok");
    expect(orgs).toEqual([]);
  });

  it("composes the two-call fetch into a summary list", async () => {
    let calls = 0;
    __setFetchForTests(async (url) => {
      calls++;
      if (calls === 1) {
        expect(String(url)).toContain("/rest/organizationAcls");
        return jsonResponse({
          elements: [
            { organization: "urn:li:organization:99" },
            { organization: "urn:li:organization:100" },
          ],
        });
      }
      expect(String(url)).toContain("/rest/organizationsLookup");
      return jsonResponse({
        results: {
          "99": {
            localizedName: "ENVI Studio",
            logoV2: { cropped: "urn:li:digitalmediaAsset:xyz" },
          },
          "100": { localizedName: "ENVI Labs" },
        },
      });
    });

    const orgs = await fetchAdminOrganizations("tok");
    expect(orgs).toEqual([
      {
        id: "99",
        urn: "urn:li:organization:99",
        localizedName: "ENVI Studio",
        logoImageUrn: "urn:li:digitalmediaAsset:xyz",
      },
      {
        id: "100",
        urn: "urn:li:organization:100",
        localizedName: "ENVI Labs",
        logoImageUrn: null,
      },
    ]);
  });

  it("sends Linkedin-Version on every rest call", async () => {
    const seenHeaders: Array<Record<string, string>> = [];
    __setFetchForTests(async (_url, init) => {
      const headers = (init as RequestInit).headers as Record<string, string>;
      seenHeaders.push(headers);
      return jsonResponse({
        elements: [{ organization: "urn:li:organization:1" }],
      });
    });
    // lookup call will use the same stub; we only assert the ACL call
    // carried the header, then short-circuit by making lookup return {}.
    __setFetchForTests(async (_url, init) => {
      const headers = (init as RequestInit).headers as Record<string, string>;
      seenHeaders.push(headers);
      if (String(_url).includes("organizationAcls")) {
        return jsonResponse({
          elements: [{ organization: "urn:li:organization:1" }],
        });
      }
      return jsonResponse({ results: {} });
    });

    await fetchAdminOrganizations("tok");
    expect(seenHeaders.length).toBeGreaterThanOrEqual(1);
    for (const h of seenHeaders) {
      expect(h["Linkedin-Version"]).toBe(LINKEDIN_API_HEADERS["Linkedin-Version"]);
      expect(h["X-Restli-Protocol-Version"]).toBe("2.0.0");
    }
  });
});
