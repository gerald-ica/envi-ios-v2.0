/**
 * appCheck.test.ts — middleware behaviour under the 4 states it can be in:
 *   - missing token (401)
 *   - valid token (passes through)
 *   - invalid token (401)
 *   - debug bypass (passes through iff allowed)
 */
import type { Request } from "firebase-functions/v2/https";
import type { Response } from "express";

import {
  __setAppCheckVerifierForTests,
  requireAppCheck,
} from "../lib/appCheck";

function makeReq(header?: string): Request {
  const headers: Record<string, string> = {};
  if (header !== undefined) {
    headers["x-firebase-appcheck"] = header;
  }
  return {
    header: (name: string) => headers[name.toLowerCase()],
  } as unknown as Request;
}

function makeRes() {
  const res = {
    statusCode: 0,
    body: null as unknown,
    status: jest.fn().mockImplementation(function (this: typeof res, code: number) {
      this.statusCode = code;
      return this;
    }),
    json: jest.fn().mockImplementation(function (this: typeof res, body: unknown) {
      this.body = body;
      return this;
    }),
  };
  res.status = res.status.bind(res) as typeof res.status;
  res.json = res.json.bind(res) as typeof res.json;
  return res;
}

describe("requireAppCheck", () => {
  afterEach(() => {
    __setAppCheckVerifierForTests(null);
    delete process.env.APP_CHECK_ALLOW_DEBUG_TOKEN;
  });

  it("returns 401 when no App Check header is present", async () => {
    __setAppCheckVerifierForTests(async () => ({ appId: "never" }));
    const handler = jest.fn();
    const wrapped = requireAppCheck(handler);
    const res = makeRes();

    await wrapped(makeReq(), res as unknown as Response);

    expect(handler).not.toHaveBeenCalled();
    expect(res.statusCode).toBe(401);
    expect(res.body).toEqual({ error: "app_check_required" });
  });

  it("invokes the handler when App Check token is valid", async () => {
    __setAppCheckVerifierForTests(async () => ({ appId: "1:abc:ios:xyz" }));
    const handler = jest.fn(async (_req: Request, res: Response) => {
      (res as unknown as { status: (c: number) => typeof res }).status(200);
    });
    const wrapped = requireAppCheck(handler);
    const res = makeRes();

    await wrapped(makeReq("valid-token"), res as unknown as Response);

    expect(handler).toHaveBeenCalledTimes(1);
  });

  it("returns 401 when verifier throws", async () => {
    __setAppCheckVerifierForTests(async () => {
      throw new Error("expired");
    });
    const handler = jest.fn();
    const wrapped = requireAppCheck(handler);
    const res = makeRes();

    await wrapped(makeReq("some-junk"), res as unknown as Response);

    expect(handler).not.toHaveBeenCalled();
    expect(res.statusCode).toBe(401);
    expect(res.body).toEqual({ error: "app_check_invalid" });
  });

  it("honours APP_CHECK_ALLOW_DEBUG_TOKEN=true when header is 'debug'", async () => {
    process.env.APP_CHECK_ALLOW_DEBUG_TOKEN = "true";
    const verifier = jest.fn();
    __setAppCheckVerifierForTests(verifier);
    const handler = jest.fn();
    const wrapped = requireAppCheck(handler);
    const res = makeRes();

    await wrapped(makeReq("debug"), res as unknown as Response);

    expect(verifier).not.toHaveBeenCalled();
    expect(handler).toHaveBeenCalledTimes(1);
  });

  it("does NOT allow debug bypass when env flag is unset", async () => {
    __setAppCheckVerifierForTests(async () => {
      throw new Error("nope");
    });
    const handler = jest.fn();
    const wrapped = requireAppCheck(handler);
    const res = makeRes();

    await wrapped(makeReq("debug"), res as unknown as Response);

    expect(handler).not.toHaveBeenCalled();
    expect(res.statusCode).toBe(401);
  });

  it("passes through on soft-fail mode even when token is invalid", async () => {
    __setAppCheckVerifierForTests(async () => {
      throw new Error("bad");
    });
    const handler = jest.fn();
    const wrapped = requireAppCheck(handler, { enforceSoftFail: true });
    const res = makeRes();

    await wrapped(makeReq("bad-token"), res as unknown as Response);

    expect(handler).toHaveBeenCalledTimes(1);
  });
});
