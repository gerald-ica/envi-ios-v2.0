import Foundation
import Combine

// MARK: - Experiment Tracker

/// Tracks experiments (hypotheses) and their results over time.
///
/// This is the direct analog to autoresearch's `results.tsv`:
///
/// ```
/// commit    val_bpb    memory_gb    status     description
/// a1b2c3d   0.997900   44.0         keep       baseline
/// b2c3d4e   0.993200   44.2         keep       increase LR to 0.04
/// c3d4e5f   1.005000   44.0         discard    switch to GeLU activation
/// d4e5f6g   0.000000   0.0          crash      double model width (OOM)
/// ```
///
/// Instead of tracking val_bpb per git commit, we track engagement_rate per
/// content strategy hypothesis. The keep/discard/crash semantics are identical:
/// - **keep**: Strategy improved the primary metric → incorporate into future recommendations
/// - **discard**: Strategy didn't improve or made things worse → don't recommend again
/// - **crash**: Something went wrong (content deleted, platform API error) → log and move on
///
/// The ExperimentTracker is the ENVI Brain's memory — it learns what works
/// for this specific user over time, building an ever-improving model of
/// their content strategy.
final class ExperimentTracker: ObservableObject {

    // MARK: - Types

    /// A single experiment — one hypothesis tested against the user's content.
    ///
    /// Maps directly to a row in autoresearch's results.tsv:
    /// - `id` ≈ commit hash (unique identifier)
    /// - `hypothesis` ≈ description (what was tried)
    /// - `metric` ≈ val_bpb column name
    /// - `baselineValue` ≈ previous best val_bpb
    /// - `resultValue` ≈ new val_bpb after experiment
    /// - `status` ≈ keep/discard/crash
    struct Experiment: Identifiable, Codable {
        let id: UUID
        let hypothesis: String          // "Posting carousel on Wed 2pm will boost engagement"
        let metric: String              // "engagement_rate"
        let baselineValue: Double       // Metric value before this experiment
        var resultValue: Double?        // Metric value after (nil if still pending)
        var status: ExperimentStatus
        let createdAt: Date
        var completedAt: Date?
        let description: String
        let contentPieceId: String?     // Associated content piece, if any
        let platform: String?           // Target platform
        let contentType: String?        // Target content type

        init(
            id: UUID = UUID(),
            hypothesis: String,
            metric: String = ENVIBrainConfig.primaryMetric,
            baselineValue: Double,
            resultValue: Double? = nil,
            status: ExperimentStatus = .pending,
            createdAt: Date = Date(),
            completedAt: Date? = nil,
            description: String,
            contentPieceId: String? = nil,
            platform: String? = nil,
            contentType: String? = nil
        ) {
            self.id = id
            self.hypothesis = hypothesis
            self.metric = metric
            self.baselineValue = baselineValue
            self.resultValue = resultValue
            self.status = status
            self.createdAt = createdAt
            self.completedAt = completedAt
            self.description = description
            self.contentPieceId = contentPieceId
            self.platform = platform
            self.contentType = contentType
        }
    }

    /// Experiment status — mirrors autoresearch's keep/discard/crash exactly.
    ///
    /// From autoresearch's program.md:
    /// > If val_bpb improved (lower), you "advance" the branch, keeping the git commit.
    /// > If val_bpb is equal or worse, you git reset back to where you started.
    /// > If a run crashes — log "crash" as the status and move on.
    enum ExperimentStatus: String, Codable, CaseIterable {
        case pending    // Hypothesis proposed, not yet tested (experiment queued)
        case active     // User posted content, waiting for engagement metrics to come in
        case keep       // Improvement confirmed → keep this strategy, advance the loop
        case discard    // No improvement or decline → discard, revert to previous approach
        case crash      // Something went wrong (content deleted, API error, etc.)
    }

    // MARK: - Published State

    @Published var experiments: [Experiment] = []

    // MARK: - Persistence

    private let storageKey = "envi_brain_experiments"

    init() {
        loadExperiments()
    }

    // MARK: - Core Methods

    /// Record a new experiment.
    ///
    /// Equivalent to: git commit + start the training run.
    /// The experiment begins in `.pending` status and transitions to `.active`
    /// when the user posts content, then to `.keep`/`.discard`/`.crash` when
    /// engagement data comes in.
    func recordExperiment(_ experiment: Experiment) {
        experiments.append(experiment)
        trimLogIfNeeded()
        saveExperiments()
    }

    /// Evaluate an experiment by comparing its result to the baseline.
    ///
    /// This is the critical keep/discard decision from autoresearch:
    /// ```
    /// If val_bpb improved (lower) → keep
    /// If val_bpb is equal or worse → discard
    /// ```
    ///
    /// For ENVI (where higher engagement_rate is better):
    /// ```
    /// If engagement_rate improved by >= keepThreshold → keep
    /// If engagement_rate declined by >= discardThreshold → discard
    /// Otherwise → discard (no significant change)
    /// ```
    func evaluateExperiment(_ id: UUID, result: Double) {
        guard let index = experiments.firstIndex(where: { $0.id == id }) else { return }

        experiments[index].resultValue = result
        experiments[index].completedAt = Date()

        let baseline = experiments[index].baselineValue
        let improvement = baseline > 0 ? (result - baseline) / baseline : 0

        if improvement >= ENVIBrainConfig.keepThreshold {
            experiments[index].status = .keep
        } else if improvement <= ENVIBrainConfig.discardThreshold {
            experiments[index].status = .discard
        } else {
            // Marginal change — not enough signal to keep
            experiments[index].status = .discard
        }

        saveExperiments()
    }

    /// Mark an experiment as crashed (content deleted, API error, etc.).
    ///
    /// From autoresearch: "If a run crashes — log 'crash' as the status and move on."
    func markExperimentCrashed(_ id: UUID) {
        guard let index = experiments.firstIndex(where: { $0.id == id }) else { return }
        experiments[index].status = .crash
        experiments[index].completedAt = Date()
        experiments[index].resultValue = 0
        saveExperiments()
    }

    /// Activate a pending experiment (user has posted the content).
    func activateExperiment(_ id: UUID) {
        guard let index = experiments.firstIndex(where: { $0.id == id }) else { return }
        experiments[index].status = .active
        saveExperiments()
    }

    // MARK: - Analytics

    /// What percentage of experiments were kept (strategies that worked).
    ///
    /// This is the ENVI Brain's "hit rate" — how often its predictions are correct.
    /// In autoresearch terms, it's the fraction of experiments that improved val_bpb.
    /// A high keep rate means the Brain is learning the user's audience well.
    func getKeepRate() -> Double {
        let completed = experiments.filter { $0.status == .keep || $0.status == .discard }
        guard !completed.isEmpty else { return 0 }
        let kept = completed.filter { $0.status == .keep }.count
        return Double(kept) / Double(completed.count)
    }

    /// Returns the best-performing strategies (experiments with status = .keep),
    /// sorted by the magnitude of improvement.
    ///
    /// These are the "accumulated improvements" — the winning strategies that the
    /// ENVI Brain has validated and should continue recommending.
    func getBestStrategies(count: Int) -> [Experiment] {
        experiments
            .filter { $0.status == .keep }
            .sorted { exp1, exp2 in
                let improvement1 = exp1.baselineValue > 0 ? ((exp1.resultValue ?? 0) - exp1.baselineValue) / exp1.baselineValue : 0
                let improvement2 = exp2.baselineValue > 0 ? ((exp2.resultValue ?? 0) - exp2.baselineValue) / exp2.baselineValue : 0
                return improvement1 > improvement2
            }
            .prefix(count)
            .map { $0 }
    }

    /// Returns experiments filtered by status.
    func experiments(withStatus status: ExperimentStatus) -> [Experiment] {
        experiments.filter { $0.status == status }
    }

    /// Number of currently active (in-flight) experiments.
    var activeExperimentCount: Int {
        experiments.filter { $0.status == .active }.count
    }

    /// Whether we can start a new experiment (respects concurrent limit).
    var canStartNewExperiment: Bool {
        activeExperimentCount < ENVIBrainConfig.maxConcurrentExperiments
    }

    /// Total number of completed experiments (keep + discard + crash).
    var completedCount: Int {
        experiments.filter { $0.status != .pending && $0.status != .active }.count
    }

    /// Summary statistics for the experiment log.
    var summary: ExperimentSummary {
        let total = experiments.count
        let kept = experiments.filter { $0.status == .keep }.count
        let discarded = experiments.filter { $0.status == .discard }.count
        let crashed = experiments.filter { $0.status == .crash }.count
        let pending = experiments.filter { $0.status == .pending }.count
        let active = experiments.filter { $0.status == .active }.count
        return ExperimentSummary(
            total: total,
            kept: kept,
            discarded: discarded,
            crashed: crashed,
            pending: pending,
            active: active,
            keepRate: getKeepRate()
        )
    }

    struct ExperimentSummary {
        let total: Int
        let kept: Int
        let discarded: Int
        let crashed: Int
        let pending: Int
        let active: Int
        let keepRate: Double
    }

    // MARK: - Persistence Helpers

    // MIGRATION NOTE: If the Experiment struct changes (fields added/removed/renamed),
    // bump a version constant here and add migration logic in loadExperiments()
    // to decode the old format and re-encode in the new format, or clear stale data.
    // Current schema version: 1

    private func saveExperiments() {
        do {
            let data = try JSONEncoder().encode(experiments)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("[ExperimentTracker] Failed to encode experiments: \(error.localizedDescription)")
        }
    }

    private func loadExperiments() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            experiments = try JSONDecoder().decode([Experiment].self, from: data)
        } catch {
            print("[ExperimentTracker] Failed to decode experiments (possible schema migration needed): \(error.localizedDescription)")
            // Don't lose data — leave the raw data in UserDefaults for manual recovery
        }
    }

    private func trimLogIfNeeded() {
        if experiments.count > ENVIBrainConfig.maxExperimentLogSize {
            // Keep the most recent experiments, drop the oldest
            experiments = Array(experiments.suffix(ENVIBrainConfig.maxExperimentLogSize))
        }
    }

    // MARK: - Sample Data

    /// Sample experiments for development and testing.
    static let sampleExperiments: [Experiment] = [
        Experiment(
            hypothesis: "Posting a reel on Wednesday at 2pm will boost engagement by 20%",
            baselineValue: 0.035,
            resultValue: 0.048,
            status: .keep,
            createdAt: Date().addingTimeInterval(-86400 * 5),
            completedAt: Date().addingTimeInterval(-86400 * 3),
            description: "Wednesday 2pm reel → +37% engagement rate",
            platform: "instagram",
            contentType: "reel"
        ),
        Experiment(
            hypothesis: "Carousel format on LinkedIn will outperform single image",
            baselineValue: 0.028,
            resultValue: 0.041,
            status: .keep,
            createdAt: Date().addingTimeInterval(-86400 * 10),
            completedAt: Date().addingTimeInterval(-86400 * 7),
            description: "LinkedIn carousel → +46% engagement rate",
            platform: "linkedin",
            contentType: "carousel"
        ),
        Experiment(
            hypothesis: "Posting at 11pm will capture night-owl audience",
            baselineValue: 0.035,
            resultValue: 0.022,
            status: .discard,
            createdAt: Date().addingTimeInterval(-86400 * 14),
            completedAt: Date().addingTimeInterval(-86400 * 12),
            description: "11pm posting time → -37% engagement rate",
            platform: "instagram",
            contentType: "photo"
        ),
        Experiment(
            hypothesis: "Quote card with personal story in caption will increase saves",
            baselineValue: 0.025,
            resultValue: nil,
            status: .active,
            createdAt: Date().addingTimeInterval(-86400 * 2),
            description: "Quote card + personal story experiment — waiting for metrics",
            platform: "linkedin",
            contentType: "photo"
        ),
        Experiment(
            hypothesis: "BTS video with trending audio will go viral on TikTok",
            baselineValue: 0.052,
            resultValue: nil,
            status: .pending,
            description: "BTS trending audio hypothesis — not yet posted",
            platform: "tiktok",
            contentType: "video"
        ),
    ]
}
