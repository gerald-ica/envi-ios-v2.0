import Foundation
import Combine

// MARK: - Prediction Engine

/// Generates content predictions and recommendations for the ENVI Brain.
///
/// In the karpathy/autoresearch pattern, this is the agent that "proposes changes
/// to train.py" — it looks at the current state, identifies opportunities, and
/// generates a concrete hypothesis to test.
///
/// In ENVI's adaptation:
/// - Instead of proposing code changes, it proposes content strategies
/// - Instead of optimizing val_bpb, it optimizes engagement_rate
/// - Instead of modifying a training script, it recommends what to post, when, where, and why
///
/// The PredictionEngine is purely generative — it doesn't evaluate results.
/// That's the ExperimentTracker's job (separation of concerns mirrors
/// autoresearch's separation of train.py edits from results.tsv logging).
final class PredictionEngine: ObservableObject {

    // MARK: - Types

    /// A single content prediction — the ENVI equivalent of a "proposed change to train.py".
    struct Prediction: Identifiable, Codable {
        let id: UUID
        let type: PredictionType
        let title: String
        let description: String
        let confidence: Double              // 0.0–1.0
        let predictedEngagement: EngagementForecast
        let suggestedDate: Date
        let suggestedPlatform: String
        let suggestedContentType: String
        let reasoning: String               // "Based on your last 30 days..."
        let priority: Priority
        let createdAt: Date

        init(
            id: UUID = UUID(),
            type: PredictionType,
            title: String,
            description: String,
            confidence: Double,
            predictedEngagement: EngagementForecast,
            suggestedDate: Date,
            suggestedPlatform: String,
            suggestedContentType: String,
            reasoning: String,
            priority: Priority,
            createdAt: Date = Date()
        ) {
            self.id = id
            self.type = type
            self.title = title
            self.description = description
            self.confidence = confidence
            self.predictedEngagement = predictedEngagement
            self.suggestedDate = suggestedDate
            self.suggestedPlatform = suggestedPlatform
            self.suggestedContentType = suggestedContentType
            self.reasoning = reasoning
            self.priority = priority
            self.createdAt = createdAt
        }
    }

    /// Categories of predictions the engine can generate.
    /// Each maps to a different "type of experiment" in autoresearch terms.
    enum PredictionType: String, Codable, CaseIterable {
        case optimalPostTime        // When to post for maximum engagement
        case contentRecommendation  // What type of content to create
        case trendOpportunity       // Trending topic/audio/format to leverage
        case contentGap             // Missing content type that the audience expects
        case collaborationSuggestion // Partner/collab opportunity
        case importantDate          // Holiday, cultural moment, audience milestone
        case audiencePeakWindow     // Time window when followers are most active
    }

    /// Priority levels for predictions — determines UI prominence.
    enum Priority: String, Codable, CaseIterable, Comparable {
        case critical   // Immediate action needed (trend about to expire, content gap critical)
        case high       // Strong recommendation, high confidence
        case medium     // Solid suggestion, moderate confidence
        case low        // Nice-to-have, lower confidence

        static func < (lhs: Priority, rhs: Priority) -> Bool {
            let order: [Priority] = [.low, .medium, .high, .critical]
            return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
        }
    }

    /// Forecasted engagement metrics for a prediction.
    /// Parallels the output summary of an autoresearch experiment:
    /// where autoresearch logs val_bpb + peak_vram + mfu_percent,
    /// we log predicted views + likes + shares + comments + engagement_rate.
    struct EngagementForecast: Codable {
        let predictedViews: Int
        let predictedLikes: Int
        let predictedShares: Int
        let predictedComments: Int
        let engagementRate: Double

        /// Human-readable summary of the forecast.
        var summary: String {
            let viewsK = Double(predictedViews) / 1000.0
            let ratePercent = String(format: "%.1f", engagementRate * 100)
            return String(format: "~%.1fK views, %.0f likes, %@%% eng. rate",
                         viewsK, Double(predictedLikes), ratePercent)
        }
    }

    // MARK: - Published State

    @Published var predictions: [Prediction] = []
    @Published var isGenerating: Bool = false

    // MARK: - Core Methods

    /// Generate predictions for the user's content library.
    ///
    /// This is the "propose a change" step in the autoresearch loop.
    /// It analyzes the content library and past experiment history to generate
    /// new hypotheses about what content will perform best.
    ///
    /// - Parameters:
    ///   - library: The user's current content library
    ///   - history: Past experiments and their results (to avoid repeating failures)
    /// - Returns: Array of predictions sorted by priority
    func generatePredictions(
        for library: [ContentPiece],
        history: [ExperimentTracker.Experiment]
    ) -> [Prediction] {
        isGenerating = true
        defer { isGenerating = false }

        var results: [Prediction] = []

        // 1. Optimal post time predictions
        let timeWindows = getOptimalPostingWindows(count: ENVIBrainConfig.optimalPostingWindows)
        if let bestWindow = timeWindows.first {
            results.append(Prediction(
                type: .optimalPostTime,
                title: "Peak Engagement Window Detected",
                description: "Your audience is most active during this window. Schedule your next post here for maximum reach.",
                confidence: bestWindow.confidence,
                predictedEngagement: EngagementForecast(
                    predictedViews: 8500,
                    predictedLikes: 1200,
                    predictedShares: 180,
                    predictedComments: 65,
                    engagementRate: 0.042
                ),
                suggestedDate: bestWindow.date,
                suggestedPlatform: "instagram",
                suggestedContentType: "reel",
                reasoning: "Analysis of your last \(ENVIBrainConfig.evaluationWindowDays) days shows this time window consistently drives 47% higher engagement than your average posting time.",
                priority: .high
            ))
        }

        // 2. Content gap detection
        let contentTypes = Dictionary(grouping: library.filter { !$0.isFuture }, by: { $0.type })
        for type in ContentType.allCases {
            let pieces = contentTypes[type] ?? []
            let latestDate = pieces.map { $0.createdAt }.max()
            let daysSince = latestDate.map { Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 0 } ?? 999

            if daysSince > ENVIBrainConfig.contentGapAlertDays {
                results.append(Prediction(
                    type: .contentGap,
                    title: "Content Gap: No \(type.label) in \(daysSince) Days",
                    description: "Your audience expects \(type.label.lowercased()) content. Going \(daysSince) days without it may impact engagement.",
                    confidence: min(0.95, 0.5 + Double(daysSince) * 0.03),
                    predictedEngagement: EngagementForecast(
                        predictedViews: 5000,
                        predictedLikes: 700,
                        predictedShares: 90,
                        predictedComments: 35,
                        engagementRate: 0.035
                    ),
                    suggestedDate: Date().addingTimeInterval(86400),
                    suggestedPlatform: pieces.first?.platform.rawValue ?? "instagram",
                    suggestedContentType: type.rawValue,
                    reasoning: "Your \(type.label.lowercased()) posts drive significant engagement. A \(daysSince)-day gap historically correlates with a 20% follower engagement drop.",
                    priority: daysSince > 14 ? .critical : .high
                ))
            }
        }

        // 3. Trend opportunity (mock — in production, powered by API)
        results.append(Prediction(
            type: .trendOpportunity,
            title: "Trending: Short-Form Behind-the-Scenes",
            description: "BTS content is surging across platforms. Your studio content historically outperforms by 2.3x when framed as behind-the-scenes.",
            confidence: 0.78,
            predictedEngagement: EngagementForecast(
                predictedViews: 15000,
                predictedLikes: 2100,
                predictedShares: 450,
                predictedComments: 120,
                engagementRate: 0.052
            ),
            suggestedDate: Date().addingTimeInterval(86400 * 2),
            suggestedPlatform: "tiktok",
            suggestedContentType: "video",
            reasoning: "BTS content across your niche is up 34% this week. Your content-4 (Behind the Scenes — Studio) hit 34.5K views, your 2nd best performer. Ride the wave.",
            priority: .high
        ))

        // 4. Important date
        results.append(Prediction(
            type: .importantDate,
            title: "Upcoming: National Coffee Day (Apr 1)",
            description: "High-engagement cultural moment. Brands in your category saw 3x engagement spikes last year.",
            confidence: 0.91,
            predictedEngagement: EngagementForecast(
                predictedViews: 12000,
                predictedLikes: 1800,
                predictedShares: 340,
                predictedComments: 95,
                engagementRate: 0.048
            ),
            suggestedDate: makeDateFromComponents(month: 4, day: 1),
            suggestedPlatform: "instagram",
            suggestedContentType: "photo",
            reasoning: "National Coffee Day generated 2.1M Instagram posts last year. Early posting (7–9am) captures peak interest. Lifestyle photo format aligns with your brand aesthetic.",
            priority: .medium
        ))

        // 5. Collaboration suggestion
        if let topCollab = library.first(where: { $0.tags.contains("collab") }) {
            results.append(Prediction(
                type: .collaborationSuggestion,
                title: "Collaboration Opportunity",
                description: "Your last collab post drove exceptional engagement. Cross-posting with partners in your niche drives mutual audience growth.",
                confidence: 0.74,
                predictedEngagement: EngagementForecast(
                    predictedViews: Int(Double(topCollab.metrics?.views ?? 5000) * 1.15),
                    predictedLikes: Int(Double(topCollab.metrics?.likes ?? 800) * 1.1),
                    predictedShares: Int(Double(topCollab.metrics?.shares ?? 200) * 1.2),
                    predictedComments: Int(Double(topCollab.metrics?.comments ?? 50) * 1.15),
                    engagementRate: 0.045
                ),
                suggestedDate: Date().addingTimeInterval(86400 * 5),
                suggestedPlatform: topCollab.platform.rawValue,
                suggestedContentType: "carousel",
                reasoning: "Your last collab (Mar 8) drove \(topCollab.metrics?.views ?? 0) views and \(topCollab.metrics?.comments ?? 0) comments — your highest engagement that week.",
                priority: .medium
            ))
        }

        // Filter by confidence threshold
        let filtered = results.filter { $0.confidence >= ENVIBrainConfig.minConfidenceThreshold }
        let sorted = filtered.sorted { $0.priority > $1.priority }

        predictions = sorted
        return sorted
    }

    /// Predict engagement for a specific content piece at a given time and platform.
    ///
    /// This is a point estimate — "if you post THIS content at THIS time on THIS platform,
    /// here's what we expect." Used by the UI to show predicted engagement on future
    /// content pieces in the timeline.
    func predictEngagement(
        for piece: ContentPiece,
        at date: Date,
        on platform: String
    ) -> EngagementForecast {
        // Base engagement derived from historical performance of similar content
        let baseViews = piece.metrics?.views ?? 5000
        let baseLikes = piece.metrics?.likes ?? 700
        let baseShares = piece.metrics?.shares ?? 100
        let baseComments = piece.metrics?.comments ?? 40

        // Time-of-day multiplier (mock — in production, learned from user's data)
        let hour = Calendar.current.component(.hour, from: date)
        let timeMultiplier: Double
        switch hour {
        case 7...9:   timeMultiplier = 1.3   // Morning peak
        case 12...14: timeMultiplier = 1.15  // Lunch peak
        case 17...20: timeMultiplier = 1.25  // Evening peak
        default:      timeMultiplier = 0.85  // Off-peak
        }

        // Day-of-week multiplier
        let weekday = Calendar.current.component(.weekday, from: date)
        let dayMultiplier: Double
        switch weekday {
        case 1: dayMultiplier = 0.9   // Sunday
        case 4: dayMultiplier = 1.2   // Wednesday
        case 5: dayMultiplier = 1.15  // Thursday
        case 6: dayMultiplier = 1.1   // Friday
        default: dayMultiplier = 1.0
        }

        let multiplier = timeMultiplier * dayMultiplier
        let predictedViews = Int(Double(baseViews) * multiplier)
        let predictedLikes = Int(Double(baseLikes) * multiplier)
        let predictedShares = Int(Double(baseShares) * multiplier)
        let predictedComments = Int(Double(baseComments) * multiplier)
        let totalEngagement = predictedLikes + predictedShares + predictedComments
        let engagementRate = predictedViews > 0 ? Double(totalEngagement) / Double(predictedViews) : 0.0

        return EngagementForecast(
            predictedViews: predictedViews,
            predictedLikes: predictedLikes,
            predictedShares: predictedShares,
            predictedComments: predictedComments,
            engagementRate: engagementRate
        )
    }

    /// Returns the top N optimal posting windows with confidence scores.
    ///
    /// Like autoresearch scanning the training log for the best hyperparameter
    /// configurations, this scans the user's posting history for the time slots
    /// that consistently produce the highest engagement.
    func getOptimalPostingWindows(count: Int) -> [(date: Date, confidence: Double)] {
        // Mock implementation — in production, this analyzes real posting history
        // and uses the learned engagement-by-hour/day patterns.
        let calendar = Calendar.current
        let now = Date()
        var windows: [(date: Date, confidence: Double)] = []

        // Generate windows for the next 7 days
        for dayOffset in 1...7 {
            guard let baseDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }

            // Wednesday 2pm — historically best
            if calendar.component(.weekday, from: baseDate) == 4 {
                let window = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: baseDate) ?? baseDate
                windows.append((window, 0.92))
            }
            // Thursday 5pm — second best
            if calendar.component(.weekday, from: baseDate) == 5 {
                let window = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: baseDate) ?? baseDate
                windows.append((window, 0.87))
            }
            // Friday 12pm — lunch spike
            if calendar.component(.weekday, from: baseDate) == 6 {
                let window = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: baseDate) ?? baseDate
                windows.append((window, 0.81))
            }
            // Tuesday 8am — morning audience
            if calendar.component(.weekday, from: baseDate) == 3 {
                let window = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: baseDate) ?? baseDate
                windows.append((window, 0.76))
            }
            // Saturday 10am — weekend leisure
            if calendar.component(.weekday, from: baseDate) == 7 {
                let window = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: baseDate) ?? baseDate
                windows.append((window, 0.69))
            }
        }

        return Array(windows.sorted { $0.confidence > $1.confidence }.prefix(count))
    }

    // MARK: - Helpers

    private func makeDateFromComponents(month: Int, day: Int) -> Date {
        var components = Calendar.current.dateComponents([.year], from: Date())
        components.month = month
        components.day = day
        components.hour = 9
        return Calendar.current.date(from: components) ?? Date()
    }
}
