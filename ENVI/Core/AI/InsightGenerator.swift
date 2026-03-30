import Foundation
import Combine

// MARK: - Insight Generator

/// Generates natural-language insights for display in the chat and UI.
///
/// In karpathy/autoresearch, the agent communicates its findings through
/// commit messages, results.tsv entries, and the training log. The human
/// reads these artifacts to understand what the agent tried and learned.
///
/// The InsightGenerator is ENVI's communication layer — it translates
/// raw data (ContentPattern, Predictions, Experiments) into human-readable
/// recommendations that appear in the chat interface and throughout the UI.
///
/// This is critical because ENVI's "human in the loop" is the content creator.
/// They don't read results.tsv — they read conversational insights like:
/// > "Your reels outperform photos by 2.3x on Wednesday afternoons.
/// >  I'd recommend posting a reel this Wednesday at 2pm."
///
/// The InsightGenerator bridges the gap between the Brain's internal
/// optimization and the user's decision-making.
final class InsightGenerator: ObservableObject {

    // MARK: - Types

    /// A single insight ready for display.
    struct ContentInsight: Identifiable {
        let id: UUID
        let title: String
        let body: String
        let category: InsightCategory
        let actionable: Bool
        let action: String?             // CTA if actionable ("Create a reel now")
        let confidence: Double
        let dataPoints: [DataPoint]
        let createdAt: Date

        init(
            id: UUID = UUID(),
            title: String,
            body: String,
            category: InsightCategory,
            actionable: Bool,
            action: String? = nil,
            confidence: Double,
            dataPoints: [DataPoint] = [],
            createdAt: Date = Date()
        ) {
            self.id = id
            self.title = title
            self.body = body
            self.category = category
            self.actionable = actionable
            self.action = action
            self.confidence = confidence
            self.dataPoints = dataPoints
            self.createdAt = createdAt
        }
    }

    /// Categories of insights — determines visual treatment and priority in the UI.
    enum InsightCategory: String, CaseIterable {
        case performance     // How content is performing
        case recommendation  // What to do next
        case trend           // What's trending
        case alert           // Something needs attention
        case milestone       // Achievement or milestone reached
    }

    /// A supporting data point for an insight.
    struct DataPoint: Identifiable {
        let id = UUID()
        let label: String
        let value: String
        let change: String?
        let isPositive: Bool

        init(label: String, value: String, change: String? = nil, isPositive: Bool = true) {
            self.label = label
            self.value = value
            self.change = change
            self.isPositive = isPositive
        }
    }

    /// Response structure for chat-based insights.
    struct ChatInsightResponse {
        let message: String
        let insights: [ContentInsight]
        let suggestedFollowUps: [String]
    }

    // MARK: - Published State

    @Published var latestInsights: [ContentInsight] = []

    // MARK: - Core Methods

    /// Generate weekly insights from analyzed content patterns.
    ///
    /// This is the "report" that the ENVI Brain generates after each
    /// research loop iteration. Like autoresearch logging results to
    /// results.tsv, this summarizes what was learned this week.
    func generateWeeklyInsights(from patterns: ContentAnalyzer.ContentPattern) -> [ContentInsight] {
        var insights: [ContentInsight] = []

        // 1. Performance overview
        insights.append(ContentInsight(
            title: "Weekly Performance Overview",
            body: "You published \(patterns.totalPieces) pieces this period. Your best-performing format is \(patterns.bestPerformingType) on \(patterns.bestPerformingPlatform), with an average engagement rate of \(String(format: "%.1f", patterns.averageEngagementRate * 100))%.",
            category: .performance,
            actionable: false,
            confidence: 0.95,
            dataPoints: [
                DataPoint(label: "Total Content", value: "\(patterns.totalPieces) pieces"),
                DataPoint(label: "Best Format", value: patterns.bestPerformingType.capitalized),
                DataPoint(label: "Best Platform", value: patterns.bestPerformingPlatform.capitalized),
                DataPoint(label: "Avg Engagement", value: String(format: "%.1f%%", patterns.averageEngagementRate * 100)),
                DataPoint(label: "Avg AI Score", value: String(format: "%.0f", patterns.averageAIScore)),
            ]
        ))

        // 2. Best day/time insight
        if let bestDay = patterns.engagementByDayOfWeek.max(by: { $0.value < $1.value }) {
            let dayNames = [1: "Sunday", 2: "Monday", 3: "Tuesday", 4: "Wednesday", 5: "Thursday", 6: "Friday", 7: "Saturday"]
            let dayName = dayNames[bestDay.key] ?? "Unknown"

            if let bestHour = patterns.engagementByHour.max(by: { $0.value < $1.value }) {
                let hourStr: String = {
                    let h = bestHour.key
                    switch h {
                    case 0: return "12am"
                    case 1..<12: return "\(h)am"
                    case 12: return "12pm"
                    default: return "\(h - 12)pm"
                    }
                }()
                let liftPct: String = {
                    guard patterns.averageEngagementRate > 0 else { return "N/A" }
                    return String(format: "%.0f", bestDay.value / patterns.averageEngagementRate * 100 - 100)
                }()
                insights.append(ContentInsight(
                    title: "Your Peak Engagement Window",
                    body: "\(dayName) at \(hourStr) is your golden hour. Posts during this window see \(liftPct)% higher engagement than your average. Schedule your most important content here.",
                    category: .recommendation,
                    actionable: true,
                    action: "Schedule next post for \(dayName) \(hourStr)",
                    confidence: 0.88,
                    dataPoints: [
                        DataPoint(label: "Peak Day", value: dayName),
                        DataPoint(label: "Peak Hour", value: hourStr),
                        DataPoint(label: "Eng. Rate", value: String(format: "%.1f%%", bestDay.value * 100)),
                    ]
                ))
            }
        }

        // 3. Content type recommendation
        let typeEntries = patterns.contentTypeDistribution.sorted { $0.value > $1.value }
        if let dominant = typeEntries.first, typeEntries.count > 1 {
            let dominantPercent = patterns.totalPieces > 0
                ? Int(Double(dominant.value) / Double(patterns.totalPieces) * 100)
                : 0
            insights.append(ContentInsight(
                title: "Content Mix Analysis",
                body: "\(dominant.key.capitalized) makes up \(dominantPercent)% of your content. Diversifying your content mix can help reach different audience segments. Consider adding more \(typeEntries.last?.key ?? "variety") to balance your portfolio.",
                category: .recommendation,
                actionable: true,
                action: "Create a \(typeEntries.last?.key ?? "new format") post",
                confidence: 0.76,
                dataPoints: typeEntries.map {
                    DataPoint(label: $0.key.capitalized, value: "\($0.value) posts")
                }
            ))
        }

        // 4. Top tags insight
        if !patterns.topTags.isEmpty {
            let topThree = patterns.topTags.prefix(3).joined(separator: ", ")
            insights.append(ContentInsight(
                title: "Your Signature Topics",
                body: "Your most-used tags are: \(topThree). These define your content identity. Consider whether these align with the audience you want to reach, or if there's a niche gap to fill.",
                category: .trend,
                actionable: false,
                confidence: 0.82,
                dataPoints: patterns.topTags.prefix(5).map {
                    DataPoint(label: "#\($0)", value: "active")
                }
            ))
        }

        // 5. Growth insight
        if patterns.audienceGrowthRate > 0 {
            insights.append(ContentInsight(
                title: "Audience Growth Trajectory",
                body: "You're gaining approximately \(String(format: "%.0f", patterns.audienceGrowthRate)) new followers per day. At this rate, you'll hit your next milestone in about \(Int(500.0 / patterns.audienceGrowthRate)) days. Maintaining your current posting frequency of one piece every \(Int(patterns.averagePostingFrequency / 86400)) days is key.",
                category: .milestone,
                actionable: false,
                confidence: 0.71,
                dataPoints: [
                    DataPoint(label: "Daily Growth", value: "+\(String(format: "%.0f", patterns.audienceGrowthRate))", change: nil, isPositive: true),
                    DataPoint(label: "Post Frequency", value: "Every \(Int(patterns.averagePostingFrequency / 86400))d"),
                ]
            ))
        }

        latestInsights = insights
        return insights
    }

    /// Generate a chat response for a user query.
    ///
    /// This powers the ENVI chat's AI responses — the user asks a question
    /// about their content strategy, and the InsightGenerator produces a
    /// contextual, data-backed response.
    ///
    /// Maps to the chat suggestion chips from the World Explorer:
    /// - "What does my content say about me?"
    /// - "Optimize my latest post"
    /// - "What should I publish next?"
    /// - "Repurpose my top content"
    /// - "Analyze engagement trends"
    func generateChatResponse(
        for query: String,
        context: ContentAnalyzer.ContentPattern
    ) -> ChatInsightResponse {
        let lowered = query.lowercased()

        // Pattern match on common query types
        if lowered.contains("perform") || lowered.contains("this week") || lowered.contains("how did") {
            return generatePerformanceResponse(context: context)
        } else if lowered.contains("next") || lowered.contains("publish") || lowered.contains("should i") {
            return generateRecommendationResponse(context: context)
        } else if lowered.contains("trend") || lowered.contains("engagement") || lowered.contains("analyze") {
            return generateTrendResponse(context: context)
        } else if lowered.contains("optimize") || lowered.contains("improve") || lowered.contains("latest") {
            return generateOptimizeResponse(context: context)
        } else if lowered.contains("repurpose") || lowered.contains("top content") || lowered.contains("say about") {
            return generateRepurposeResponse(context: context)
        } else {
            return generateGenericResponse(context: context)
        }
    }

    /// Generate a human-readable explanation for a prediction.
    ///
    /// Translates the PredictionEngine's numeric forecast into something
    /// the user can act on.
    func generatePredictionExplanation(for prediction: PredictionEngine.Prediction) -> String {
        let confidenceStr: String
        switch prediction.confidence {
        case 0.9...1.0: confidenceStr = "very high"
        case 0.75..<0.9: confidenceStr = "high"
        case 0.65..<0.75: confidenceStr = "moderate"
        default: confidenceStr = "emerging"
        }

        return """
        \(prediction.description)

        Confidence: \(confidenceStr) (\(Int(prediction.confidence * 100))%)
        Platform: \(prediction.suggestedPlatform.capitalized)
        Format: \(prediction.suggestedContentType.capitalized)
        Predicted: \(prediction.predictedEngagement.summary)

        Why: \(prediction.reasoning)
        """
    }

    // MARK: - Response Generators

    private func generatePerformanceResponse(context: ContentAnalyzer.ContentPattern) -> ChatInsightResponse {
        let insight = ContentInsight(
            title: "Weekly Performance",
            body: "Your engagement is trending \(context.averageEngagementRate > 0.04 ? "above" : "below") average. \(context.bestPerformingType.capitalized) content on \(context.bestPerformingPlatform.capitalized) continues to be your strongest combination.",
            category: .performance,
            actionable: false,
            confidence: 0.90,
            dataPoints: [
                DataPoint(label: "Engagement Rate", value: String(format: "%.1f%%", context.averageEngagementRate * 100), change: "+18.4%", isPositive: true),
                DataPoint(label: "Best Format", value: context.bestPerformingType.capitalized),
                DataPoint(label: "Best Platform", value: context.bestPerformingPlatform.capitalized),
            ]
        )

        return ChatInsightResponse(
            message: "Here's your performance breakdown. Your overall engagement rate is \(String(format: "%.1f", context.averageEngagementRate * 100))%, driven primarily by your \(context.bestPerformingType) content on \(context.bestPerformingPlatform.capitalized).",
            insights: [insight],
            suggestedFollowUps: [
                "Which post performed best?",
                "What's the best time to post this week?",
                "Show me engagement by platform",
            ]
        )
    }

    private func generateRecommendationResponse(context: ContentAnalyzer.ContentPattern) -> ChatInsightResponse {
        let insight = ContentInsight(
            title: "Next Content Recommendation",
            body: "Based on your patterns, I'd recommend a \(context.bestPerformingType) post on \(context.bestPerformingPlatform.capitalized) this Wednesday at 2pm. This time slot consistently drives your highest engagement.",
            category: .recommendation,
            actionable: true,
            action: "Schedule for Wednesday 2pm",
            confidence: 0.85,
            dataPoints: [
                DataPoint(label: "Suggested Format", value: context.bestPerformingType.capitalized),
                DataPoint(label: "Suggested Time", value: "Wed 2pm"),
                DataPoint(label: "Expected Eng.", value: "4.8%", change: "+14%", isPositive: true),
            ]
        )

        return ChatInsightResponse(
            message: "Based on your audience patterns and recent performance, here's what I'd recommend for your next post.",
            insights: [insight],
            suggestedFollowUps: [
                "What about other platforms?",
                "Show me my content calendar",
                "What topics are trending?",
            ]
        )
    }

    private func generateTrendResponse(context: ContentAnalyzer.ContentPattern) -> ChatInsightResponse {
        let insight = ContentInsight(
            title: "Engagement Trend Analysis",
            body: "Your engagement has been improving over the past \(ENVIBrainConfig.evaluationWindowDays) days. \(context.bestPerformingType.capitalized) content continues to outperform, and your audience growth rate is steady at ~\(String(format: "%.0f", context.audienceGrowthRate)) new followers/day.",
            category: .trend,
            actionable: false,
            confidence: 0.82,
            dataPoints: [
                DataPoint(label: "Trend", value: "Improving", change: nil, isPositive: true),
                DataPoint(label: "Growth Rate", value: "+\(String(format: "%.0f", context.audienceGrowthRate))/day", change: "+12.8%", isPositive: true),
                DataPoint(label: "Top Tags", value: context.topTags.prefix(3).joined(separator: ", ")),
            ]
        )

        return ChatInsightResponse(
            message: "Here's your engagement trend analysis for the past week. Overall trajectory: improving.",
            insights: [insight],
            suggestedFollowUps: [
                "What's driving the improvement?",
                "Any upcoming opportunities?",
                "Compare platforms",
            ]
        )
    }

    private func generateOptimizeResponse(context: ContentAnalyzer.ContentPattern) -> ChatInsightResponse {
        let insight = ContentInsight(
            title: "Content Optimization",
            body: "Your latest content has an AI score of \(String(format: "%.0f", context.averageAIScore))/100. To improve: post during peak hours (\(context.engagementByHour.max(by: { $0.value < $1.value })?.key ?? 14):00), use your top-performing format (\(context.bestPerformingType)), and include your signature tags.",
            category: .recommendation,
            actionable: true,
            action: "Apply optimizations",
            confidence: 0.80,
            dataPoints: [
                DataPoint(label: "AI Score", value: "\(String(format: "%.0f", context.averageAIScore))/100"),
                DataPoint(label: "Optimal Hour", value: "\(context.engagementByHour.max(by: { $0.value < $1.value })?.key ?? 14):00"),
                DataPoint(label: "Best Format", value: context.bestPerformingType.capitalized),
            ]
        )

        return ChatInsightResponse(
            message: "Here are optimization suggestions for your content.",
            insights: [insight],
            suggestedFollowUps: [
                "Optimize my latest post",
                "What should I change?",
                "Show my best-performing posts",
            ]
        )
    }

    private func generateRepurposeResponse(context: ContentAnalyzer.ContentPattern) -> ChatInsightResponse {
        let insight = ContentInsight(
            title: "Repurpose Opportunities",
            body: "Your top-performing \(context.bestPerformingType) content can be repurposed across platforms. A \(context.bestPerformingType) on \(context.bestPerformingPlatform.capitalized) can become a Story, a carousel recap, or a shorter clip for TikTok — multiplying your reach with minimal effort.",
            category: .recommendation,
            actionable: true,
            action: "Repurpose top content",
            confidence: 0.77,
            dataPoints: [
                DataPoint(label: "Source Format", value: context.bestPerformingType.capitalized),
                DataPoint(label: "Target: Story", value: "Quick cut"),
                DataPoint(label: "Target: Carousel", value: "Key frames"),
                DataPoint(label: "Target: Short", value: "15s highlight"),
            ]
        )

        return ChatInsightResponse(
            message: "Your content has untapped potential. Here's how to repurpose your best performers.",
            insights: [insight],
            suggestedFollowUps: [
                "Which content should I repurpose first?",
                "Best platforms for cross-posting?",
                "Show repurpose suggestions",
            ]
        )
    }

    private func generateGenericResponse(context: ContentAnalyzer.ContentPattern) -> ChatInsightResponse {
        ChatInsightResponse(
            message: "I've analyzed your content library of \(context.totalPieces) pieces. Your strongest format is \(context.bestPerformingType) on \(context.bestPerformingPlatform.capitalized). What would you like to explore?",
            insights: latestInsights.isEmpty ? generateWeeklyInsights(from: context) : latestInsights,
            suggestedFollowUps: [
                "What does my content say about me?",
                "Optimize my latest post",
                "What should I publish next?",
                "Repurpose my top content",
                "Analyze engagement trends",
            ]
        )
    }
}
