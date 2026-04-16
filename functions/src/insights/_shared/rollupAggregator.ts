/**
 * rollupAggregator.ts — daily → weekly + monthly aggregation.
 *
 * Invoked two ways:
 *   1. Inline from `InsightsSyncBase.run()` after each successful daily
 *      write — keeps rollups eventually consistent within minutes of the
 *      daily sync.
 *   2. From a nightly CF (`generateWeeklyDigest`) on the ISO week boundary
 *      to force a final pass once all daily docs for the week have
 *      landed.
 *
 * Trade-offs
 * ----------
 * We re-read the full 7-/30-day window on every trigger. Cheap — each
 * snapshot is ~4KB and the window is bounded. Simpler than maintaining
 * running totals on the rollup doc (which would need transactional
 * updates to stay correct under concurrent writes).
 */
import type * as admin from "firebase-admin";
import type { SupportedProvider } from "../../lib/firestoreSchema";
import {
  dailySnapshotPath,
  weeklyRollupPath,
  monthlyRollupPath,
  isoWeekLabelUTC,
  monthKeyUTC,
  dateKeyUTC,
  worstQuality,
  type DailySnapshot,
  type DataQuality,
  type WeeklyRollup,
  type MonthlyRollup,
} from "./snapshotSchema";

/**
 * Recompute the weekly + monthly rollup for the week + month that
 * contain `triggerDateKey`. Idempotent — safe to call on every daily
 * write.
 */
export async function aggregateOnTriggerDates(
  db: admin.firestore.Firestore,
  uid: string,
  provider: SupportedProvider,
  triggerDateKey: string
): Promise<void> {
  const trigger = parseDateKey(triggerDateKey);
  await Promise.all([
    aggregateWeek(db, uid, provider, trigger),
    aggregateMonth(db, uid, provider, trigger),
  ]);
}

export async function aggregateWeek(
  db: admin.firestore.Firestore,
  uid: string,
  provider: SupportedProvider,
  anyDayInWeek: Date
): Promise<WeeklyRollup | null> {
  const { monday, sunday } = isoWeekRange(anyDayInWeek);
  const snapshots = await readRange(db, uid, provider, monday, sunday);
  if (snapshots.length === 0) return null;

  const totals = sumFields(snapshots);
  const followerGrowth = snapshots.reduce((acc, s) => acc + s.followersGain, 0);
  const topPost = pickTopPost(snapshots);
  const engagement =
    totals.likes +
    totals.comments +
    totals.shares +
    (totals.saves ?? 0);
  const avgEngagementRate = totals.views > 0 ? (engagement / totals.views) * 100 : 0;

  const rollup: WeeklyRollup = {
    provider,
    weekLabel: isoWeekLabelUTC(anyDayInWeek),
    startDate: dateKeyUTC(monday),
    endDate: dateKeyUTC(sunday),
    totalViews: totals.views,
    totalReach: totals.reach,
    totalLikes: totals.likes,
    totalComments: totals.comments,
    totalShares: totals.shares,
    totalSaves: totals.saves,
    totalLinkClicks: totals.linkClicks,
    avgEngagementRate: round2(avgEngagementRate),
    followerGrowth,
    topPostId: topPost,
    syncedAt: nowTs(db),
    dataQuality: worstOf(snapshots),
  };

  await db
    .doc(weeklyRollupPath(uid, provider, rollup.weekLabel))
    .set(rollup);
  return rollup;
}

export async function aggregateMonth(
  db: admin.firestore.Firestore,
  uid: string,
  provider: SupportedProvider,
  anyDayInMonth: Date
): Promise<MonthlyRollup | null> {
  const { first, last } = monthRange(anyDayInMonth);
  const snapshots = await readRange(db, uid, provider, first, last);
  if (snapshots.length === 0) return null;

  const totals = sumFields(snapshots);
  const followerGrowth = snapshots.reduce((acc, s) => acc + s.followersGain, 0);
  const engagement =
    totals.likes +
    totals.comments +
    totals.shares +
    (totals.saves ?? 0);
  const avgEngagementRate = totals.views > 0 ? (engagement / totals.views) * 100 : 0;

  // Use the most recent non-null demographics snapshot for the month —
  // providers return the same cumulative shape every day, so "latest
  // wins" matches their semantics better than averaging.
  const audienceSource = [...snapshots].reverse().find(
    (s) => s.audienceAge || s.audienceGender || s.audienceCountry
  );

  const rollup: MonthlyRollup = {
    provider,
    monthLabel: monthKeyUTC(anyDayInMonth),
    startDate: dateKeyUTC(first),
    endDate: dateKeyUTC(last),
    totalViews: totals.views,
    totalReach: totals.reach,
    totalLikes: totals.likes,
    totalComments: totals.comments,
    totalShares: totals.shares,
    totalSaves: totals.saves,
    totalLinkClicks: totals.linkClicks,
    avgEngagementRate: round2(avgEngagementRate),
    followerGrowth,
    bestPostId: pickTopPost(snapshots),
    audienceAge: audienceSource?.audienceAge ?? null,
    audienceGender: audienceSource?.audienceGender ?? null,
    audienceCountry: audienceSource?.audienceCountry ?? null,
    syncedAt: nowTs(db),
    dataQuality: worstOf(snapshots),
  };

  await db
    .doc(monthlyRollupPath(uid, provider, rollup.monthLabel))
    .set(rollup);
  return rollup;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

interface Totals {
  views: number;
  reach: number;
  likes: number;
  comments: number;
  shares: number;
  saves: number | null;
  linkClicks: number | null;
}

function sumFields(snapshots: DailySnapshot[]): Totals {
  const totals: Totals = {
    views: 0,
    reach: 0,
    likes: 0,
    comments: 0,
    shares: 0,
    saves: null,
    linkClicks: null,
  };
  for (const s of snapshots) {
    totals.views += s.views;
    totals.reach += s.reach;
    totals.likes += s.likes;
    totals.comments += s.comments;
    totals.shares += s.shares;
    if (s.saves !== null) totals.saves = (totals.saves ?? 0) + s.saves;
    if (s.linkClicks !== null) totals.linkClicks = (totals.linkClicks ?? 0) + s.linkClicks;
  }
  return totals;
}

function pickTopPost(snapshots: DailySnapshot[]): string | null {
  let bestId: string | null = null;
  let bestViews = -1;
  for (const s of snapshots) {
    for (const p of s.posts) {
      if (p.views > bestViews) {
        bestViews = p.views;
        bestId = p.postId;
      }
    }
  }
  return bestId;
}

function worstOf(snapshots: DailySnapshot[]): DataQuality {
  return snapshots.reduce<DataQuality>(
    (acc, s) => worstQuality(acc, s.dataQuality),
    "full"
  );
}

async function readRange(
  db: admin.firestore.Firestore,
  uid: string,
  provider: SupportedProvider,
  start: Date,
  end: Date
): Promise<DailySnapshot[]> {
  const startKey = dateKeyUTC(start);
  const endKey = dateKeyUTC(end);
  const out: DailySnapshot[] = [];
  for (let cursor = new Date(start); cursor <= end; cursor = addDaysUTC(cursor, 1)) {
    const key = dateKeyUTC(cursor);
    if (key < startKey || key > endKey) continue;
    const snap = await db.doc(dailySnapshotPath(uid, provider, key)).get();
    if (snap.exists) out.push(snap.data() as DailySnapshot);
  }
  return out;
}

function isoWeekRange(d: Date): { monday: Date; sunday: Date } {
  const day = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  const dayNum = day.getUTCDay() || 7;
  const monday = addDaysUTC(day, 1 - dayNum);
  const sunday = addDaysUTC(monday, 6);
  return { monday, sunday };
}

function monthRange(d: Date): { first: Date; last: Date } {
  const first = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), 1));
  const last = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 0));
  return { first, last };
}

function addDaysUTC(d: Date, days: number): Date {
  const copy = new Date(d.getTime());
  copy.setUTCDate(copy.getUTCDate() + days);
  return copy;
}

function parseDateKey(key: string): Date {
  const [y, m, d] = key.split("-").map((n) => parseInt(n, 10));
  return new Date(Date.UTC(y, (m ?? 1) - 1, d ?? 1));
}

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

function nowTs(db: admin.firestore.Firestore): admin.firestore.Timestamp {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const adminSdk = require("firebase-admin") as typeof import("firebase-admin");
  return adminSdk.firestore.Timestamp.now();
  // (db argument reserved for future per-project overrides.)
  void db;
}
