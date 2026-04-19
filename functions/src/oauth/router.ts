/**
 * router.ts — single `oauth` Cloud Function that dispatches
 * `/oauth/:provider/:action` URLs to the right handler.
 *
 * Why this exists:
 *   Cloud Functions v2 deploys one HTTP function per export, and the
 *   gateway routes `cloudfunctions.net/{functionName}/*` to that single
 *   function. The iOS client (and the provider console callback URLs)
 *   expect the path-style endpoint `/oauth/:provider/:action`, which
 *   would require a function literally named `oauth`. This file provides
 *   that catch-all and forwards to the pure handlers exported by each
 *   action file.
 *
 * Routing table (req.path after the `oauth` function prefix is stripped
 * by the gateway — e.g. a request to `…/oauth/instagram/start` arrives
 * here with `req.path = "/instagram/start"`):
 *
 *   POST /:provider/start       → handleStart       (App Check required)
 *   GET  /:provider/callback    → handleCallback    (App Check soft-fail)
 *   GET  /:provider/status      → handleStatus      (App Check required)
 *   POST /:provider/disconnect  → handleDisconnect  (App Check required)
 *   POST /:provider/refresh     → handleRefresh     (App Check required)
 */
import { onRequest, type Request } from "firebase-functions/v2/https";
import type { Response } from "express";

import { requireAppCheck } from "../lib/appCheck";
import { getRegion } from "../lib/config";
import { logger } from "../lib/logger";
import { handleCallback } from "./callback";
import { handleDisconnect } from "./disconnect";
import { OAuthBrokerError, OAuthBrokerErrorCode } from "./errors";
import { handleBrokerError } from "./http";
import { handleRefresh } from "./refresh";
import { handleStart } from "./start";
import { handleStatus } from "./status";

const log = logger.withContext({ phase: "07-router" });

type PureHandler = (req: Request, res: Response) => Promise<void> | void;

function parseAction(req: Request): { action: string; provider: string } {
  const segments = (req.path || "/")
    .split("/")
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
  // Tolerate both `/:provider/:action` and `/oauth/:provider/:action`
  // (if the gateway ever surfaces the function-name prefix).
  const stripped =
    segments[0]?.toLowerCase() === "oauth" ? segments.slice(1) : segments;
  return {
    provider: (stripped[0] || "").toLowerCase(),
    action: (stripped[1] || "").toLowerCase(),
  };
}

/**
 * Entry point. Selects the right action handler and App Check policy,
 * then delegates. Unknown actions produce a 404 via OAuthBrokerError.
 */
async function dispatch(req: Request, res: Response): Promise<void> {
  const { action, provider } = parseAction(req);

  // Per-action App Check policy (mirrors the individual oauthX exports).
  const softFail = action === "callback";

  let handler: PureHandler;
  switch (action) {
    case "start":
      handler = handleStart;
      break;
    case "callback":
      handler = handleCallback;
      break;
    case "status":
      handler = handleStatus;
      break;
    case "disconnect":
      handler = handleDisconnect;
      break;
    case "refresh":
      handler = handleRefresh;
      break;
    default:
      log.warn("oauth router: unknown action", { action, provider });
      return handleBrokerError(
        res,
        new OAuthBrokerError(
          OAuthBrokerErrorCode.PROVIDER_NOT_REGISTERED,
          `unknown oauth action: ${action || "(empty)"}`
        )
      );
  }

  // Wrap the selected handler with its App Check policy and invoke.
  const guarded = requireAppCheck(handler, { enforceSoftFail: softFail });
  return guarded(req, res);
}

export const oauth = onRequest({ region: getRegion(), cors: false }, dispatch);
