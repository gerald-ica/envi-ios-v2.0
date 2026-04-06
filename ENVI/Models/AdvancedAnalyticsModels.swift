import Foundation

// MARK: - Performance Report

/// A comprehensive performance report across platforms over a date range.
struct PerformanceReport: Identifiable {
    let id: UUID
    let dateRange: DateInterval
    let platforms: [SocialPlatform]
    let metrics: [MetricDataPoint]
    let summary: String

    init(
        id: UUID = UUID(),
        dateRange: DateInterval,
        platforms: [SocialPlatform],
        metrics: [MetricDataPoint],
        summary: String
    ) {
        self.id = id
        self.dateRange = dateRange
        self.platforms = platforms
        self.metrics = metrics
        self.summary = summary
    }
}

/// A single metric value tied to a date and platform.
struct MetricDataPoint: Identifiable {
    let id: UUID
    let date: Date
    let value: Double
    let platform: SocialPlatform

    init(id: UUID = UUID(), date: Date, value: Double, platform: SocialPlatform) {
        self.id = id
        self.date = date
        self.value = value
        self.platform = platform
    }
}

// MARK: - Audience Demographics

/// Breakdown of an audience segment by age, gender, or location.
struct AudienceDemographic: Identifiable {
    let id: UUID
    let ageRange: String
    let gender: String
    let location: String
    let percentage: Double

    init(
        id: UUID = UUID(),
        ageRange: String,
        gender: String,
        location: String,
        percentage: Double
    ) {
        self.id = id
        self.ageRange = ageRange
        self.gender = gender
        self.location = location
        self.percentage = percentage
    }
}

// MARK: - Content Performance

/// Performance metrics for a single piece of content.
struct ContentPerformance: Identifiable {
    let id: UUID
    let contentID: String
    let title: String
    let platform: SocialPlatform
    let impressions: Int
    let reach: Int
    let engagement: Int
    let saves: Int
    let shares: Int
    let comments: Int
    let clickRate: Double

    init(
        id: UUID = UUID(),
        contentID: String,
        title: String,
        platform: SocialPlatform,
        impressions: Int,
        reach: Int,
        engagement: Int,
        saves: Int,
        shares: Int,
        comments: Int,
        clickRate: Double
    ) {
        self.id = id
        self.contentID = contentID
        self.title = title
        self.platform = platform
        self.impressions = impressions
        self.reach = reach
        self.engagement = engagement
        self.saves = saves
        self.shares = shares
        self.comments = comments
        self.clickRate = clickRate
    }
}

// MARK: - Post Time Analysis

/// Engagement statistics for a specific day-of-week and hour combination.
struct PostTimeAnalysis: Identifiable {
    let id: UUID
    let dayOfWeek: Int      // 0 = Sunday, 6 = Saturday
    let hour: Int           // 0–23
    let avgEngagement: Double
    let postCount: Int

    init(id: UUID = UUID(), dayOfWeek: Int, hour: Int, avgEngagement: Double, postCount: Int) {
        self.id = id
        self.dayOfWeek = dayOfWeek
        self.hour = hour
        self.avgEngagement = avgEngagement
        self.postCount = postCount
    }

    /// Short day label (Mon, Tue, ...).
    var dayLabel: String {
        switch dayOfWeek {
        case 0: return "Sun"
        case 1: return "Mon"
        case 2: return "Tue"
        case 3: return "Wed"
        case 4: return "Thu"
        case 5: return "Fri"
        case 6: return "Sat"
        default: return "?"
        }
    }
}

// MARK: - Funnel Step

/// A single step in a conversion funnel.
struct FunnelStep: Identifiable {
    let id: UUID
    let name: String
    let count: Int
    let dropoffRate: Double

    init(id: UUID = UUID(), name: String, count: Int, dropoffRate: Double) {
        self.id = id
        self.name = name
        self.count = count
        self.dropoffRate = dropoffRate
    }
}

// MARK: - Comparison Period

/// Period-over-period comparison of a metric.
struct ComparisonPeriod: Identifiable {
    let id: UUID
    let metricName: String
    let current: Double
    let previous: Double
    let changePercent: Double

    init(id: UUID = UUID(), metricName: String, current: Double, previous: Double, changePercent: Double) {
        self.id = id
        self.metricName = metricName
        self.current = current
        self.previous = previous
        self.changePercent = changePercent
    }

    var isPositive: Bool { changePercent >= 0 }
}

// MARK: - Mock Data

extension PerformanceReport {
    static let mock: PerformanceReport = {
        let cal = Calendar.current
        let now = Date()
        let start = cal.date(byAdding: .day, value: -30, to: now) ?? now
        let platforms: [SocialPlatform] = [.instagram, .tiktok, .youtube]

        var metrics: [MetricDataPoint] = []
        for dayOffset in 0..<30 {
            let date = cal.date(byAdding: .day, value: -dayOffset, to: now) ?? now
            for platform in platforms {
                let base: Double = platform == .instagram ? 3200 : (platform == .tiktok ? 5800 : 1400)
                let noise = Double.random(in: -500...500)
                metrics.append(MetricDataPoint(date: date, value: base + noise, platform: platform))
            }
        }

        return PerformanceReport(
            dateRange: DateInterval(start: start, end: now),
            platforms: platforms,
            metrics: metrics,
            summary: "Overall engagement up 18% vs previous period. TikTok leads with 5.8K avg daily impressions."
        )
    }()
}

extension AudienceDemographic {
    static let mock: [AudienceDemographic] = [
        AudienceDemographic(ageRange: "18–24", gender: "Female", location: "United States", percentage: 32),
        AudienceDemographic(ageRange: "25–34", gender: "Female", location: "United States", percentage: 28),
        AudienceDemographic(ageRange: "18–24", gender: "Male", location: "United Kingdom", percentage: 14),
        AudienceDemographic(ageRange: "25–34", gender: "Male", location: "Canada", percentage: 11),
        AudienceDemographic(ageRange: "35–44", gender: "Female", location: "Australia", percentage: 8),
        AudienceDemographic(ageRange: "35–44", gender: "Male", location: "Germany", percentage: 4),
        AudienceDemographic(ageRange: "45+", gender: "Female", location: "France", percentage: 3),
    ]
}

extension ContentPerformance {
    static let mock: [ContentPerformance] = [
        ContentPerformance(contentID: "c1", title: "Summer Lookbook 2024", platform: .instagram, impressions: 124_500, reach: 98_200, engagement: 8_400, saves: 2_100, shares: 1_200, comments: 340, clickRate: 3.2),
        ContentPerformance(contentID: "c2", title: "Get Ready With Me", platform: .tiktok, impressions: 310_000, reach: 245_000, engagement: 24_300, saves: 4_500, shares: 6_800, comments: 1_100, clickRate: 5.1),
        ContentPerformance(contentID: "c3", title: "Behind the Scenes Vlog", platform: .youtube, impressions: 58_000, reach: 42_000, engagement: 3_200, saves: 800, shares: 450, comments: 210, clickRate: 2.8),
        ContentPerformance(contentID: "c4", title: "Morning Routine", platform: .tiktok, impressions: 198_000, reach: 156_000, engagement: 15_600, saves: 3_200, shares: 4_100, comments: 780, clickRate: 4.4),
        ContentPerformance(contentID: "c5", title: "Q&A Reel", platform: .instagram, impressions: 87_300, reach: 71_000, engagement: 5_900, saves: 1_400, shares: 890, comments: 420, clickRate: 2.9),
    ]
}

extension PostTimeAnalysis {
    static let mock: [PostTimeAnalysis] = {
        var items: [PostTimeAnalysis] = []
        for day in 0..<7 {
            for hour in stride(from: 6, through: 22, by: 2) {
                let isWeekday = (1...5).contains(day)
                let isPeak = (9...11).contains(hour) || (17...20).contains(hour)
                let base: Double = isWeekday && isPeak ? 4200 : (isPeak ? 3100 : 1200)
                let noise = Double.random(in: -300...300)
                let posts = isPeak ? Int.random(in: 3...8) : Int.random(in: 0...3)
                items.append(PostTimeAnalysis(dayOfWeek: day, hour: hour, avgEngagement: max(0, base + noise), postCount: posts))
            }
        }
        return items
    }()
}

extension FunnelStep {
    static let mock: [FunnelStep] = [
        FunnelStep(name: "Profile Views", count: 12_400, dropoffRate: 0),
        FunnelStep(name: "Link Clicks", count: 3_800, dropoffRate: 69.4),
        FunnelStep(name: "Sign-ups", count: 940, dropoffRate: 75.3),
        FunnelStep(name: "Purchases", count: 210, dropoffRate: 77.7),
    ]
}

extension ComparisonPeriod {
    static let mock: [ComparisonPeriod] = [
        ComparisonPeriod(metricName: "Impressions", current: 580_000, previous: 492_000, changePercent: 17.9),
        ComparisonPeriod(metricName: "Engagement", current: 24_300, previous: 21_100, changePercent: 15.2),
        ComparisonPeriod(metricName: "Followers", current: 1_240, previous: 1_380, changePercent: -10.1),
        ComparisonPeriod(metricName: "Click Rate", current: 3.8, previous: 3.2, changePercent: 18.8),
    ]
}
