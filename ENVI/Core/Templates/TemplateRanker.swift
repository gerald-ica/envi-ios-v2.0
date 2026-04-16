import Foundation

// MARK: - Ranked Output

/// Transparent breakdown of a single ranked template's score — used for
/// debugging the "For You" ranker (and surfaced in tests).
struct RankedTemplate {
    let template: PopulatedTemplate
    let rank: Int
    let scoreBreakdown: ScoreBreakdown

    struct ScoreBreakdown {
        let fill: Double
        let score: Double
        let popularity: Double
        let recency: Double
        let total: Double
    }
}

// MARK: - Ranker

/// Deterministic ranker for the "For You" section of the Template tab.
///
/// Score per template:
///   `fillRate * fillWeight + overallScore * scoreWeight + (popularity / maxPopularity) * popularityWeight`
///
/// Secondary sort: recency of the template's matched assets (templates that
/// best match the user's *recent* content rank higher when primary scores tie).
///
/// Weights are tunable via init for experimentation; defaults follow Phase 3
/// plan: fill 0.5, score 0.3, popularity 0.2.
struct TemplateRanker {
    var fillWeight: Double
    var scoreWeight: Double
    var popularityWeight: Double

    /// Half-life (seconds) used to decay asset recency into a 0..1 signal.
    /// Default ~30 days, matching the "recent content" preference used by
    /// the match engine.
    var recencyHalfLife: TimeInterval

    /// Clock injection — lets tests use a fixed "now" for deterministic recency.
    var now: () -> Date

    init(
        fillWeight: Double = 0.5,
        scoreWeight: Double = 0.3,
        popularityWeight: Double = 0.2,
        recencyHalfLife: TimeInterval = 60 * 60 * 24 * 30,
        now: @escaping () -> Date = Date.init
    ) {
        self.fillWeight = fillWeight
        self.scoreWeight = scoreWeight
        self.popularityWeight = popularityWeight
        self.recencyHalfLife = recencyHalfLife
        self.now = now
    }

    /// Primary entry point. Returns `populated` sorted by descending ranker score.
    func rank(_ populated: [PopulatedTemplate]) -> [PopulatedTemplate] {
        rankWithBreakdown(populated).map(\.template)
    }

    /// Returns full score breakdowns for each template in ranked order.
    func rankWithBreakdown(_ populated: [PopulatedTemplate]) -> [RankedTemplate] {
        guard !populated.isEmpty else { return [] }

        let maxPopularity = max(1, populated.map(\.template.popularity).max() ?? 1)
        let reference = now()

        let scored: [(template: PopulatedTemplate, breakdown: RankedTemplate.ScoreBreakdown)] =
            populated.map { pop in
                let fill = pop.fillRate
                let score = pop.overallScore
                let pop01 = Double(pop.template.popularity) / Double(maxPopularity)
                let recency = recencySignal(for: pop, reference: reference)

                let total =
                    fill * fillWeight
                    + score * scoreWeight
                    + pop01 * popularityWeight

                let breakdown = RankedTemplate.ScoreBreakdown(
                    fill: fill * fillWeight,
                    score: score * scoreWeight,
                    popularity: pop01 * popularityWeight,
                    recency: recency,
                    total: total
                )
                return (pop, breakdown)
            }

        // Primary: total desc. Secondary: recency desc. Stable via index fallback.
        let sorted = scored.enumerated().sorted { lhs, rhs in
            if lhs.element.breakdown.total != rhs.element.breakdown.total {
                return lhs.element.breakdown.total > rhs.element.breakdown.total
            }
            if lhs.element.breakdown.recency != rhs.element.breakdown.recency {
                return lhs.element.breakdown.recency > rhs.element.breakdown.recency
            }
            return lhs.offset < rhs.offset
        }

        return sorted.enumerated().map { rankIndex, entry in
            RankedTemplate(
                template: entry.element.template,
                rank: rankIndex,
                scoreBreakdown: entry.element.breakdown
            )
        }
    }

    // MARK: - Recency

    /// Sum of exponential-decay recency across filled slots' matched assets.
    /// Empty / photoless matches contribute 0. Result is normalized by slot count
    /// so it stays in roughly [0, 1] regardless of template size.
    private func recencySignal(for populated: PopulatedTemplate, reference: Date) -> Double {
        let filled = populated.filledSlots.compactMap { $0.matchedAsset }
        guard !filled.isEmpty else { return 0 }

        let decayed = filled.map { asset -> Double in
            guard let created = asset.creationDate else { return 0 }
            let age = reference.timeIntervalSince(created)
            guard age >= 0 else { return 1 }
            return pow(0.5, age / recencyHalfLife)
        }
        return decayed.reduce(0, +) / Double(populated.filledSlots.count)
    }
}
