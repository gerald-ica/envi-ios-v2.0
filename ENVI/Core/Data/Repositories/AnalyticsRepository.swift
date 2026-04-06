import Foundation

protocol AnalyticsRepository {
    func fetchDashboard() async throws -> AnalyticsData
    func fetchCreatorGrowth() async throws -> CreatorGrowthSnapshot
    func fetchRetentionCohorts() async throws -> [RetentionCohort]
    func fetchAttribution() async throws -> [SourceAttribution]
}

final class MockAnalyticsRepository: AnalyticsRepository {
    func fetchDashboard() async throws -> AnalyticsData {
        AnalyticsData.mock
    }

    func fetchCreatorGrowth() async throws -> CreatorGrowthSnapshot {
        .mock
    }

    func fetchRetentionCohorts() async throws -> [RetentionCohort] {
        RetentionCohort.mock
    }

    func fetchAttribution() async throws -> [SourceAttribution] {
        SourceAttribution.mock
    }
}

final class APIAnalyticsRepository: AnalyticsRepository {
    func fetchDashboard() async throws -> AnalyticsData {
        let response: AnalyticsDashboardResponse = try await APIClient.shared.request(
            endpoint: "analytics/dashboard",
            method: .get,
            requiresAuth: true
        )
        return response.toDomain()
    }

    func fetchCreatorGrowth() async throws -> CreatorGrowthSnapshot {
        let response: CreatorGrowthResponse = try await APIClient.shared.request(
            endpoint: "analytics/growth",
            method: .get,
            requiresAuth: true
        )
        return response.toDomain()
    }

    func fetchRetentionCohorts() async throws -> [RetentionCohort] {
        let response: [RetentionCohortResponse] = try await APIClient.shared.request(
            endpoint: "analytics/cohorts",
            method: .get,
            requiresAuth: true
        )
        return response.map { $0.toDomain() }
    }

    func fetchAttribution() async throws -> [SourceAttribution] {
        let response: [SourceAttributionResponse] = try await APIClient.shared.request(
            endpoint: "analytics/attribution",
            method: .get,
            requiresAuth: true
        )
        return response.map { $0.toDomain() }
    }
}

enum AnalyticsRepositoryProvider {
    static var shared = Shared(repository: defaultRepository())

    struct Shared {
        var repository: AnalyticsRepository
    }

    private static func defaultRepository() -> AnalyticsRepository {
        switch AppEnvironment.current {
        case .dev:
            return MockAnalyticsRepository()
        case .staging, .prod:
            return APIAnalyticsRepository()
        }
    }
}

private struct CreatorGrowthResponse: Decodable {
    let followerGrowthPercent: Double
    let netNewFollowers: Int
    let weeklyRetentionPercent: Double
    let topPerformingPlatform: String
    let channels: [ChannelGrowthResponse]

    func toDomain() -> CreatorGrowthSnapshot {
        CreatorGrowthSnapshot(
            followerGrowthPercent: followerGrowthPercent,
            netNewFollowers: netNewFollowers,
            weeklyRetentionPercent: weeklyRetentionPercent,
            topPerformingPlatform: SocialPlatform(rawValue: topPerformingPlatform) ?? .instagram,
            channels: channels.map { $0.toDomain() }
        )
    }
}

private struct ChannelGrowthResponse: Decodable {
    let platform: String
    let netFollowers: Int
    let growthPercent: Double

    func toDomain() -> ChannelGrowth {
        ChannelGrowth(
            platform: SocialPlatform(rawValue: platform) ?? .instagram,
            netFollowers: netFollowers,
            growthPercent: growthPercent
        )
    }
}

private struct AnalyticsDashboardResponse: Decodable {
    let reach: KPIResponse
    let engagement: KPIResponse
    let engagementRate: KPIResponse
    let dailyEngagement: [DailyMetricResponse]
    let calendarDays: [CalendarDayResponse]

    func toDomain() -> AnalyticsData {
        AnalyticsData(
            reach: reach.toDomain(),
            engagement: engagement.toDomain(),
            engagementRate: engagementRate.toDomain(),
            dailyEngagement: dailyEngagement.map { $0.toDomain() },
            calendarDays: calendarDays.map { $0.toDomain() }
        )
    }
}

private struct KPIResponse: Decodable {
    let label: String
    let value: String
    let change: String
    let isPositive: Bool

    func toDomain() -> AnalyticsData.KPI {
        AnalyticsData.KPI(label: label, value: value, change: change, isPositive: isPositive)
    }
}

private struct DailyMetricResponse: Decodable {
    let day: String
    let value: Double

    func toDomain() -> AnalyticsData.DailyMetric {
        AnalyticsData.DailyMetric(day: day, value: value)
    }
}

private struct CalendarDayResponse: Decodable {
    let date: String
    let hasContent: Bool
    let platform: String?

    func toDomain() -> AnalyticsData.CalendarDay {
        let parsedDate = ISO8601DateFormatter().date(from: date) ?? Date()
        let socialPlatform = platform.flatMap(SocialPlatform.init(rawValue:))
        return AnalyticsData.CalendarDay(
            date: parsedDate,
            hasContent: hasContent,
            platform: socialPlatform
        )
    }
}

private struct RetentionCohortResponse: Decodable {
    let weekLabel: String
    let cohortSize: Int
    let retainedPercent: Double
    let platform: String?

    func toDomain() -> RetentionCohort {
        RetentionCohort(
            weekLabel: weekLabel,
            cohortSize: cohortSize,
            retainedPercent: retainedPercent,
            platform: platform.flatMap(SocialPlatform.init(rawValue:))
        )
    }
}

private struct SourceAttributionResponse: Decodable {
    let source: String
    let channel: String?
    let visitors: Int
    let conversions: Int
    let conversionRate: Double

    func toDomain() -> SourceAttribution {
        SourceAttribution(
            source: source,
            channel: channel,
            visitors: visitors,
            conversions: conversions,
            conversionRate: conversionRate
        )
    }
}
