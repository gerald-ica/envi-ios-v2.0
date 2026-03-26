import Foundation
import Combine

// MARK: - Trend Forecaster

/// Forecasts engagement trends, identifies optimal posting times,
/// and detects upcoming opportunities (holidays, events, trending topics).
///
/// In karpathy/autoresearch, the agent reads the training log and code to
/// identify promising directions for the next experiment. The TrendForecaster
/// is ENVI's forward-looking equivalent — it reads the content landscape
/// (both the user's history and external signals) to identify where the
/// next opportunity lies.
///
/// While the ContentAnalyzer looks backward ("what happened?"), the
/// TrendForecaster looks forward ("what's coming?"). Together they
/// inform the PredictionEngine's hypotheses.
///
/// In the autoresearch loop:
/// > "If you feel like you're getting stuck, try combining previous near-misses,
/// >  try more radical architectural changes."
///
/// The TrendForecaster embodies this spirit — it identifies new angles,
/// upcoming events, and trend shifts that the user's current strategy
/// might be missing.
final class TrendForecaster: ObservableObject {

    // MARK: - Types

    /// A forecasted event or opportunity on the horizon.
    struct ForecastedEvent: Identifiable, Codable {
        let id: UUID
        let title: String
        let date: Date
        let category: EventCategory
        let relevanceScore: Double          // 0.0–1.0, how relevant to this user
        let suggestedContent: String        // What to post for this event
        let predictedImpact: String         // "Expected +45% engagement"
        let platform: String?               // Suggested platform, if specific

        init(
            id: UUID = UUID(),
            title: String,
            date: Date,
            category: EventCategory,
            relevanceScore: Double,
            suggestedContent: String,
            predictedImpact: String,
            platform: String? = nil
        ) {
            self.id = id
            self.title = title
            self.date = date
            self.category = category
            self.relevanceScore = relevanceScore
            self.suggestedContent = suggestedContent
            self.predictedImpact = predictedImpact
            self.platform = platform
        }
    }

    /// Categories of upcoming events.
    enum EventCategory: String, Codable, CaseIterable {
        case holiday              // Cultural/national holiday
        case trendingTopic        // Currently trending on social platforms
        case audiencePeak         // Predicted audience activity spike
        case contentMilestone     // User's milestone (100th post, 1-year anniversary)
        case platformUpdate       // Platform algorithm change or new feature
        case seasonalOpportunity  // Seasonal content opportunity
    }

    /// A single slot in an optimal posting schedule.
    struct ScheduleSlot: Identifiable, Codable {
        let id: UUID
        let date: Date
        let suggestedContentType: String
        let platform: String
        let confidence: Double
        let reasoning: String

        init(
            id: UUID = UUID(),
            date: Date,
            suggestedContentType: String,
            platform: String,
            confidence: Double,
            reasoning: String
        ) {
            self.id = id
            self.date = date
            self.suggestedContentType = suggestedContentType
            self.platform = platform
            self.confidence = confidence
            self.reasoning = reasoning
        }
    }

    /// A detected trending opportunity.
    struct TrendOpportunity: Identifiable {
        let id = UUID()
        let topic: String
        let platform: String
        let trendStrength: Double           // 0.0–1.0
        let windowRemaining: TimeInterval   // Seconds until trend fades
        let suggestedAction: String
        let urgency: TrendUrgency
    }

    enum TrendUrgency: String, CaseIterable {
        case immediate  // Act now — trend peaks in < 24h
        case soon       // Act within 2–3 days
        case upcoming   // Trend is building, 5–7 day window
    }

    // MARK: - Published State

    @Published var upcomingEvents: [ForecastedEvent] = []
    @Published var trendOpportunities: [TrendOpportunity] = []
    @Published var weeklySchedule: [ScheduleSlot] = []

    // MARK: - Core Methods

    /// Forecast daily engagement rates for the next N days.
    ///
    /// Returns a dictionary mapping each future date to a predicted
    /// engagement rate. This powers the timeline visualization — showing
    /// the user where their engagement is headed if they follow (or ignore)
    /// the Brain's recommendations.
    func forecastEngagement(days: Int) -> [Date: Double] {
        let calendar = Calendar.current
        let now = Date()
        var forecast: [Date: Double] = [:]

        // Base engagement rate from recent history (mock)
        let baseRate = 0.042

        for dayOffset in 1...days {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let weekday = calendar.component(.weekday, from: date)

            // Day-of-week modifier
            let dayModifier: Double
            switch weekday {
            case 1: dayModifier = 0.85   // Sunday
            case 4: dayModifier = 1.25   // Wednesday peak
            case 5: dayModifier = 1.15   // Thursday
            case 6: dayModifier = 1.10   // Friday
            default: dayModifier = 1.0
            }

            // Trend modifier (slight upward trend for active creators)
            let trendModifier = 1.0 + Double(dayOffset) * 0.002

            // Noise (small random variation for realism)
            let noise = 1.0 + (Double(dayOffset.hashValue % 100) / 1000.0 - 0.05)

            forecast[date] = baseRate * dayModifier * trendModifier * noise
        }

        return forecast
    }

    /// Get upcoming events relevant to the user.
    ///
    /// Combines:
    /// - Known holidays/cultural moments
    /// - Detected trending topics (in production, from platform APIs)
    /// - User-specific milestones (post count, anniversary)
    /// - Seasonal opportunities
    ///
    /// This is one of the ENVI Brain's key differentiators from generic
    /// scheduling tools — it proactively surfaces opportunities the user
    /// might not be tracking.
    func getUpcomingEvents(count: Int) -> [ForecastedEvent] {
        let calendar = Calendar.current
        let now = Date()

        var events: [ForecastedEvent] = []

        // Cultural holidays and brand moments (next 30 days)
        let holidays: [(String, Int, Int, String, String)] = [
            ("National Coffee Day", 4, 1, "Lifestyle photo tying your brand to the cultural moment", "Expected +45% engagement — 2.1M posts last year"),
            ("Earth Day", 4, 22, "Sustainability-focused content showcasing eco-friendly practices", "High relevance — sustainability content up 60% YoY"),
            ("World Creativity Day", 4, 21, "Behind-the-scenes creative process showcase", "Strong fit for your brand — creative process content is your top performer"),
        ]

        for (name, month, day, suggestion, impact) in holidays {
            var components = calendar.dateComponents([.year], from: now)
            components.month = month
            components.day = day
            guard let date = calendar.date(from: components),
                  date > now,
                  date < calendar.date(byAdding: .day, value: 30, to: now) ?? now
            else { continue }

            events.append(ForecastedEvent(
                title: name,
                date: date,
                category: .holiday,
                relevanceScore: 0.85,
                suggestedContent: suggestion,
                predictedImpact: impact,
                platform: "instagram"
            ))
        }

        // Trending topic opportunities (mock — in production from APIs)
        events.append(ForecastedEvent(
            title: "Trending: AI-Generated Art Backlash Discussion",
            date: now.addingTimeInterval(86400),
            category: .trendingTopic,
            relevanceScore: 0.72,
            suggestedContent: "Share your perspective on AI in creative work — authentic creator voices are amplified in this discourse",
            predictedImpact: "Thought-leadership content during trending conversations sees 3x engagement",
            platform: "twitter"
        ))

        // Audience peak prediction
        if let nextWednesday = nextWeekday(4, from: now) {
            events.append(ForecastedEvent(
                title: "Predicted Audience Peak",
                date: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: nextWednesday) ?? nextWednesday,
                category: .audiencePeak,
                relevanceScore: 0.93,
                suggestedContent: "Post your highest-impact content here — reel or carousel format recommended",
                predictedImpact: "+47% engagement vs. average posting time"
            ))
        }

        // Content milestone
        events.append(ForecastedEvent(
            title: "Milestone: 50th Post This Quarter",
            date: now.addingTimeInterval(86400 * 5),
            category: .contentMilestone,
            relevanceScore: 0.68,
            suggestedContent: "Celebrate with a retrospective carousel or Q&A story — milestones drive community engagement",
            predictedImpact: "Milestone posts average 2x saves and 1.5x comments"
        ))

        // Seasonal opportunity
        events.append(ForecastedEvent(
            title: "Spring Content Season Peak",
            date: now.addingTimeInterval(86400 * 7),
            category: .seasonalOpportunity,
            relevanceScore: 0.76,
            suggestedContent: "Outdoor shoots, fresh color palettes, renewal-themed narratives. Spring content sees peak engagement in early April.",
            predictedImpact: "Seasonal alignment boosts reach by ~25%"
        ))

        let sorted = events
            .sorted { $0.relevanceScore > $1.relevanceScore }
            .prefix(count)
            .map { $0 }

        upcomingEvents = sorted
        return sorted
    }

    /// Generate an optimal posting schedule for the given week.
    ///
    /// Like autoresearch planning which experiments to run next, this plans
    /// the user's content calendar for maximum impact. Each slot is a
    /// hypothesis: "posting X content at Y time on Z platform will achieve
    /// the best engagement."
    func getOptimalPostingSchedule(for week: Date) -> [ScheduleSlot] {
        let calendar = Calendar.current

        // Find the Monday of the given week
        let weekday = calendar.component(.weekday, from: week)
        let daysToMonday = weekday == 1 ? -6 : (2 - weekday)
        guard let monday = calendar.date(byAdding: .day, value: daysToMonday, to: week) else { return [] }

        var slots: [ScheduleSlot] = []

        // Optimal schedule based on learned patterns (mock)
        let schedule: [(dayOffset: Int, hour: Int, type: String, platform: String, confidence: Double, reason: String)] = [
            (0, 8, "photo", "instagram", 0.78, "Monday morning — strong for lifestyle and motivational content"),
            (1, 14, "video", "tiktok", 0.82, "Tuesday afternoon — TikTok algorithm favors fresh video at this window"),
            (2, 14, "reel", "instagram", 0.92, "Wednesday 2pm — your historically highest engagement window"),
            (3, 17, "carousel", "linkedin", 0.85, "Thursday evening — professional audience is most active"),
            (4, 12, "story", "instagram", 0.76, "Friday lunch — casual content performs well end-of-week"),
        ]

        for slot in schedule {
            guard let date = calendar.date(byAdding: .day, value: slot.dayOffset, to: monday),
                  let dateWithTime = calendar.date(bySettingHour: slot.hour, minute: 0, second: 0, of: date)
            else { continue }

            slots.append(ScheduleSlot(
                date: dateWithTime,
                suggestedContentType: slot.type,
                platform: slot.platform,
                confidence: slot.confidence,
                reasoning: slot.reason
            ))
        }

        weeklySchedule = slots
        return slots
    }

    /// Detect currently trending opportunities.
    ///
    /// In production, this would query platform APIs for trending hashtags,
    /// audio, and topics. For now, returns mock data showing the interface.
    func detectTrendingOpportunities() -> [TrendOpportunity] {
        let opportunities: [TrendOpportunity] = [
            TrendOpportunity(
                topic: "Behind-the-scenes studio content",
                platform: "tiktok",
                trendStrength: 0.87,
                windowRemaining: 86400 * 3,
                suggestedAction: "Create a 15-30s BTS reel showing your creative process. Use trending audio #StudioLife.",
                urgency: .soon
            ),
            TrendOpportunity(
                topic: "AI creativity tools showcase",
                platform: "twitter",
                trendStrength: 0.73,
                windowRemaining: 86400 * 5,
                suggestedAction: "Share a thread showing before/after of AI-assisted editing. Thought-leadership angle.",
                urgency: .upcoming
            ),
            TrendOpportunity(
                topic: "Spring transition aesthetic",
                platform: "instagram",
                trendStrength: 0.81,
                windowRemaining: 86400 * 7,
                suggestedAction: "Post a carousel with spring color palette and seasonal mood board. High save potential.",
                urgency: .upcoming
            ),
        ]

        trendOpportunities = opportunities
        return opportunities
    }

    // MARK: - Helpers

    /// Find the next occurrence of a given weekday (1=Sunday, 2=Monday, etc.)
    private func nextWeekday(_ target: Int, from date: Date) -> Date? {
        let calendar = Calendar.current
        let current = calendar.component(.weekday, from: date)
        let daysAhead = (target - current + 7) % 7
        let offset = daysAhead == 0 ? 7 : daysAhead
        return calendar.date(byAdding: .day, value: offset, to: date)
    }
}
