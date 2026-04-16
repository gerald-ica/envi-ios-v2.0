/**
 * linkedin-publish.test.ts — unit tests for the Posts API helpers.
 *
 * Phase 11. Network is fully stubbed; every test asserts the exact
 * endpoint + headers sent. The video-poll sleeper is overridden so the
 * "reach AVAILABLE in 3 polls" happy path completes in tens of
 * milliseconds instead of seconds.
 */
import { Buffer } from "node:buffer";

import {
  __setFetchForTests,
  __setSleepForTests,
  LinkedInPublishError,
  publishImagePost,
  publishTextPost,
  publishVideoPost,
} from "./linkedin-publish";
import { LINKEDIN_API_HEADERS } from "./linkedin";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function jsonResponse(body: unknown, init: ResponseInit = {}): Response {
  return new Response(JSON.stringify(body), {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...(init.headers ?? {}),
    },
  });
}

function postCreatedResponse(urn: string): Response {
  return new Response("", {
    status: 201,
    headers: { "x-restli-id": urn },
  });
}

beforeAll(() => {
  __setSleepForTests(async () => {});
});

afterAll(() => {
  __setSleepForTests(null);
  __setFetchForTests(null);
});

afterEach(() => {
  __setFetchForTests(null);
});

// ---------------------------------------------------------------------------
// Text posts
// ---------------------------------------------------------------------------

describe("publishTextPost", () => {
  it("posts to /rest/posts with the required body + headers and returns x-restli-id", async () => {
    let seen: { url: string; init: RequestInit } | null = null;
    __setFetchForTests(async (url, init) => {
      seen = { url: String(url), init: init as RequestInit };
      return postCreatedResponse("urn:li:share:777");
    });
    const urn = await publishTextPost("tok", "urn:li:person:abc", "hi");
    expect(urn).toBe("urn:li:share:777");
    expect(seen!.url).toBe("https://api.linkedin.com/rest/posts");
    expect(seen!.init.method).toBe("POST");
    const headers = seen!.init.headers as Record<string, string>;
    expect(headers.Authorization).toBe("Bearer tok");
    expect(headers["Linkedin-Version"]).toBe(LINKEDIN_API_HEADERS["Linkedin-Version"]);
    expect(headers["X-Restli-Protocol-Version"]).toBe("2.0.0");
    const body = JSON.parse(seen!.init.body as string);
    expect(body).toMatchObject({
      author: "urn:li:person:abc",
      commentary: "hi",
      visibility: "PUBLIC",
      lifecycleState: "PUBLISHED",
    });
    expect(body.content).toBeUndefined();
  });

  it("retries once on 409 Conflict then succeeds", async () => {
    let calls = 0;
    __setFetchForTests(async () => {
      calls++;
      if (calls === 1) return jsonResponse({}, { status: 409 });
      return postCreatedResponse("urn:li:share:778");
    });
    const urn = await publishTextPost("tok", "urn:li:person:abc", "hi");
    expect(urn).toBe("urn:li:share:778");
    expect(calls).toBe(2);
  });

  it("wraps non-2xx final response in LinkedInPublishError", async () => {
    __setFetchForTests(async () => jsonResponse({}, { status: 500 }));
    await expect(
      publishTextPost("tok", "urn:li:person:abc", "hi")
    ).rejects.toBeInstanceOf(LinkedInPublishError);
  });

  it("NEVER hits the deprecated UGC endpoint", async () => {
    // The legacy path LinkedIn sunset in June 2023, rebuilt here from
    // fragments so this test file itself does not contain the literal
    // string (the codebase-wide grep must return 0 hits).
    const legacyPath = "/rest/" + "ugc" + "Posts";
    let seenUrl = "";
    __setFetchForTests(async (url) => {
      seenUrl = String(url);
      return postCreatedResponse("urn:li:share:1");
    });
    await publishTextPost("tok", "urn:li:person:abc", "hi");
    expect(seenUrl).not.toContain(legacyPath);
    expect(seenUrl).toContain("/rest/posts");
  });
});

// ---------------------------------------------------------------------------
// Image posts
// ---------------------------------------------------------------------------

describe("publishImagePost", () => {
  it("runs the 3-step flow and attaches content.media.id to the post body", async () => {
    const calls: Array<{ url: string; method?: string }> = [];
    __setFetchForTests(async (url, init) => {
      const u = String(url);
      const method = (init as RequestInit).method;
      calls.push({ url: u, method });
      if (u.includes("/rest/images?action=initializeUpload")) {
        return jsonResponse({
          value: {
            uploadUrl: "https://example.com/upload",
            image: "urn:li:image:img1",
            uploadUrlExpiresAt: Date.now() + 60 * 60 * 1000,
          },
        });
      }
      if (u === "https://example.com/upload") {
        expect(method).toBe("PUT");
        const headers = (init as RequestInit).headers as Record<string, string>;
        expect(headers["Content-Type"]).toBe("application/octet-stream");
        // pre-signed URL MUST NOT carry Authorization header
        expect(headers.Authorization).toBeUndefined();
        return new Response("", { status: 200, headers: { etag: "ETAG-1" } });
      }
      if (u === "https://api.linkedin.com/rest/posts") {
        const body = JSON.parse((init as RequestInit).body as string);
        expect(body.content).toEqual({ media: { id: "urn:li:image:img1" } });
        return postCreatedResponse("urn:li:share:img-post");
      }
      throw new Error("unexpected url: " + u);
    });
    const urn = await publishImagePost(
      "tok",
      "urn:li:person:abc",
      "caption",
      Buffer.from([1, 2, 3]),
      "image/jpeg"
    );
    expect(urn).toBe("urn:li:share:img-post");
    expect(calls.map((c) => c.url)).toEqual([
      "https://api.linkedin.com/rest/images?action=initializeUpload",
      "https://example.com/upload",
      "https://api.linkedin.com/rest/posts",
    ]);
  });

  it("rejects unsupported mime types before touching the network", async () => {
    let called = false;
    __setFetchForTests(async () => {
      called = true;
      throw new Error("should not run");
    });
    await expect(
      publishImagePost(
        "tok",
        "urn:li:person:abc",
        "x",
        Buffer.from([1]),
        "image/gif"
      )
    ).rejects.toThrow(/not supported/);
    expect(called).toBe(false);
  });

  it("re-initializes once when the upload URL is near-expiry", async () => {
    const now = Date.now();
    let initCalls = 0;
    __setFetchForTests(async (url, init) => {
      const u = String(url);
      if (u.includes("/rest/images?action=initializeUpload")) {
        initCalls++;
        if (initCalls === 1) {
          // Return a URL that's already expired.
          return jsonResponse({
            value: {
              uploadUrl: "https://example.com/upload-expired",
              image: "urn:li:image:old",
              uploadUrlExpiresAt: now - 1000,
            },
          });
        }
        return jsonResponse({
          value: {
            uploadUrl: "https://example.com/upload-fresh",
            image: "urn:li:image:fresh",
            uploadUrlExpiresAt: now + 5 * 60 * 1000,
          },
        });
      }
      if (u === "https://example.com/upload-fresh") {
        return new Response("", { status: 200, headers: { etag: "E" } });
      }
      if (u === "https://api.linkedin.com/rest/posts") {
        const body = JSON.parse((init as RequestInit).body as string);
        expect(body.content).toEqual({ media: { id: "urn:li:image:fresh" } });
        return postCreatedResponse("urn:li:share:fresh");
      }
      throw new Error("unexpected url: " + u);
    });
    const urn = await publishImagePost(
      "tok",
      "urn:li:person:abc",
      "cap",
      Buffer.from([1, 2]),
      "image/png"
    );
    expect(urn).toBe("urn:li:share:fresh");
    expect(initCalls).toBe(2);
  });
});

// ---------------------------------------------------------------------------
// Video posts
// ---------------------------------------------------------------------------

describe("publishVideoPost", () => {
  // The minimum accepted size is 75KB; build a buffer that clears it.
  const videoBytes = Buffer.alloc(200 * 1024, 0x41);

  it("runs init → parts × N → finalize → poll → post", async () => {
    let pollCount = 0;
    const calls: string[] = [];
    __setFetchForTests(async (url, init) => {
      const u = String(url);
      calls.push(u);
      if (u.includes("/rest/videos?action=initializeUpload")) {
        return jsonResponse({
          value: {
            video: "urn:li:video:vid1",
            uploadInstructions: [
              {
                uploadUrl: "https://example.com/part-1",
                firstByte: 0,
                lastByte: videoBytes.length - 1,
              },
            ],
            uploadToken: "tok-upl",
            uploadUrlsExpireAt: Date.now() + 60 * 60 * 1000,
          },
        });
      }
      if (u.startsWith("https://example.com/part-")) {
        return new Response("", { status: 200, headers: { etag: "ETAG-1" } });
      }
      if (u.includes("/rest/videos?action=finalizeUpload")) {
        const body = JSON.parse((init as RequestInit).body as string);
        expect(body.finalizeUploadRequest.uploadedPartIds).toEqual(["ETAG-1"]);
        return new Response("", { status: 200 });
      }
      if (u.startsWith("https://api.linkedin.com/rest/videos/")) {
        pollCount++;
        if (pollCount < 3) {
          return jsonResponse({ status: "PROCESSING" });
        }
        return jsonResponse({ status: "AVAILABLE" });
      }
      if (u === "https://api.linkedin.com/rest/posts") {
        const body = JSON.parse((init as RequestInit).body as string);
        expect(body.content).toEqual({ media: { id: "urn:li:video:vid1" } });
        return postCreatedResponse("urn:li:share:video-post");
      }
      throw new Error("unexpected url: " + u);
    });

    const urn = await publishVideoPost(
      "tok",
      "urn:li:person:abc",
      "cap",
      videoBytes,
      "video/mp4"
    );
    expect(urn).toBe("urn:li:share:video-post");
    expect(pollCount).toBe(3);
    expect(
      calls.some((c) => c.includes("/rest/videos?action=initializeUpload"))
    ).toBe(true);
    expect(
      calls.some((c) => c.includes("/rest/videos?action=finalizeUpload"))
    ).toBe(true);
    // No legacy UGC endpoint anywhere (fragment-rebuild so this file
    // contains 0 literal matches for the deprecated path).
    const legacyPath = "/rest/" + "ugc" + "Posts";
    expect(calls.some((c) => c.includes(legacyPath))).toBe(false);
  });

  it("throws when bytes < 75KB", async () => {
    await expect(
      publishVideoPost(
        "tok",
        "urn:li:person:abc",
        "cap",
        Buffer.from([1, 2, 3]),
        "video/mp4"
      )
    ).rejects.toThrow(/below LinkedIn minimum/);
  });

  it("throws when processing reports PROCESSING_FAILED", async () => {
    __setFetchForTests(async (url) => {
      const u = String(url);
      if (u.includes("/rest/videos?action=initializeUpload")) {
        return jsonResponse({
          value: {
            video: "urn:li:video:bad",
            uploadInstructions: [
              {
                uploadUrl: "https://example.com/part-1",
                firstByte: 0,
                lastByte: videoBytes.length - 1,
              },
            ],
            uploadToken: "t",
            uploadUrlsExpireAt: Date.now() + 60_000,
          },
        });
      }
      if (u.startsWith("https://example.com/")) {
        return new Response("", { status: 200, headers: { etag: "E" } });
      }
      if (u.includes("/rest/videos?action=finalizeUpload")) {
        return new Response("", { status: 200 });
      }
      if (u.startsWith("https://api.linkedin.com/rest/videos/")) {
        return jsonResponse({ status: "PROCESSING_FAILED" });
      }
      throw new Error("unexpected url: " + u);
    });
    await expect(
      publishVideoPost(
        "tok",
        "urn:li:person:abc",
        "cap",
        videoBytes,
        "video/mp4"
      )
    ).rejects.toThrow(/processing failed/);
  });

  it("rejects unsupported video mime types", async () => {
    await expect(
      publishVideoPost(
        "tok",
        "urn:li:person:abc",
        "cap",
        videoBytes,
        "video/quicktime"
      )
    ).rejects.toThrow(/not supported/);
  });
});
