/**
 * insightRules.ts — heuristic rules that turn raw rollups into
 * actionable `InsightCard` payloads for the iOS Benchmark tab.
 *
 * Each rule reads a 30-day slice of daily snapshots for ONE user across
 * all providers and returns zero or more `GeneratedInsight` records. The
 * orchestrator (`generateInsights` CF, see index.ts) merges results,
 * sorts by impact + confidence, and writes the top N to
 * `users/{uid}/generatedInsights/{yyyy-mm-dd}`.
 *
 * Rules are intentionally small, pure, and side-effect free. Adding a
 * new heuristic = add an entry to `INSIGHT_RULES` and write a unit test.
 */
import type {
  DailySnapshot,
  GeneratedInsightsDoc,
  SocialProvider,
} from "./snapshotSchema";

export type GeneratedInsight = GeneratedInsightsDoc["insights"][number];

export interface InsightsInput {
  /** All daily snapshots for the user across all providers, last 30 days. */
  snapshots: DailySnapshot[];
  /** Date key (yyyy-mm-dd) the insights are being generated FOR. */
  date: string;
}

export type InsightRule = (input: InsightsInput) => GeneratedInsight[];

// ---------------------------------------------------------------------------
// Rules
// ---------------------------------------------------------------------------

/**
 * Rule 1 — engagement anomaly: flag a provider whose 7-day avg engagement
 * is ≥ 2× the 30-day avg. Classic "your last week crushed it" card.
 */
const engagementSpike: InsightRule = ({ snapshots }) => {
  const byProvider = groupByProvider(snapshots);
  const out: GeneratedInsight[] = [];
  for (const [provider, rows] of byProvider) {
    if (rows.length < 14) continue;
    const sorted = [...rows].sort((a, b) => a.date.localeCompare(b.date));
    const recent = sorted.slice(-7);
    const prior = sorted.slice(0, -7);
    const recentAvg = avgEngagement(recent);
    const priorAvg = avgEngagement(prior);
    if (priorAvg === 0) continue;
    const ratio = recentAvg / priorAvg;
    if (ratio >= 2) {
      out.push({
        id: `engagement_spike_${provider}_${Date.now()}`,
        title: `${displayName(provider)} engagement ${ratio.toFixed(1)}× 30-day avg`,
        description: `Your last 7 days on ${displayName(provider)} averaged ${Math.round(recentAvg)} engagements/day vs ${Math.round(priorAvg)}/day for the prior 3 weeks.`,
        actionableAdvice: `Lean into whatever format you posted last week — the signal is strong.`,
        impact: ratio >= 3 ? "high" : "medium",
        confidence: clamp01(Math.log2(ratio) / 3 + 0.5),
        providers: [provider],
      });
    }
  }
  return out;
};

/**
 * Rule 2 — cross-platform gap: one provider materially outperforms all
 * others on engagement rate. Nudges the user to replicate content.
 */
const crossPlatformGap: InsightRule = ({ snapshots }) => {
  const byProvider = groupByProvider(snapshots);
  if (byProvider.size < 2) return [];
  const rates = Array.from(byProvider.entries()).map(([provider, rows]) => ({
    provider,
    rate: engagementRate(rows),
  }));
  rates.sort((a, b) => b.rate - a.rate);
  const [top, second] = rates;
  if (!top || !second || second.rate === 0) return [];
  const ratio = top.rate / second.rate;
  if (ratio < 1.8) return [];
  return [{
    id: `cross_platform_gap_${top.provider}`,
    title: `${displayName(top.provider)} engagement outruns ${displayName(second.provider)} by ${ratio.toFixed(1)}×`,
    description: `Your ${displayName(top.provider)} content converts viewers into engagers at ${(top.rate * 100).toFixed(1)}% vs ${(second.rate * 100).toFixed(1)}% on ${displayName(second.provider)}.`,
    actionableAdvice: `Try reposting your top ${displayName(top.provider)} posts on ${displayName(second.provider)} — format the hook for that platform.`,
    impact: ratio >= 3 ? "high" : "medium",
    confidence: clamp01(0.6 + Math.log2(ratio) * 0.15),
    providers: [top.provider, second.provider],
  }];
};

/**
 * Rule 3 — follower-growth stall: 14-day follower gain is negative or
 * < 10% of the prior 14-day gain. Low-confidence nudge.
 */
const followerStall: InsightRule = ({ snapshots }) => {
  const byProvider = groupByProvider(snapshots);
  const out: GeneratedInsight[] = [];
  for (const [provider, rows] of byProvider) {
    if (rows.length < 28) continue;
    const sorted = [...rows].sort((a, b) => a.date.localeCompare(b.date));
    const recent = sorted.slice(-14);
    const prior = sorted.slice(-28, -14);
    const recentGain = recent.reduce((a, s) => a + s.followersGain, 0);
    const priorGain = prior.reduce((a, s) => a + s.followersGain, 0);
    if (priorGain <= 0) continue;
    if (recentGain < priorGain * 0.1) {
      out.push({
        id: `follower_stall_${provider}`,
        title: `${displayName(provider)} follower growth stalled`,
        description: `Net new followers dropped from ${priorGain} (prior 14d) to ${recentGain} (last 14d) on ${displayName(provider)}.`,
        actionableAdvice: `Consider reposting one of your top-5 posts or collaborating with an account in your niche.`,
        impact: "medium",
        confidence: 0.7,
        providers: [provider],
      });
    }
  }
  return out;
};

/**
 * Rule 4 — best-hour hint. Reads aggregated `postsByHour` and surfaces
 * the top slot as a recommendation.
 */
const bestHourHint: InsightRule = ({ snapshots }) => {
  const byProvider = groupByProvider(snapshots);
  const out: GeneratedInsight[] = [];
  for (const [provider, rows] of byProvider) {
    if (rows.length < 14) continue;
    const hourly = new Map<string, number>();
    for (const s of rows) {
      for (const [h, v] of Object.entries(s.postsByHour)) {
        hourly.set(h, (hourly.get(h) ?? 0) + v);
      }
    }
    if (hourly.size === 0) continue;
    const sorted = [...hourly.entries()].sort((a, b) => b[1] - a[1]);
    const top = sorted[0];
    if (!top) continue;
    const hour = parseInt(top[0], 10);
    out.push({
      id: `best_hour_${provider}`,
      title: `Best posting window on ${displayName(provider)}: ${formatHour(hour)}`,
      description: `Posts published around ${formatHour(hour)} UTC generated ${Math.round(top[1])} total engagements over the last 30 days — the highest hourly slot.`,
      actionableAdvice: `Schedule your next 3 posts near ${formatHour(hour)} UTC to tap into that window.`,
      impact: "low",
      confidence: 0.65,
      providers: [provider],
    });
  }
  return out;
};

export const INSIGHT_RULES: InsightRule[] = [
  engagementSpike,
  crossPlatformGap,
  followerStall,
  bestHourHint,
];

/** Run every rule and return the merged, ranked list (top `limit`). */
export function runAllRules(
  input: InsightsInput,
  limit: number = 6
): GeneratedInsight[] {
  const all = INSIGHT_RULES.flatMap((rule) => rule(input));
  all.sort((a, b) => impactWeight(b.impact) - impactWeight(a.impact) || b.confidence - a.confidence);
  return all.slice(0, limit);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function groupByProvider(snapshots: DailySnapshot[]): Map<SocialProvider, DailySnapshot[]> {
  const map = new Map<SocialProvider, DailySnapshot[]>();
  for (const s of snapshots) {
    const arr = map.get(s.provider) ?? [];
    arr.push(s);
    map.set(s.provider, arr);
  }
  return map;
}

function avgEngagement(rows: DailySnapshot[]): number {
  if (rows.length === 0) return 0;
  const total = rows.reduce(
    (a, s) => a + s.likes + s.comments + s.shares + (s.saves ?? 0),
    0
  );
  return total / rows.length;
}

function engagementRate(rows: DailySnapshot[]): number {
  const views = rows.reduce((a, s) => a + s.views, 0);
  if (views === 0) return 0;
  const eng = rows.reduce(
    (a, s) => a + s.likes + s.comments + s.shares + (s.saves ?? 0),
    0
  );
  return eng / views;
}

function displayName(p: SocialProvider): string {
  switch (p) {
    case "instagram": return "Instagram";
    case "facebook":  return "Facebook";
    case "tiktok":    return "TikTok";
    case "x":         return "X";
    case "threads":   return "Threads";
    case "linkedin":  return "LinkedIn";
  }
}

function formatHour(h: number): string {
  const hh = String(h).padStart(2, "0");
  return `${hh}:00`;
}

function impactWeight(impact: "high" | "medium" | "low"): number {
  return impact === "high" ? 3 : impact === "medium" ? 2 : 1;
}

function clamp01(n: number): number {
  return Math.max(0, Math.min(1, n));
}
