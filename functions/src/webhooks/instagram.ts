/**
 * instagram.ts — Phase 12-05 Instagram webhook receiver.
 *
 * Meta's webhook subscription endpoints require both a verification handshake
 * (GET with `hub.mode=subscribe`) and a POST body matching
 * `entry[].changes[].field == "media"`.
 *
 * GET:
 *   /webhooks/instagram?hub.mode=subscribe
 *                     &hub.verify_token=<our-secret>
 *                     &hub.challenge=<echo-me>
 *   → 200 with body = hub.challenge if the verify_token matches the
 *     Secret Manager secret `meta-webhook-verify-token`.
 *
 * POST:
 *   X-Hub-Signature-256: sha256=<hmac>
 *   {
 *     object: "instagram",
 *     entry: [{ id, time, changes: [{ field, value }] }]
 *   }
 *   → reconcile per-platform publish status in Firestore.
 */
import { onRequest } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

import { logger } from "../lib/logger";
import { getSecret } from "../lib/secrets";
import { getRegion } from "../lib/config";

const log = logger.withContext({ phase: "12-05", webhook: "instagram" });
const VERIFY_TOKEN_SECRET = "meta-webhook-verify-token";

export const instagramWebhook = onRequest(
  { region: getRegion() },
  async (req, res) => {
    if (admin.apps.length === 0) admin.initializeApp();

    if (req.method === "GET") {
      const mode = req.query["hub.mode"];
      const token = req.query["hub.verify_token"];
      const challenge = req.query["hub.challenge"];
      const expected = await getSecret(VERIFY_TOKEN_SECRET);
      if (mode === "subscribe" && token === expected) {
        res.status(200).send(String(challenge ?? ""));
        return;
      }
      res.status(403).send("verify_token mismatch");
      return;
    }

    if (req.method !== "POST") {
      res.status(405).send("method_not_allowed");
      return;
    }

    const body = req.body as {
      object?: string;
      entry?: Array<{
        id?: string;
        changes?: Array<{
          field?: string;
          value?: { media_id?: string; status?: string };
        }>;
      }>;
    };

    if (body.object !== "instagram") {
      res.status(400).send("wrong_object");
      return;
    }

    await reconcile(body.entry ?? []);

    // Meta requires 200 quickly — parse + reconcile are fast but if we ever
    // hit slow Firestore writes we should push to a Pub/Sub topic here.
    res.status(200).send("ok");
  }
);

async function reconcile(
  entries: Array<{
    id?: string;
    changes?: Array<{
      field?: string;
      value?: { media_id?: string; status?: string };
    }>;
  }>
): Promise<void> {
  const db = admin.firestore();
  for (const entry of entries) {
    for (const change of entry.changes ?? []) {
      const mediaId = change.value?.media_id;
      const status = change.value?.status;
      if (!mediaId || !status) continue;

      // Match against providerPostId. In practice we'd also index by
      // `platforms.instagram.providerPostId`; a collection-group index is
      // declared in `firestore.indexes.json`.
      const snap = await db
        .collection("publish_jobs")
        .where("platforms.instagram.providerPostId", "==", mediaId)
        .limit(1)
        .get();
      if (snap.empty) continue;

      const ref = snap.docs[0].ref;
      const newStatus = status === "published" ? "posted" : "failed";
      await ref.update({
        [`platforms.instagram.status`]: newStatus,
        [`platforms.instagram.lastSyncAt`]: admin.firestore.FieldValue.serverTimestamp(),
      });
      await reDeriveTopLevelStatus(ref);
      log.info("instagram webhook reconciled", { mediaId, newStatus });
    }
  }
}

async function reDeriveTopLevelStatus(
  ref: FirebaseFirestore.DocumentReference
): Promise<void> {
  const db = admin.firestore();
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return;
    const data = snap.data() ?? {};
    const platforms = (data.platforms ?? {}) as Record<string, { status?: string }>;
    const statuses = Object.values(platforms).map((p) => p.status ?? "queued");
    let next = "queued";
    if (statuses.every((s) => s === "posted")) next = "posted";
    else if (statuses.every((s) => s === "failed" || s === "dlq")) next = "failed";
    else if (
      statuses.some((s) => s === "posted") &&
      statuses.every((s) => s === "posted" || s === "failed" || s === "dlq")
    ) next = "partial";
    else if (statuses.some((s) => s === "processing")) next = "processing";
    if (data.status !== next) tx.update(ref, { status: next });
  });
}
