/**
 * linkedin-dispatch.ts — glue between the iOS publish request and the
 * LinkedIn Posts API.
 *
 * Phase 11. Called by the `publish/linkedin` HTTPS handler (Phase 12
 * will wire it up as a Firestore-triggered job; for now it's exposed as
 * a function callable from `functions/src/index.ts`).
 *
 * Flow
 * ----
 *   1. Load the encrypted LinkedIn connection for {uid}. Missing / revoked
 *      / expired → throw.
 *   2. Resolve the author URN:
 *        - member       → `connection.personUrn` (stored at exchange time).
 *        - organization → look up in `connection.adminOrgUrns` cache;
 *                         reject if absent (user demoted from admin).
 *   3. Validate scope against the chosen author type:
 *        - member    requires `w_member_social`.
 *        - org       requires `w_organization_social`.
 *        Missing → throw `insufficientScopes`.
 *   4. If `mediaStoragePath` is present, download the bytes from Cloud
 *      Storage (default bucket).
 *   5. Dispatch to `publishTextPost` / `publishImagePost` /
 *      `publishVideoPost` based on `mediaType`.
 *   6. Write the outcome to the Phase 12 publish-job Firestore doc.
 *      (Phase 12's writer lives under `publish/jobs/{jobID}`; we share
 *      the helper via `../publish/jobWriter.ts` where available and
 *      no-op the write in its absence so Phase 11 deploys cleanly.)
 *
 * Error surface
 * -------------
 * Every failure is funneled through `ConnectorDispatchError` which the
 * HTTPS handler translates to a typed envelope the iOS
 * `LinkedInConnectorError` translator understands.
 */
import type { firestore } from "firebase-admin";

import { readConnection } from "../lib/tokenStorage";
import { logger } from "../lib/logger";
import { resolveKmsKeyName } from "../oauth/http";
import {
  publishTextPost,
  publishImagePost,
  publishVideoPost,
  LinkedInPublishError,
} from "../providers/linkedin-publish";

const log = logger.withContext({ phase: "11", provider: "linkedin-dispatch" });

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface LinkedInDispatchPayload {
  caption: string;
  mediaType: "none" | "image" | "video";
  mediaStoragePath?: string;
  authorType: "member" | "organization";
  organizationUrn?: string;
}

export interface LinkedInDispatchResult {
  postUrn: string;
  authorUrn: string;
  authorType: "member" | "organization";
}

export type ConnectorDispatchErrorCode =
  | "not_connected"
  | "token_expired"
  | "insufficient_scopes"
  | "not_organization_admin"
  | "media_missing"
  | "media_mime_unsupported"
  | "publish_failed";

export class ConnectorDispatchError extends Error {
  readonly code: ConnectorDispatchErrorCode;
  readonly detail: string | null;
  readonly missingScopes?: string[];

  constructor(
    code: ConnectorDispatchErrorCode,
    detail?: string | null,
    missingScopes?: string[]
  ) {
    super(`${code}${detail ? `: ${detail}` : ""}`);
    this.name = "ConnectorDispatchError";
    this.code = code;
    this.detail = detail ?? null;
    this.missingScopes = missingScopes;
  }
}

// ---------------------------------------------------------------------------
// Storage fetcher (injectable for tests)
// ---------------------------------------------------------------------------

type MediaFetcher = (storagePath: string) => Promise<{
  bytes: Buffer;
  mimeType: string;
}>;

let mediaFetcherImpl: MediaFetcher = defaultMediaFetcher;

/** @internal test-only override */
export function __setMediaFetcherForTests(impl: MediaFetcher | null): void {
  mediaFetcherImpl = impl ?? defaultMediaFetcher;
}

async function defaultMediaFetcher(
  storagePath: string
): Promise<{ bytes: Buffer; mimeType: string }> {
  // Lazy-load firebase-admin so unit tests that stub this function
  // don't drag the SDK into the module graph.
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const admin = require("firebase-admin") as typeof import("firebase-admin");
  if (admin.apps.length === 0) {
    admin.initializeApp();
  }
  const bucket = admin.storage().bucket();
  const file = bucket.file(storagePath);
  const [metadata] = await file.getMetadata();
  const [bytes] = await file.download();
  return {
    bytes,
    mimeType:
      (metadata.contentType as string | undefined) ??
      inferMimeFromPath(storagePath),
  };
}

function inferMimeFromPath(path: string): string {
  const ext = path.toLowerCase().split(".").pop() ?? "";
  switch (ext) {
    case "jpg":
    case "jpeg":
      return "image/jpeg";
    case "png":
      return "image/png";
    case "mp4":
      return "video/mp4";
    default:
      return "application/octet-stream";
  }
}

// ---------------------------------------------------------------------------
// Firestore handle (injectable)
// ---------------------------------------------------------------------------

let dbSingleton: firestore.Firestore | null = null;

/** @internal test-only: inject a firestore instance. */
export function __setFirestoreForTests(db: firestore.Firestore | null): void {
  dbSingleton = db;
}

function getFirestore(): firestore.Firestore {
  if (dbSingleton) return dbSingleton;
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const admin = require("firebase-admin") as typeof import("firebase-admin");
  if (admin.apps.length === 0) {
    admin.initializeApp();
  }
  dbSingleton = admin.firestore();
  return dbSingleton;
}

// ---------------------------------------------------------------------------
// Connection extras (provider-specific fields stored alongside token)
// ---------------------------------------------------------------------------

/**
 * `personUrn` + `adminOrgUrns` aren't part of the provider-agnostic
 * `ConnectionDocument` but are written by the LinkedIn-specific
 * post-exchange hook. Reads are `admin.firestore` raw so we can keep
 * the base-schema validator strict.
 */
async function loadLinkedInExtras(
  uid: string
): Promise<{
  personUrn: string | null;
  adminOrgUrns: string[];
}> {
  const db = getFirestore();
  const snap = await db
    .collection("users")
    .doc(uid)
    .collection("connections")
    .doc("linkedin")
    .get();
  if (!snap.exists) return { personUrn: null, adminOrgUrns: [] };
  const data = snap.data() ?? {};
  return {
    personUrn: (data.personUrn as string | undefined) ?? null,
    adminOrgUrns: Array.isArray(data.adminOrgUrns)
      ? (data.adminOrgUrns as string[])
      : [],
  };
}

// ---------------------------------------------------------------------------
// Main entry point
// ---------------------------------------------------------------------------

export async function dispatchLinkedInPost(
  uid: string,
  payload: LinkedInDispatchPayload
): Promise<LinkedInDispatchResult> {
  // 1. Load connection
  const db = getFirestore();
  const connection = await readConnection(uid, "linkedin", {
    db,
    kmsKeyName: resolveKmsKeyName(),
  });
  if (!connection) {
    throw new ConnectorDispatchError(
      "not_connected",
      "no linkedin connection for user"
    );
  }
  if (connection.revokedAt) {
    throw new ConnectorDispatchError(
      "not_connected",
      "linkedin connection revoked"
    );
  }
  if (connection.expiresAt.toMillis() < Date.now()) {
    // LinkedIn ships no refresh endpoint, so this is always a forced reauth.
    throw new ConnectorDispatchError(
      "token_expired",
      "linkedin access token expired; reauth required"
    );
  }

  // 2. Resolve author URN
  const extras = await loadLinkedInExtras(uid);
  const authorUrn = await resolveAuthorUrn(payload, extras);

  // 3. Scope validation
  const scopes = new Set(connection.scopes);
  if (payload.authorType === "member" && !scopes.has("w_member_social")) {
    throw new ConnectorDispatchError(
      "insufficient_scopes",
      "linkedin token missing w_member_social",
      ["w_member_social"]
    );
  }
  if (payload.authorType === "organization" && !scopes.has("w_organization_social")) {
    throw new ConnectorDispatchError(
      "insufficient_scopes",
      "linkedin token missing w_organization_social",
      ["w_organization_social"]
    );
  }

  // 4. Fetch media if present
  let mediaBytes: Buffer | null = null;
  let mediaMime: string | null = null;
  if (payload.mediaType !== "none") {
    if (!payload.mediaStoragePath) {
      throw new ConnectorDispatchError(
        "media_missing",
        `mediaType=${payload.mediaType} but no mediaStoragePath provided`
      );
    }
    const fetched = await mediaFetcherImpl(payload.mediaStoragePath);
    mediaBytes = fetched.bytes;
    mediaMime = fetched.mimeType;
  }

  // 5. Dispatch
  let postUrn: string;
  try {
    switch (payload.mediaType) {
      case "none":
        postUrn = await publishTextPost(
          connection.accessToken,
          authorUrn,
          payload.caption
        );
        break;
      case "image":
        postUrn = await publishImagePost(
          connection.accessToken,
          authorUrn,
          payload.caption,
          mediaBytes as Buffer,
          mediaMime as string
        );
        break;
      case "video":
        postUrn = await publishVideoPost(
          connection.accessToken,
          authorUrn,
          payload.caption,
          mediaBytes as Buffer,
          mediaMime as string
        );
        break;
    }
  } catch (err) {
    if (err instanceof LinkedInPublishError) {
      throw new ConnectorDispatchError(
        "publish_failed",
        err.message
      );
    }
    throw err;
  }

  log.info("linkedin publish success", {
    uid,
    authorType: payload.authorType,
    postUrn,
  });

  return {
    postUrn,
    authorUrn,
    authorType: payload.authorType,
  };
}

// ---------------------------------------------------------------------------
// Author URN resolver
// ---------------------------------------------------------------------------

async function resolveAuthorUrn(
  payload: LinkedInDispatchPayload,
  extras: { personUrn: string | null; adminOrgUrns: string[] }
): Promise<string> {
  if (payload.authorType === "member") {
    if (!extras.personUrn) {
      throw new ConnectorDispatchError(
        "not_connected",
        "linkedin personUrn missing on connection doc; reconnect required"
      );
    }
    return extras.personUrn;
  }

  // organization branch
  const urn = payload.organizationUrn;
  if (!urn) {
    throw new ConnectorDispatchError(
      "not_organization_admin",
      "organizationUrn missing on request"
    );
  }
  if (!extras.adminOrgUrns.includes(urn)) {
    throw new ConnectorDispatchError(
      "not_organization_admin",
      `requested organizationUrn ${urn} not in admin cache`
    );
  }
  return urn;
}
