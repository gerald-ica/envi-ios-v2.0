/**
 * scheduled.ts — onSchedule wrappers for the 6 nightly insight syncs,
 * plus the 3 orchestration CFs (`generateInsights`,
 * `trendSignalsGenerator`, `seedBenchmarks`).
 *
 * Schedule (UTC, staggered per PLAN.md)
 * -------------------------------------
 *   02:00  tiktok, instagram
 *   03:00  facebook, threads
 *   04:00  linkedin, x
 *   05:00  generateInsights (Pub/Sub fan-out)
 *   05:30  trendSignalsGenerator
 *
 * All jobs share one region (read from `getRegion()`) for cold-start
 * locality with the OAuth broker + publish workers.
 */
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onMessagePublished } from "firebase-functions/v2/pubsub";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { PubSub } from "@google-cloud/pubsub";

import { logger } from "../lib/logger";
import { getRegion } from "../lib/config";
import { TikTokInsightsSync } from "./tiktok";
import { InstagramInsightsSync } from "./instagram";
import { FacebookInsightsSync } from "./facebook";
import { ThreadsInsightsSync } from "./threads";
import { LinkedInInsightsSync } from "./linkedin";
import { XInsightsSync } from "./x";
import { runAllRules } from "./_shared/insightRules";
import {
  dateKeyUTC,
  isoWeekLabelUTC,
  type DailySnapshot,
  type GeneratedInsightsDoc,
  type TrendSignalsDoc,
} from "./_shared/snapshotSchema";

const log = logger.withContext({ phase: "13-01" });

const GENERATE_INSIGHTS_TOPIC = "envi-generate-insights";

// ---------------------------------------------------------------------------
// Scheduled per-provider syncs
// ---------------------------------------------------------------------------

export const scheduledInsightsSyncTikTok = onSchedule(
  { schedule: "0 2 * * *", timeZone: "UTC", region: getRegion() },
  async () => {
    await new TikTokInsightsSync().run();
    await publishGenerate(dateKeyUTC(new Date()));
  }
);

export const scheduledInsightsSyncInstagram = onSchedule(
  { schedule: "0 2 * * *", timeZone: "UTC", region: getRegion() },
  async () => {
    await new InstagramInsightsSync().run();
    await publishGenerate(dateKeyUTC(new Date()));
  }
);

export const scheduledInsightsSyncFacebook = onSchedule(
  { schedule: "0 3 * * *", timeZone: "UTC", region: getRegion() },
  async () => {
    await new FacebookInsightsSync().run();
  }
);

export const scheduledInsightsSyncThreads = onSchedule(
  { schedule: "0 3 * * *", timeZone: "UTC", region: getRegion() },
  async () => {
    await new ThreadsInsightsSync().run();
  }
);

export const scheduledInsightsSyncLinkedIn = onSchedule(
  { schedule: "0 4 * * *", timeZone: "UTC", region: getRegion() },
  async () => {
    await new LinkedInInsightsSync().run();
  }
);

export const scheduledInsightsSyncX = onSchedule(
  { schedule: "0 4 * * *", timeZone: "UTC", region: getRegion() },
  async () => {
    await new XInsightsSync().run();
  }
);

// ---------------------------------------------------------------------------
// generateInsights — Pub/Sub triggered per UID
// ---------------------------------------------------------------------------

interface GenerateInsightsMessage {
  uid: string;
  date: string;
}

export const generateInsights = onMessagePublished(
  {
    topic: GENERATE_INSIGHTS_TOPIC,
    region: getRegion(),
  },
  async (event) => {
    const raw = event.data.message.json as GenerateInsightsMessage | undefined;
    if (!raw?.uid || !raw?.date) {
      log.warn("generateInsights: malformed message", { raw });
      return;
    }
    await generateInsightsForUser(raw.uid, raw.date);
  }
);

async function generateInsightsForUser(uid: string, date: string): Promise<void> {
  const db = admin.firestore();
  // Pull the last 30 daily snapshots across all providers. Path matches
  // the canonical one set by `dailySnapshotPath` (schema).
  const providers = ["tiktok", "instagram", "facebook", "threads", "linkedin", "x"] as const;
  const snapshots: DailySnapshot[] = [];
  for (const provider of providers) {
    const dailyRef = db
      .collection("users").doc(uid)
      .collection("insights").doc(provider)
      .collection("daily");

    // Prefer a single ranged query over 30 per-date reads.
    const end = date;
    const startDate = new Date(Date.parse(`${date}T00:00:00Z`));
    startDate.setUTCDate(startDate.getUTCDate() - 29);
    const start = dateKeyUTC(startDate);

    const q = await dailyRef
      .where("date", ">=", start)
      .where("date", "<=", end)
      .get()
      .catch(() => null);

    if (q && !q.empty) {
      for (const d of q.docs) snapshots.push(d.data() as DailySnapshot);
    }
  }

  const generated = runAllRules({ snapshots, date }, 6);
  const doc: GeneratedInsightsDoc = {
    date,
    generatedAt: admin.firestore.Timestamp.now(),
    insights: generated,
  };
  await db.doc(`users/${uid}/generatedInsights/${date}`).set(doc);
  log.info("generated insights", { uid, date, count: generated.length });
}

async function publishGenerate(dateKey: string): Promise<void> {
  const db = admin.firestore();
  // Enumerate distinct uids with at least one connection. Small cost.
  const connections = await db
    .collectionGroup("connections")
    .where("revokedAt", "==", null)
    .get();
  const uids = new Set<string>();
  for (const d of connections.docs) {
    const uid = d.ref.parent.parent?.id;
    if (uid) uids.add(uid);
  }
  if (uids.size === 0) return;
  const pubsub = new PubSub();
  const topic = pubsub.topic(GENERATE_INSIGHTS_TOPIC);
  await Promise.allSettled(
    [...uids].map((uid) =>
      topic.publishMessage({ json: { uid, date: dateKey } as GenerateInsightsMessage })
    )
  );
}

// ---------------------------------------------------------------------------
// trendSignalsGenerator — nightly global trend roll-up
// ---------------------------------------------------------------------------

export const trendSignalsGenerator = onSchedule(
  { schedule: "30 5 * * *", timeZone: "UTC", region: getRegion() },
  async () => {
    const db = admin.firestore();
    const today = dateKeyUTC(new Date());

    // Minimal v1 implementation: aggregate this week's weekly-rollup
    // entries across all users and surface the top-5 providers by
    // average engagement rate. Replace with a dedicated signals pipeline
    // (v1.2 follow-up flagged in PLAN Open Questions §3).
    const rollups = await db
      .collectionGroup("entries")
      .where("weekLabel", "==", isoWeekLabelUTC(new Date()))
      .limit(500)
      .get();

    const byProvider = new Map<string, { momentum: number; samples: number }>();
    for (const d of rollups.docs) {
      const data = d.data() as { provider: string; avgEngagementRate: number; totalViews: number };
      const entry = byProvider.get(data.provider) ?? { momentum: 0, samples: 0 };
      entry.momentum += data.avgEngagementRate;
      entry.samples += 1;
      byProvider.set(data.provider, entry);
    }

    const signals: TrendSignalsDoc["signals"] = [...byProvider.entries()].map(
      ([provider, stats]) => ({
        topic: `${provider} creators`,
        momentum: Math.round((stats.momentum / Math.max(stats.samples, 1)) * 10) / 10,
        direction: "stable" as const,
        platforms: [provider as TrendSignalsDoc["signals"][number]["platforms"][number]],
        timeframe: "past 7 days",
      })
    );

    const doc: TrendSignalsDoc = {
      date: today,
      generatedAt: admin.firestore.Timestamp.now(),
      signals,
    };
    await db.doc(`trendSignals/${today}`).set(doc);
    log.info("trendSignals written", { date: today, signals: signals.length });
  }
);

// ---------------------------------------------------------------------------
// seedBenchmarks — one-time callable (admin-only) to populate globals
// ---------------------------------------------------------------------------

export const seedBenchmarks = onCall(
  { region: getRegion() },
  async (req) => {
    // Admin-only: guard against unauthenticated + non-admin callers.
    if (!req.auth) {
      throw new HttpsError("unauthenticated", "sign in required");
    }
    const token = req.auth.token as { admin?: boolean };
    if (!token.admin) {
      throw new HttpsError("permission-denied", "admin only");
    }

    const db = admin.firestore();
    const categories = [
      "fashion", "beauty", "fitness", "food", "travel", "tech",
      "lifestyle", "education", "entertainment", "business",
    ] as const;
    const metrics = [
      { metric: "engagement_rate", industryAvg: 3.1, topPerformerThreshold: 7.8 },
      { metric: "follower_growth", industryAvg: 1.5, topPerformerThreshold: 6.2 },
      { metric: "avg_reach", industryAvg: 8_900, topPerformerThreshold: 34_000 },
      { metric: "save_rate", industryAvg: 1.2, topPerformerThreshold: 4.5 },
      { metric: "share_rate", industryAvg: 0.6, topPerformerThreshold: 2.1 },
    ];

    const batch = db.batch();
    for (const category of categories) {
      for (const m of metrics) {
        const ref = db.doc(`benchmarks/${category}/${m.metric}/current`);
        batch.set(ref, {
          category,
          metric: m.metric,
          industryAvg: m.industryAvg,
          topPerformerThreshold: m.topPerformerThreshold,
          sampleSize: 0,
          lastUpdated: admin.firestore.Timestamp.now(),
        });
      }
    }
    await batch.commit();
    return { ok: true, categories: categories.length, metrics: metrics.length };
  }
);
