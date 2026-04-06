import Foundation

// MARK: - Industry Category

/// Categories for benchmark comparison.
enum IndustryCategory: String, CaseIterable, Codable, Identifiable {
    case fashion
    case beauty
    case fitness
    case food
    case travel
    case tech
    case lifestyle
    case education
    case entertainment
    case business

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fashion:       return "Fashion"
        case .beauty:        return "Beauty"
        case .fitness:       return "Fitness"
        case .food:          return "Food & Beverage"
        case .travel:        return "Travel"
        case .tech:          return "Tech"
        case .lifestyle:     return "Lifestyle"
        case .education:     return "Education"
        case .entertainment: return "Entertainment"
        case .business:      return "Business"
        }
    }
}

// MARK: - Benchmark

/// A single benchmark metric comparing user performance to industry data.
struct Benchmark: Identifiable {
    let id: UUID
    let metric: String
    let userValue: Double
    let industryAvg: Double
    let topPerformer: Double
    let percentile: Int

    init(
        id: UUID = UUID(),
        metric: String,
        userValue: Double,
        industryAvg: Double,
        topPerformer: Double,
        percentile: Int
    ) {
        self.id = id
        self.metric = metric
        self.userValue = userValue
        self.industryAvg = industryAvg
        self.topPerformer = topPerformer
        self.percentile = percentile
    }
}

// MARK: - Trend Direction

/// Direction a trend signal is moving.
enum TrendDirection: String, Codable {
    case up
    case down
    case stable
}

// MARK: - Impact Level

/// Impact level for insight cards.
enum ImpactLevel: String, Codable, CaseIterable {
    case high
    case medium
    case low

    var displayName: String { rawValue.capitalized }
}

// MARK: - Insight Card

/// An actionable insight derived from analytics data.
struct InsightCard: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let actionableAdvice: String
    let impact: ImpactLevel
    let confidence: Double

    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        actionableAdvice: String,
        impact: ImpactLevel,
        confidence: Double
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.actionableAdvice = actionableAdvice
        self.impact = impact
        self.confidence = confidence
    }
}

// MARK: - Trend Signal

/// A trending topic or content signal across platforms.
struct TrendSignal: Identifiable {
    let id: UUID
    let topic: String
    let momentum: Double
    let direction: TrendDirection
    let platforms: [SocialPlatform]
    let timeframe: String

    init(
        id: UUID = UUID(),
        topic: String,
        momentum: Double,
        direction: TrendDirection,
        platforms: [SocialPlatform],
        timeframe: String
    ) {
        self.id = id
        self.topic = topic
        self.momentum = momentum
        self.direction = direction
        self.platforms = platforms
        self.timeframe = timeframe
    }
}

// MARK: - Weekly Digest

/// A weekly summary of creator performance, highlights, and recommendations.
struct WeeklyDigest: Identifiable {
    var id: Date { weekStarting }

    let weekStarting: Date
    let highlights: [String]
    let topContent: [ContentPerformance]
    let keyMetrics: [Benchmark]
    let recommendations: [String]

    init(
        weekStarting: Date,
        highlights: [String],
        topContent: [ContentPerformance],
        keyMetrics: [Benchmark],
        recommendations: [String]
    ) {
        self.weekStarting = weekStarting
        self.highlights = highlights
        self.topContent = topContent
        self.keyMetrics = keyMetrics
        self.recommendations = recommendations
    }
}

// MARK: - Mock Data

extension Benchmark {
    static let mock: [Benchmark] = [
        Benchmark(metric: "Engagement Rate", userValue: 4.2, industryAvg: 3.1, topPerformer: 7.8, percentile: 72),
        Benchmark(metric: "Follower Growth", userValue: 2.8, industryAvg: 1.5, topPerformer: 6.2, percentile: 81),
        Benchmark(metric: "Avg. Reach", userValue: 12400, industryAvg: 8900, topPerformer: 34000, percentile: 65),
        Benchmark(metric: "Save Rate", userValue: 1.9, industryAvg: 1.2, topPerformer: 4.5, percentile: 68),
        Benchmark(metric: "Share Rate", userValue: 0.8, industryAvg: 0.6, topPerformer: 2.1, percentile: 59),
        Benchmark(metric: "Story Completion", userValue: 78, industryAvg: 65, topPerformer: 92, percentile: 74),
    ]
}

extension InsightCard {
    static let mock: [InsightCard] = [
        InsightCard(
            title: "Carousel posts outperform singles",
            description: "Your carousel posts receive 2.3x more engagement than single-image posts over the past 30 days.",
            actionableAdvice: "Increase carousel frequency to 3-4 per week for maximum engagement lift.",
            impact: .high,
            confidence: 0.92
        ),
        InsightCard(
            title: "Optimal posting window detected",
            description: "Posts published between 6-8 PM on weekdays consistently reach 40% more followers.",
            actionableAdvice: "Schedule your next 5 posts within the 6-8 PM window to capitalize on peak activity.",
            impact: .medium,
            confidence: 0.87
        ),
        InsightCard(
            title: "Hashtag strategy refresh needed",
            description: "Your top 3 hashtags have declined in reach by 15% this month.",
            actionableAdvice: "Replace underperforming hashtags with trending alternatives in your niche.",
            impact: .medium,
            confidence: 0.78
        ),
        InsightCard(
            title: "Video content opportunity",
            description: "Short-form video adoption in your category grew 28% this quarter, but your video output is flat.",
            actionableAdvice: "Add 2 Reels or TikToks per week to capture the rising demand.",
            impact: .high,
            confidence: 0.84
        ),
    ]
}

extension TrendSignal {
    static let mock: [TrendSignal] = [
        TrendSignal(topic: "AI-generated content", momentum: 87, direction: .up, platforms: [.instagram, .tiktok], timeframe: "Past 7 days"),
        TrendSignal(topic: "Behind-the-scenes", momentum: 64, direction: .up, platforms: [.instagram, .youtube], timeframe: "Past 14 days"),
        TrendSignal(topic: "Photo dumps", momentum: 42, direction: .stable, platforms: [.instagram], timeframe: "Past 30 days"),
        TrendSignal(topic: "Long-form captions", momentum: 31, direction: .down, platforms: [.instagram, .threads], timeframe: "Past 14 days"),
        TrendSignal(topic: "Micro-tutorials", momentum: 76, direction: .up, platforms: [.tiktok, .youtube], timeframe: "Past 7 days"),
    ]
}

extension WeeklyDigest {
    static let mock = WeeklyDigest(
        weekStarting: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date(),
        highlights: [
            "Engagement rate up 12% vs. prior week",
            "Best performing post reached 24.5K accounts",
            "Follower growth accelerated by 1.4x"
        ],
        topContent: Array(ContentPerformance.mock.prefix(3)),
        keyMetrics: Array(Benchmark.mock.prefix(3)),
        recommendations: [
            "Double down on carousel content — your audience consistently saves them.",
            "Try posting a Reel during the 6-8 PM window on Wednesday for maximum reach.",
            "Engage with 10 accounts in your niche daily to boost algorithmic visibility."
        ]
    )
}
