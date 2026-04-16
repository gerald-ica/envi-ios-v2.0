/**
 * metaRoutes.ts — Meta-specific HTTP routes beyond the standard OAuth
 * broker surface.
 *
 * Phase 10. Exposes three endpoints that don't fit the provider-agnostic
 * broker contract:
 *
 *   GET  /meta/pages
 *     Fetch the authenticated user's Facebook Pages. Used by iOS
 *     `PageSelectorView` immediately after the FB OAuth flow resolves.
 *     Pulls the user access token from Firestore, hits `GET /me/accounts`,
 *     and returns a trimmed `MetaPage[]` shape. Per-Page tokens are
 *     encrypted and persisted server-side under
 *     `users/{uid}/connections/facebook/pages/{pageId}`.
 *
 *   POST /meta/ig-account-type
 *     Detect whether the connected IG account is Business / Creator /
 *     Personal. iOS blocks publish UI when the account is Personal or
 *     lacks a linked Page.
 *
 *   POST /oauth/facebook/select-page
 *     Finalize FB OAuth by storing the user's chosen Page id on the
 *     connection doc. The broker uses this `selectedPageId` to look up
 *     the Page access token at publish time.
 *
 * Auth
 * ----
 * All routes require a Firebase ID token + App Check. Same request
 * plumbing as the standard OAuth broker — reuse `requireFirebaseUid` +
 * `requireAppCheck`.
 */
import { onRequest, type Request, type Response } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

import { requireAppCheck } from "../lib/appCheck";
import { getRegion } from "../lib/config";
import { logger } from "../lib/logger";
import { readConnection } from "../lib/tokenStorage";
import { requireFirebaseUid } from "./auth";
import { OAuthBrokerError, OAuthBrokerErrorCode } from "./errors";
import {
  getFirestore,
  handleBrokerError,
  resolveKmsKeyName,
} from "./http";
import {
  metaFacebookAdapter,
  metaInstagramAdapter,
  type MetaPage,
} from "../providers/meta";

const log = logger.withContext({ phase: "10", route: "metaRoutes" });

// ---------------------------------------------------------------------------
// GET /meta/pages
// ---------------------------------------------------------------------------

/**
 * List the authenticated user's Facebook Pages.
 *
 * Response:
 *   { pages: MetaPage[] }
 *
 * iOS consumes via `PageSelectorViewModel.loadPages()`.
 */
export const metaPages = onRequest(
  { region: getRegion() },
  requireAppCheck(async (req: Request, res: Response) => {
    try {
      if (req.method !== "GET") {
        res.status(405).json({ error: "method_not_allowed" });
        return;
      }

      const uid = await requireFirebaseUid(req);
      const db = getFirestore();
      const kmsKeyName = resolveKmsKeyName();

      const connection = await readConnection(uid, "facebook", {
        db,
        kmsKeyName,
      });
      if (!connection) {
        throw new OAuthBrokerError(
          OAuthBrokerErrorCode.PROVIDER_NOT_REGISTERED,
          "no facebook connection for uid"
        );
      }

      const pages = await metaFacebookAdapter.getPages(connection.accessToken);

      // Persist per-Page access tokens encrypted. We don't reuse
      // `tokenStorage.writeConnection` because the schema differs — Pages
      // live under the connection as a sub-collection.
      await persistPageTokens(db, uid, pages);

      // Strip the access tokens from the response — iOS only needs the
      // metadata for display. Tokens stay server-side.
      const sanitized = pages.map((p) => ({
        page_id: p.pageId,
        page_name: p.pageName,
        category: p.category,
        tasks: p.tasks,
      }));

      res.status(200).json({ pages: sanitized });
    } catch (err) {
      handleBrokerError(res, err);
    }
  })
);

/**
 * Encrypt + persist per-Page access tokens under
 * `users/{uid}/connections/facebook/pages/{pageId}`. Uses the same KMS
 * envelope as the top-level connection doc.
 */
async function persistPageTokens(
  db: FirebaseFirestore.Firestore,
  uid: string,
  pages: MetaPage[]
): Promise<void> {
  if (pages.length === 0) return;

  const { encryptTokenPair } = await import("../lib/kmsEncryption");
  const kmsKeyName = resolveKmsKeyName();
  const now = admin.firestore.Timestamp.now();

  const pagesRef = db
    .collection("users")
    .doc(uid)
    .collection("connections")
    .doc("facebook")
    .collection("pages");

  const batch = db.batch();
  for (const page of pages) {
    const encrypted = await encryptTokenPair(page.pageAccessToken, null, kmsKeyName);
    batch.set(pagesRef.doc(page.pageId), {
      pageId: page.pageId,
      pageName: page.pageName,
      category: page.category,
      tasks: page.tasks,
      accessTokenCiphertext: encrypted.accessTokenCiphertext,
      dekCiphertext: encrypted.dekCiphertext,
      storedAt: now,
    });
  }
  await batch.commit();
}

// ---------------------------------------------------------------------------
// POST /meta/ig-account-type
// ---------------------------------------------------------------------------

/**
 * Detect whether the user's connected IG account can publish. Requires
 * the IG user id, which the broker derives from the linked FB Page's
 * `instagram_business_account` field. If the user has no IG account
 * linked to any Page, the endpoint returns `UNKNOWN`.
 */
export const metaIGAccountType = onRequest(
  { region: getRegion() },
  requireAppCheck(async (req: Request, res: Response) => {
    try {
      if (req.method !== "POST") {
        res.status(405).json({ error: "method_not_allowed" });
        return;
      }

      const uid = await requireFirebaseUid(req);
      const db = getFirestore();
      const kmsKeyName = resolveKmsKeyName();

      const connection = await readConnection(uid, "instagram", {
        db,
        kmsKeyName,
      });
      if (!connection) {
        res.status(200).json({
          account_type: "UNKNOWN",
          username: null,
          media_count: null,
        });
        return;
      }

      // The IG user id + Page access token live on the `facebook`
      // connection's pages subcollection (populated by /meta/pages).
      const igResolution = await resolveIGPublishingContext(db, uid);
      if (!igResolution) {
        res.status(200).json({
          account_type: "UNKNOWN",
          username: null,
          media_count: null,
        });
        return;
      }

      const result = await metaInstagramAdapter.detectIGAccountType(
        igResolution.igUserId,
        igResolution.pageAccessToken
      );

      res.status(200).json({
        account_type: result.accountType,
        username: result.username,
        media_count: result.mediaCount,
      });
    } catch (err) {
      handleBrokerError(res, err);
    }
  })
);

/**
 * Resolve the IG user id + Page access token for publishing. Reads the
 * user's chosen Page (`selectedPageId`) and returns the pre-populated
 * `instagram_business_account` id. Returns `null` if either piece is
 * missing — the caller handles that as `UNKNOWN`.
 */
async function resolveIGPublishingContext(
  db: FirebaseFirestore.Firestore,
  uid: string
): Promise<{ igUserId: string; pageAccessToken: string } | null> {
  const fbDoc = await db
    .collection("users")
    .doc(uid)
    .collection("connections")
    .doc("facebook")
    .get();
  const selectedPageId = fbDoc.data()?.selectedPageId as string | undefined;
  if (!selectedPageId) return null;

  const pageDoc = await db
    .collection("users")
    .doc(uid)
    .collection("connections")
    .doc("facebook")
    .collection("pages")
    .doc(selectedPageId)
    .get();
  const pageData = pageDoc.data();
  const igUserId = pageData?.instagramBusinessAccountId as string | undefined;
  if (!igUserId || !pageData?.accessTokenCiphertext || !pageData?.dekCiphertext) {
    return null;
  }

  const { decryptTokenPair } = await import("../lib/kmsEncryption");
  const decrypted = await decryptTokenPair(
    {
      accessTokenCiphertext: pageData.accessTokenCiphertext,
      refreshTokenCiphertext: null,
      dekCiphertext: pageData.dekCiphertext,
    },
    resolveKmsKeyName()
  );

  return {
    igUserId,
    pageAccessToken: decrypted.accessToken,
  };
}

// ---------------------------------------------------------------------------
// POST /oauth/facebook/select-page
// ---------------------------------------------------------------------------

/**
 * Persist the user's chosen Facebook Page id on the top-level connection
 * doc. Called by iOS immediately after the user picks a row in
 * `PageSelectorView`.
 */
export const metaSelectPage = onRequest(
  { region: getRegion() },
  requireAppCheck(async (req: Request, res: Response) => {
    try {
      if (req.method !== "POST") {
        res.status(405).json({ error: "method_not_allowed" });
        return;
      }

      const uid = await requireFirebaseUid(req);
      const db = getFirestore();

      const body = req.body as { page_id?: string };
      const pageId = body.page_id;
      if (typeof pageId !== "string" || pageId.trim() === "") {
        res.status(400).json({ error: "missing page_id" });
        return;
      }

      // Confirm the Page belongs to this user before marking it selected.
      const pageDoc = await db
        .collection("users")
        .doc(uid)
        .collection("connections")
        .doc("facebook")
        .collection("pages")
        .doc(pageId)
        .get();
      if (!pageDoc.exists) {
        res.status(404).json({ error: "page_not_found" });
        return;
      }

      await db
        .collection("users")
        .doc(uid)
        .collection("connections")
        .doc("facebook")
        .update({
          selectedPageId: pageId,
          selectedPageAt: admin.firestore.Timestamp.now(),
        });

      res.status(204).send();
    } catch (err) {
      handleBrokerError(res, err);
    }
  })
);
