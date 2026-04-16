/**
 * Health endpoint — exercises the deploy pipeline end-to-end.
 *
 * Phase 06-01: publicly reachable, returns `{ status, phase, env }`.
 * Phase 06-07: wrapped in `requireAppCheck` so only clients that can mint a
 *              valid App Check token are allowed through. This is intentional
 *              even for a health check — it verifies App Check is wired into
 *              the deploy path.
 *
 * URL (after deploy): https://us-central1-<project>.cloudfunctions.net/health
 */
import { onRequest } from "firebase-functions/v2/https";

import { requireAppCheck } from "./lib/appCheck";
import { getConnectorEnv, getRegion } from "./lib/config";
import { logger } from "./lib/logger";

const log = logger.withContext({ phase: "06-01" });

export const health = onRequest(
  { region: getRegion(), cors: false },
  requireAppCheck(async (req, res) => {
    log.info("health check hit", {
      method: req.method,
      userAgent: req.get("user-agent") ?? null,
    });

    res.status(200).json({
      status: "ok",
      phase: "06-01",
      env: getConnectorEnv(),
      timestamp: new Date().toISOString(),
    });
  })
);
