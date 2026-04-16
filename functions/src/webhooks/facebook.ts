/**
 * facebook.ts — Phase 12-05 Facebook Page webhook receiver.
 *
 * Mirrors the Instagram receiver — Meta's webhook spec is shared between
 * the two products (Graph subscribe → GET challenge → POST entries).
 *
 * Subscription `object` key differs (`"page"`) and we match against
 * `platforms.facebook.providerPostId`.
 */
import { onRequest } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

import { logger } from "../lib/logger";
import { getSecret } from "../lib/secrets";
import { getRegion } from "../lib/config";

const log = logger.withContext({ phase: "12-05", webhook: "facebook" });
const VERIFY_TOKEN_SECRET = "meta-webhook-verify-token";

export const facebookWebhook = onRequest(
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
          value?: { post_id?: string; verb?: string };
        }>;
      }>;
    };
    if (body.object !== "page") {
      res.status(400).send("wrong_object");
      return;
    }

    await reconcile(body.entry ?? []);
    res.status(200).send("ok");
  }
);

async function reconcile(
  entries: Array<{
    id?: string;
    changes?: Array<{
      field?: string;
      value?: { post_id?: string; verb?: string };
    }>;
  }>
): Promise<void> {
  const db = admin.firestore();
  for (const entry of entries) {
    for (const change of entry.changes ?? []) {
      const postId = change.value?.post_id;
      const verb = change.value?.verb;  // add | remove | edit
      if (!postId) continue;

      const snap = await db
        .collection("publish_jobs")
        .where("platforms.facebook.providerPostId", "==", postId)
        .limit(1)
        .get();
      if (snap.empty) continue;

      const ref = snap.docs[0].ref;
      const newStatus = verb === "remove" ? "failed" : "posted";
      await ref.update({
        [`platforms.facebook.status`]: newStatus,
        [`platforms.facebook.lastSyncAt`]: admin.firestore.FieldValue.serverTimestamp(),
      });
      await reDeriveTopLevelStatus(ref);
      log.info("facebook webhook reconciled", { postId, newStatus, verb });
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
