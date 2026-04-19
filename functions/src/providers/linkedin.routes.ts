/**
 * linkedin.routes.ts — LinkedIn-specific HTTPS handlers.
 *
 * Phase 11. Two routes sit outside the provider-agnostic OAuth broker:
 *
 *   GET  /connectors/linkedin/organizations  — admin-org list for the
 *                                              iOS author picker.
 *   POST /publish/linkedin                   — dispatch a single post
 *                                              (text / image / video)
 *                                              through the Posts API.
 *
 * Both routes are App Check-gated and identify the user via the Firebase
 * ID token. Business logic lives in `./linkedin.ts` (org fetch) and
 * `../publish/linkedin-dispatch.ts` (publish orchestration); this module
 * is a thin HTTP shim.
 */
import {
  onRequest,
  type Request,
} from "firebase-functions/v2/https";
import type { Response } from "express";

import { requireAppCheck } from "../lib/appCheck";
import { getRegion } from "../lib/config";
import { logger } from "../lib/logger";
import { readConnection } from "../lib/tokenStorage";
import { requireFirebaseUid } from "../oauth/auth";
import { OAuthBrokerError, OAuthBrokerErrorCode } from "../oauth/errors";
import {
  getFirestore,
  handleBrokerError,
  resolveKmsKeyName,
} from "../oauth/http";

import { fetchAdminOrganizations } from "./linkedin";
import {
  ConnectorDispatchError,
  dispatchLinkedInPost,
  type LinkedInDispatchPayload,
} from "../publish/linkedin-dispatch";

const log = logger.withContext({ phase: "11", scope: "linkedin-routes" });

// ---------------------------------------------------------------------------
// /connectors/linkedin/organizations
// ---------------------------------------------------------------------------

async function handleOrganizations(
  req: Request,
  res: Response
): Promise<void> {
  if (req.method !== "GET") {
    res.status(405).json({ error: "method_not_allowed" });
    return;
  }
  try {
    const uid = await requireFirebaseUid(req);
    const accessToken = await loadAccessToken(uid);
    const organizations = await fetchAdminOrganizations(accessToken);
    res.status(200).json({ organizations });
  } catch (err) {
    handleBrokerError(res, err);
  }
}

export const connectorsLinkedInOrganizations = onRequest(
  { region: getRegion(), cors: false },
  requireAppCheck(handleOrganizations)
);

// ---------------------------------------------------------------------------
// /publish/linkedin
// ---------------------------------------------------------------------------

interface PublishLinkedInBody {
  caption?: string;
  mediaType?: "none" | "image" | "video";
  mediaStoragePath?: string;
  authorType?: "member" | "organization";
  organizationUrn?: string;
}

async function handlePublish(req: Request, res: Response): Promise<void> {
  if (req.method !== "POST") {
    res.status(405).json({ error: "method_not_allowed" });
    return;
  }
  try {
    const uid = await requireFirebaseUid(req);
    const body = (req.body ?? {}) as PublishLinkedInBody;

    const payload = validatePublishBody(body);
    const result = await dispatchLinkedInPost(uid, payload);

    // Shape matches the Phase 12 publish-job envelope so iOS's
    // `PublishingManager` can consume without branching.
    const jobID = result.postUrn; // Phase 12 will swap in a server-minted id.
    res.status(200).json({
      jobID,
      status: "posted",
      postUrn: result.postUrn,
      authorType: result.authorType,
      authorUrn: result.authorUrn,
    });
  } catch (err) {
    if (err instanceof ConnectorDispatchError) {
      // Map dispatch errors onto a code + detail envelope that iOS
      // translates in `LinkedInConnectorError.from(envelope:)`.
      const status = statusForDispatchCode(err.code);
      res.status(status).json({
        error: err.code,
        detail: err.detail,
        missingScopes: err.missingScopes,
      });
      return;
    }
    handleBrokerError(res, err);
  }
}

export const publishLinkedIn = onRequest(
  { region: getRegion(), cors: false, timeoutSeconds: 540 },
  requireAppCheck(handlePublish)
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function validatePublishBody(
  body: PublishLinkedInBody
): LinkedInDispatchPayload {
  if (typeof body.caption !== "string" || body.caption.length === 0) {
    throw new OAuthBrokerError(
      OAuthBrokerErrorCode.INTERNAL,
      "caption is required"
    );
  }
  if (
    body.mediaType !== "none" &&
    body.mediaType !== "image" &&
    body.mediaType !== "video"
  ) {
    throw new OAuthBrokerError(
      OAuthBrokerErrorCode.INTERNAL,
      "mediaType must be one of: none, image, video"
    );
  }
  if (
    body.authorType !== "member" &&
    body.authorType !== "organization"
  ) {
    throw new OAuthBrokerError(
      OAuthBrokerErrorCode.INTERNAL,
      "authorType must be member or organization"
    );
  }
  if (body.authorType === "organization" && !body.organizationUrn) {
    throw new OAuthBrokerError(
      OAuthBrokerErrorCode.INTERNAL,
      "organizationUrn required when authorType=organization"
    );
  }
  if (body.mediaType !== "none" && !body.mediaStoragePath) {
    throw new OAuthBrokerError(
      OAuthBrokerErrorCode.INTERNAL,
      "mediaStoragePath required when mediaType != none"
    );
  }
  return {
    caption: body.caption,
    mediaType: body.mediaType,
    mediaStoragePath: body.mediaStoragePath,
    authorType: body.authorType,
    organizationUrn: body.organizationUrn,
  };
}

function statusForDispatchCode(
  code: ConnectorDispatchError["code"]
): number {
  switch (code) {
    case "not_connected":
    case "token_expired":
      return 401;
    case "insufficient_scopes":
      return 403;
    case "not_organization_admin":
      return 403;
    case "media_missing":
    case "media_mime_unsupported":
      return 400;
    case "publish_failed":
      return 502;
    default:
      return 500;
  }
}

/**
 * Load the user's LinkedIn access token from Firestore. Raises
 * `CONNECTION_NOT_FOUND` when the user hasn't connected yet.
 */
async function loadAccessToken(uid: string): Promise<string> {
  const result = await readConnection(uid, "linkedin", {
    db: getFirestore(),
    kmsKeyName: resolveKmsKeyName(),
  });
  if (!result) {
    throw new OAuthBrokerError(
      OAuthBrokerErrorCode.CONNECTION_NOT_FOUND,
      "no linkedin connection for user"
    );
  }
  if (result.revokedAt) {
    throw new OAuthBrokerError(
      OAuthBrokerErrorCode.CONNECTION_NOT_FOUND,
      "linkedin connection is revoked"
    );
  }
  log.debug("linkedin token loaded", { uid });
  return result.accessToken;
}
