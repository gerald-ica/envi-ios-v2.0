import Foundation
import Combine

// MARK: - Research Loop

/// The core autoresearch loop adapted for content optimization.
/// This is the heart of the ENVI Brain — an autonomous improvement cycle.
///
/// ## Direct Mapping to karpathy/autoresearch
///
/// From autoresearch's `program.md`:
/// ```
/// LOOP FOREVER:
///   1. Look at the git state: the current branch/commit we're on
///   2. Tune train.py with an experimental idea by directly hacking the code.
///   3. git commit
///   4. Run the experiment: uv run train.py > run.log 2>&1
///   5. Read out the results: grep "^val_bpb:" run.log
///   6. If crashed → read stack trace, attempt fix, or give up
///   7. Record the results in the tsv
///   8. If val_bpb improved → keep (advance branch)
///   9. If val_bpb worse → discard (git reset)
/// ```
///
/// The ENVI Research Loop adaptation:
/// ```
/// LOOP (on app launch, content updates, background refresh):
///   1. OBSERVE: Analyze current content library + engagement metrics
///   2. HYPOTHESIZE: Generate predictions via PredictionEngine
///   3. EXECUTE: User posts content (or accepts AI recommendation)
///   4. MEASURE: Track actual engagement vs. prediction
///   5. EVALUATE: Compare result to baseline
///   6. LEARN: If improved → keep strategy. If worse → discard.
///   7. RECORD: Log experiment in ExperimentTracker
///   8. ITERATE: Feed learnings into next prediction cycle
/// ```
///
/// ## Key Differences from autoresearch
///
/// 1. **Not literally "LOOP FOREVER"**: On iOS, the loop triggers on events
///    (app launch, content updates, background refresh) rather than running
///    continuously on a GPU. Each trigger advances the loop by one iteration.
///
/// 2. **Human in the loop**: In autoresearch, the agent autonomously edits
///    train.py and runs experiments. In ENVI, the user decides whether to
///    act on predictions. The loop still works because we measure what
///    actually happens and learn from it.
///
/// 3. **Longer feedback cycles**: autoresearch experiments take 5 minutes.
///    Content experiments take days (waiting for engagement data). The loop
///    accounts for this with async evaluation and experiment cooldowns.
///
/// 4. **Multiple concurrent experiments**: autoresearch runs one experiment
///    at a time. A content creator may have multiple posts in flight. We
///    track up to `maxConcurrentExperiments` simultaneously.
final class ResearchLoop: ObservableObject {

    // MARK: - Types

    /// The current state of the research loop.
    ///
    /// Maps to autoresearch's implicit loop states:
    /// - `.idle` → between experiments
    /// - `.observing` → "Look at the git state" (step 1)
    /// - `.hypothesizing` → "Tune train.py with an idea" (step 2)
    /// - `.waiting` → "Run the experiment" (steps 3-4, but async for content)
    /// - `.evaluating` → "Read out the results" + keep/discard decision (steps 5-9)
    /// - `.learning` → Updating internal models based on results
    enum LoopState: String, CaseIterable {
        case idle           // Between iterations, waiting for trigger
        case observing      // Analyzing current content library + metrics
        case hypothesizing  // Generating new predictions
        case waiting        // User hasn't acted yet, or waiting for engagement data
        case evaluating     // Measuring results against baseline
        case learning       // Updating models based on experiment outcomes
    }

    /// Summary of the research loop's current status.
    struct LoopStatus {
        let state: LoopState
        let loopCount: Int
        let keepRate: Double
        let activeExperiments: Int
        let pendingExperiments: Int
        let lastIterationDate: Date?
        let nextScheduledIteration: Date?
    }

    // MARK: - Published State

    @Published var state: LoopState = .idle
    @Published var currentExperiment: ExperimentTracker.Experiment?
    @Published var loopCount: Int = 0           // Total iterations completed
    @Published var keepRate: Double = 0         // % of experiments kept
    @Published var lastIterationDate: Date?
    @Published var isRunning: Bool = false

    // MARK: - Dependencies

    private let contentAnalyzer: ContentAnalyzer
    private let predictionEngine: PredictionEngine
    private let experimentTracker: ExperimentTracker
    private let insightGenerator: InsightGenerator
    private let trendForecaster: TrendForecaster

    private var cancellables = Set<AnyCancellable>()
    private var iterationTimer: Timer?

    // MARK: - Initialization

    init(
        contentAnalyzer: ContentAnalyzer,
        predictionEngine: PredictionEngine,
        experimentTracker: ExperimentTracker,
        insightGenerator: InsightGenerator,
        trendForecaster: TrendForecaster
    ) {
        self.contentAnalyzer = contentAnalyzer
        self.predictionEngine = predictionEngine
        self.experimentTracker = experimentTracker
        self.insightGenerator = insightGenerator
        self.trendForecaster = trendForecaster

        // Observe experiment tracker to update keep rate
        experimentTracker.$experiments
            .map { _ in self.experimentTracker.getKeepRate() }
            .assign(to: &$keepRate)
    }

    // MARK: - Loop Control

    /// Start the research loop.
    ///
    /// From autoresearch: "Once you get confirmation, kick off the experimentation."
    ///
    /// On iOS, this sets up the loop to run on a schedule and triggers
    /// the first iteration immediately.
    func startLoop() {
        guard !isRunning else { return }
        isRunning = true

        // Run first iteration immediately
        advanceLoop()

        // Schedule periodic iterations
        iterationTimer = Timer.scheduledTimer(
            withTimeInterval: ENVIBrainConfig.backgroundLoopIntervalSeconds,
            repeats: true
        ) { [weak self] _ in
            self?.advanceLoop()
        }
    }

    /// Pause the research loop.
    ///
    /// Unlike autoresearch ("NEVER STOP"), the ENVI loop can be paused
    /// by the user or by the system (battery saver, background limits).
    func pauseLoop() {
        isRunning = false
        iterationTimer?.invalidate()
        iterationTimer = nil
        state = .idle
    }

    /// Execute one iteration of the research loop.
    ///
    /// This is the core of the autoresearch pattern adapted for ENVI:
    /// one complete cycle of observe → hypothesize → evaluate → learn.
    ///
    /// From autoresearch:
    /// > The idea is that you are a completely autonomous researcher trying
    /// > things out. If they work, keep. If they don't, discard. And you're
    /// > advancing so that you can iterate.
    func advanceLoop() {
        guard state == .idle || state == .waiting else { return }

        // STEP 1: OBSERVE
        // autoresearch: "Look at the git state: the current branch/commit we're on"
        state = .observing
        let contentLibrary = ContentPiece.sampleLibrary
        let patterns = contentAnalyzer.analyzeLibrary(contentLibrary)

        // STEP 2: EVALUATE PENDING EXPERIMENTS
        // autoresearch: "Read out the results: grep '^val_bpb:' run.log"
        state = .evaluating
        evaluatePendingExperiments(contentLibrary: contentLibrary)

        // STEP 3: HYPOTHESIZE
        // autoresearch: "Tune train.py with an experimental idea"
        state = .hypothesizing
        let predictions = predictionEngine.generatePredictions(
            for: contentLibrary,
            history: experimentTracker.experiments
        )

        // STEP 4: CREATE NEW EXPERIMENTS FROM TOP PREDICTIONS
        // autoresearch: "git commit" + "Run the experiment"
        if experimentTracker.canStartNewExperiment, let topPrediction = predictions.first {
            let experiment = ExperimentTracker.Experiment(
                hypothesis: topPrediction.title,
                baselineValue: patterns.averageEngagementRate,
                description: topPrediction.description,
                platform: topPrediction.suggestedPlatform,
                contentType: topPrediction.suggestedContentType
            )
            experimentTracker.recordExperiment(experiment)
            currentExperiment = experiment
        }

        // STEP 5: GENERATE INSIGHTS
        // (No direct autoresearch equivalent — this is ENVI's user communication layer)
        state = .learning
        let _ = insightGenerator.generateWeeklyInsights(from: patterns)
        let _ = trendForecaster.getUpcomingEvents(count: 5)
        let _ = trendForecaster.detectTrendingOpportunities()

        // STEP 6: RECORD AND ITERATE
        // autoresearch: "Record the results in the tsv"
        loopCount += 1
        lastIterationDate = Date()
        keepRate = experimentTracker.getKeepRate()

        // Back to idle, waiting for next trigger
        // autoresearch: loop back to step 1
        state = isRunning ? .waiting : .idle
    }

    /// Get the current status of the research loop.
    func getStatus() -> LoopStatus {
        LoopStatus(
            state: state,
            loopCount: loopCount,
            keepRate: keepRate,
            activeExperiments: experimentTracker.activeExperimentCount,
            pendingExperiments: experimentTracker.experiments(withStatus: .pending).count,
            lastIterationDate: lastIterationDate,
            nextScheduledIteration: lastIterationDate?.addingTimeInterval(ENVIBrainConfig.backgroundLoopIntervalSeconds)
        )
    }

    // MARK: - Experiment Evaluation

    /// Evaluate experiments that have been active long enough to have results.
    ///
    /// This is the keep/discard decision from autoresearch:
    /// > If val_bpb improved (lower), you "advance" the branch, keeping the git commit.
    /// > If val_bpb is equal or worse, you git reset back to where you started.
    ///
    /// For content experiments, we wait at least `evaluationWindowDays` before
    /// evaluating, then compare engagement_rate to the baseline.
    private func evaluatePendingExperiments(contentLibrary: [ContentPiece]) {
        let activeExperiments = experimentTracker.experiments(withStatus: .active)

        for experiment in activeExperiments {
            let daysSinceCreation = Calendar.current.dateComponents(
                [.day],
                from: experiment.createdAt,
                to: Date()
            ).day ?? 0

            // Only evaluate after the evaluation window has passed
            guard daysSinceCreation >= ENVIBrainConfig.evaluationWindowDays else { continue }

            // Calculate current engagement rate for the experiment's content type
            let relevantPieces = contentLibrary.filter { piece in
                if let platform = experiment.platform {
                    return piece.platform.rawValue == platform && !piece.isFuture
                }
                return !piece.isFuture
            }

            let currentEngagementRate: Double
            if !relevantPieces.isEmpty {
                let totalViews = relevantPieces.compactMap { $0.metrics?.views }.reduce(0, +)
                let totalLikes = relevantPieces.compactMap { $0.metrics?.likes }.reduce(0, +)
                let totalShares = relevantPieces.compactMap { $0.metrics?.shares }.reduce(0, +)
                let totalComments = relevantPieces.compactMap { $0.metrics?.comments }.reduce(0, +)
                let totalEngagement = totalLikes + totalShares + totalComments
                currentEngagementRate = totalViews > 0 ? Double(totalEngagement) / Double(totalViews) : 0
            } else {
                currentEngagementRate = experiment.baselineValue
            }

            // THE KEEP/DISCARD DECISION
            // autoresearch: "If val_bpb improved → keep. If worse → discard."
            experimentTracker.evaluateExperiment(experiment.id, result: currentEngagementRate)
        }
    }

    // MARK: - Event-Driven Triggers

    /// Trigger the loop when new content is added.
    /// This is like autoresearch's "git commit" — new state enters the system.
    func onContentAdded(_ piece: ContentPiece) {
        // Check if this content matches any pending experiments
        let pendingExperiments = experimentTracker.experiments(withStatus: .pending)
        for experiment in pendingExperiments {
            if experiment.contentType == piece.type.rawValue ||
               experiment.platform == piece.platform.rawValue {
                experimentTracker.activateExperiment(experiment.id)
            }
        }

        // Trigger a loop iteration if not already running
        if state == .idle || state == .waiting {
            advanceLoop()
        }
    }

    /// Trigger the loop when engagement metrics are updated.
    /// This is like autoresearch's "grep val_bpb run.log" — results are in.
    func onMetricsUpdated(for pieceId: String, metrics: ContentMetrics) {
        if state == .idle || state == .waiting {
            advanceLoop()
        }
    }

    /// Trigger the loop on app launch.
    func onAppLaunch() {
        advanceLoop()
    }
}
