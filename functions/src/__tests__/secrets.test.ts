/**
 * secrets.test.ts
 *
 * Covers:
 *   - cache hit/miss semantics
 *   - explicit `cache: false` bypass
 *   - SecretNotFoundError on empty payload
 *   - SecretNotFoundError on gRPC NOT_FOUND (code 5)
 *   - projectId resolution fallback order
 */
import {
  __setSecretClientForTests,
  getSecret,
  SecretNotFoundError,
  STAGING_SECRET_NAMES,
} from "../lib/secrets";

interface FakeClient {
  accessSecretVersion: jest.Mock;
}

function makeClient(responses: Array<unknown | Error>): FakeClient {
  let i = 0;
  return {
    accessSecretVersion: jest.fn(async () => {
      const item = responses[i++];
      if (item instanceof Error) {
        throw item;
      }
      return [item] as const;
    }),
  };
}

describe("getSecret", () => {
  const savedEnv = { ...process.env };

  beforeEach(() => {
    process.env.GCLOUD_PROJECT = "envi-by-informal-staging";
    delete process.env.GOOGLE_CLOUD_PROJECT;
  });

  afterEach(() => {
    process.env = { ...savedEnv };
    __setSecretClientForTests(null);
  });

  it("returns decoded utf8 payload on first call", async () => {
    const client = makeClient([
      { payload: { data: Buffer.from("super-secret-value", "utf8") } },
    ]);
    __setSecretClientForTests(client as never);

    const value = await getSecret("staging-tiktok-sandbox-client-secret");
    expect(value).toBe("super-secret-value");
    expect(client.accessSecretVersion).toHaveBeenCalledTimes(1);
    expect(client.accessSecretVersion).toHaveBeenCalledWith({
      name: "projects/envi-by-informal-staging/secrets/staging-tiktok-sandbox-client-secret/versions/latest",
    });
  });

  it("serves subsequent calls from the in-memory cache", async () => {
    const client = makeClient([
      { payload: { data: Buffer.from("cached-value", "utf8") } },
    ]);
    __setSecretClientForTests(client as never);

    await getSecret("staging-meta-app-secret");
    await getSecret("staging-meta-app-secret");
    await getSecret("staging-meta-app-secret");
    expect(client.accessSecretVersion).toHaveBeenCalledTimes(1);
  });

  it("bypasses cache when cache=false", async () => {
    const client = makeClient([
      { payload: { data: Buffer.from("v1", "utf8") } },
      { payload: { data: Buffer.from("v2", "utf8") } },
    ]);
    __setSecretClientForTests(client as never);

    const first = await getSecret("staging-x-bearer-token");
    const second = await getSecret("staging-x-bearer-token", { cache: false });
    expect(first).toBe("v1");
    expect(second).toBe("v2");
    expect(client.accessSecretVersion).toHaveBeenCalledTimes(2);
  });

  it("throws SecretNotFoundError when payload is empty", async () => {
    const client = makeClient([{ payload: { data: null } }]);
    __setSecretClientForTests(client as never);

    await expect(
      getSecret("staging-does-not-exist")
    ).rejects.toBeInstanceOf(SecretNotFoundError);
  });

  it("throws SecretNotFoundError on gRPC NOT_FOUND", async () => {
    const notFound = Object.assign(new Error("NOT_FOUND"), { code: 5 });
    const client = makeClient([notFound]);
    __setSecretClientForTests(client as never);

    await expect(
      getSecret("staging-missing")
    ).rejects.toBeInstanceOf(SecretNotFoundError);
  });

  it("rethrows unexpected errors", async () => {
    const boom = Object.assign(new Error("PERMISSION_DENIED"), { code: 7 });
    const client = makeClient([boom]);
    __setSecretClientForTests(client as never);

    await expect(
      getSecret("staging-threads-app-secret")
    ).rejects.toThrow("PERMISSION_DENIED");
  });

  it("throws when no project id is discoverable", async () => {
    delete process.env.GCLOUD_PROJECT;
    delete process.env.GOOGLE_CLOUD_PROJECT;

    const client = makeClient([
      { payload: { data: Buffer.from("x", "utf8") } },
    ]);
    __setSecretClientForTests(client as never);

    await expect(getSecret("staging-anything")).rejects.toThrow(
      /project id/i
    );
  });

  it("accepts an explicit projectId override", async () => {
    delete process.env.GCLOUD_PROJECT;
    const client = makeClient([
      { payload: { data: Buffer.from("override", "utf8") } },
    ]);
    __setSecretClientForTests(client as never);

    const value = await getSecret("staging-linkedin-primary-client-secret", {
      projectId: "envi-by-informal-staging",
    });
    expect(value).toBe("override");
    expect(client.accessSecretVersion).toHaveBeenCalledWith({
      name: "projects/envi-by-informal-staging/secrets/staging-linkedin-primary-client-secret/versions/latest",
    });
  });
});

describe("STAGING_SECRET_NAMES", () => {
  it("contains the 11 canonical staging secret names, unique and stable", () => {
    expect(STAGING_SECRET_NAMES).toHaveLength(11);
    expect(new Set(STAGING_SECRET_NAMES).size).toBe(
      STAGING_SECRET_NAMES.length
    );
    for (const name of STAGING_SECRET_NAMES) {
      expect(name.startsWith("staging-")).toBe(true);
    }
  });
});
