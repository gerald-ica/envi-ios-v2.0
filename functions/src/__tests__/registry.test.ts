/**
 * registry.test.ts — register/resolve behaviour of the adapter registry.
 */
import {
  __resetRegistryForTests,
  listRegistered,
  register,
  resolve,
} from "../oauth/registry";
import type { ProviderOAuthAdapter } from "../oauth/adapter";
import { OAuthBrokerErrorCode } from "../oauth/errors";

function makeStubAdapter(
  provider: ProviderOAuthAdapter["provider"]
): ProviderOAuthAdapter {
  return {
    provider,
    defaultScopes: ["scope-a"],
    buildAuthUrl: () => `https://auth.example.com/${provider}`,
    exchangeCode: async () => ({
      accessToken: "at",
      refreshToken: "rt",
      expiresIn: 3600,
      scopes: ["scope-a"],
    }),
    refresh: async () => ({
      accessToken: "at2",
      refreshToken: "rt2",
      expiresIn: 3600,
      scopes: ["scope-a"],
    }),
    revoke: async () => {},
    fetchUserProfile: async () => ({
      providerUserId: `stub-${provider}`,
      handle: "handle",
      followerCount: 1,
    }),
  };
}

describe("oauth registry", () => {
  beforeEach(() => {
    __resetRegistryForTests();
  });

  it("registers + resolves an adapter by provider slug", () => {
    const adapter = makeStubAdapter("tiktok");
    register(adapter);
    expect(resolve("tiktok")).toBe(adapter);
    expect(listRegistered()).toEqual(["tiktok"]);
  });

  it("throws PROVIDER_NOT_REGISTERED for unknown providers", () => {
    expect(() => resolve("tiktok")).toThrow(
      expect.objectContaining({
        code: OAuthBrokerErrorCode.PROVIDER_NOT_REGISTERED,
      })
    );
  });

  it("rejects registration for non-SupportedProvider slugs", () => {
    const bogus = {
      ...makeStubAdapter("tiktok"),
      provider: "snapchat" as never,
    };
    expect(() => register(bogus)).toThrow(/unknown provider/);
  });

  it("tolerates double-registration of the same adapter instance", () => {
    const adapter = makeStubAdapter("x");
    register(adapter);
    expect(() => register(adapter)).not.toThrow();
    expect(listRegistered()).toEqual(["x"]);
  });

  it("rejects registering a different adapter for the same provider", () => {
    register(makeStubAdapter("linkedin"));
    expect(() => register(makeStubAdapter("linkedin"))).toThrow(
      /different adapter/
    );
  });
});
