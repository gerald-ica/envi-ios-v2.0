import Foundation

protocol AnalyticsRepository {
    func fetchDashboard() async throws -> AnalyticsData
}

final class MockAnalyticsRepository: AnalyticsRepository {
    func fetchDashboard() async throws -> AnalyticsData {
        AnalyticsData.mock
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
