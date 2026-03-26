import Foundation

// MARK: - ENVI Brain Configuration

/// Configuration for the ENVI Brain research loop.
///
/// In karpathy/autoresearch, the experiment loop has fixed constraints:
/// - A fixed 5-minute time budget per experiment
/// - A single metric to optimize (val_bpb)
/// - A simplicity criterion (prefer simpler code at equal performance)
///
/// ENVIBrainConfig is the ENVI equivalent — it defines the fixed constraints
/// for the content optimization loop:
/// - How far back to look for data (evaluation window)
/// - How far ahead to predict (prediction horizon)
/// - What metric to optimize (engagement_rate)
/// - When to keep or discard a strategy (thresholds)
///
/// Like autoresearch's `prepare.py` constants, these are intentionally fixed
/// so that experiments are directly comparable across iterations.
struct ENVIBrainConfig {

    // MARK: - Research Loop Parameters

    /// How far back to analyze engagement data when evaluating experiments.
    /// Analogous to autoresearch's fixed training window — a consistent lookback
    /// ensures apples-to-apples comparison between experiment iterations.
    static let evaluationWindowDays = 7

    /// How far ahead to generate predictions.
    /// Longer horizons decrease confidence; 14 days balances utility with accuracy.
    static let predictionHorizonDays = 14

    /// Minimum confidence (0.0–1.0) to surface a prediction to the user.
    /// Below this threshold, predictions are kept internal for model learning
    /// but not shown in the UI — avoids noisy, low-signal recommendations.
    static let minConfidenceThreshold: Double = 0.65

    /// Cooldown between re-evaluating the same hypothesis.
    /// Prevents the loop from thrashing on a single idea — forces it to
    /// move on and explore other strategies, then revisit later.
    static let experimentCooldownHours = 24

    /// Maximum number of active (in-flight) experiments at once.
    /// In autoresearch, only one experiment runs at a time (sequential GPU).
    /// For content, the user may have multiple posts in flight, so we allow
    /// a small number of concurrent experiments.
    static let maxConcurrentExperiments = 5

    // MARK: - Metrics (equivalent to val_bpb)

    /// The primary metric the ENVI Brain optimizes.
    /// In autoresearch, this is `val_bpb` — lower is better.
    /// In ENVI, this is `engagement_rate` — higher is better.
    /// Every experiment is ultimately judged by this single metric.
    static let primaryMetric = "engagement_rate"

    /// Secondary metrics tracked for context but not used for keep/discard decisions.
    /// These provide signal for understanding *why* engagement changed.
    static let secondaryMetrics = ["reach", "saves", "shares", "profile_visits"]

    // MARK: - Keep/Discard Thresholds

    /// Minimum improvement (as a fraction) to keep a strategy.
    /// +5% engagement_rate improvement → keep this strategy, advance the loop.
    /// In autoresearch terms: val_bpb improved → keep the commit.
    static let keepThreshold: Double = 0.05

    /// Decline threshold (as a fraction) to immediately discard a strategy.
    /// -10% engagement_rate decline → discard, revert to previous approach.
    /// In autoresearch terms: val_bpb got worse → git reset.
    static let discardThreshold: Double = -0.10

    // MARK: - Content Analysis

    /// Number of top posting time windows to suggest.
    /// The PredictionEngine identifies these from historical engagement patterns.
    static let optimalPostingWindows = 5

    /// Alert the user if no content of a specific type has been posted in N days.
    /// Content gaps correlate with audience drop-off — this is a proactive signal.
    static let contentGapAlertDays = 7

    /// How aggressively to recommend trending content (0.0–1.0).
    /// Higher values push more trend-based recommendations; lower values
    /// favor the user's established content patterns.
    static let trendingSensitivity: Double = 0.7

    // MARK: - Loop Scheduling

    /// Interval between background research loop iterations (in seconds).
    /// The loop doesn't run "forever" on iOS like autoresearch does on a GPU —
    /// instead it triggers on app launch, content updates, and background refresh.
    static let backgroundLoopIntervalSeconds: TimeInterval = 3600  // 1 hour

    /// Maximum iterations per session before the loop pauses.
    /// Prevents runaway CPU usage on mobile devices.
    static let maxIterationsPerSession = 10

    // MARK: - Experiment Log

    /// Maximum number of experiments to keep in the local log.
    /// Analogous to autoresearch's results.tsv — but on-device storage is limited.
    static let maxExperimentLogSize = 200

    /// Date formatter for experiment timestamps.
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}
