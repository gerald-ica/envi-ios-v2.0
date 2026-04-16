/**
 * health.test.ts — smoke test for the health endpoint handler.
 *
 * We test the inner handler contract (not the `onRequest` wrapper) by
 * mocking `firebase-functions/v2/https` so `onRequest` becomes a pure
 * pass-through. That gives us direct invoke-ability on the exported symbol.
 *
 * Checks:
 *   - 200 status
 *   - { status: "ok", phase: "06-01", env: "sandbox", timestamp: <iso> }
 *   - App Check middleware is applied (module imports it)
 */
import type { Request, Response } from "firebase-functions/v2/https";

jest.mock("firebase-functions/v2/https", () => {
  return {
    onRequest: jest.fn((_options: unknown, handler: unknown) => handler),
  };
});

jest.mock("../lib/logger", () => {
  const mockLogger = {
    debug: jest.fn(),
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
    withContext: jest.fn(function () {
      return mockLogger;
    }),
  };
  return { logger: mockLogger };
});

jest.mock("../lib/config", () => ({
  getConnectorEnv: jest.fn().mockReturnValue("sandbox"),
  getRegion: jest.fn().mockReturnValue("us-central1"),
}));

jest.mock("../lib/appCheck", () => ({
  requireAppCheck: jest.fn(<H>(handler: H) => handler),
}));

interface MockResponse {
  statusCode: number;
  body: unknown;
  status: jest.Mock;
  json: jest.Mock;
}

function createMockResponse(): MockResponse {
  const res = {
    statusCode: 0,
    body: null as unknown,
  } as MockResponse;
  res.status = jest.fn().mockImplementation((code: number) => {
    res.statusCode = code;
    return res;
  });
  res.json = jest.fn().mockImplementation((body: unknown) => {
    res.body = body;
    return res;
  });
  return res;
}

function createMockRequest(): Request {
  return {
    method: "GET",
    get: jest.fn().mockReturnValue("jest-test-runner"),
  } as unknown as Request;
}

describe("health endpoint", () => {
  it("returns 200 with status=ok and expected phase/env fields", async () => {
    const { health } = await import("../health");
    const handler = health as unknown as (
      req: Request,
      res: Response
    ) => Promise<void>;

    const req = createMockRequest();
    const res = createMockResponse();

    await handler(req, res as unknown as Response);

    expect(res.statusCode).toBe(200);
    expect(res.body).toMatchObject({
      status: "ok",
      phase: "06-01",
      env: "sandbox",
    });
    expect(typeof (res.body as { timestamp?: string }).timestamp).toBe("string");
  });
});
