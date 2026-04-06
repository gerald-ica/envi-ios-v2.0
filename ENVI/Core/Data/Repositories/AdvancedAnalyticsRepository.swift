import Foundation

// MARK: - Protocol

protocol AdvancedAnalyticsRepository {
    func fetchPerformanceReport(range: DateInterval, platforms: [SocialPlatform]) async throws -> PerformanceReport
    func fetchAudienceDemographics() async throws -> [AudienceDemographic]
    func fetchContentPerformance(sortBy: ContentSortField, limit: Int) async throws -> [ContentPerformance]
    func fetchPostTimeAnalysis() async throws -> [PostTimeAnalysis]
    func fetchFunnelData() async throws -> [FunnelStep]
    func fetchPeriodComparison(current: DateInterval, previous: DateInterval) async throws -> [ComparisonPeriod]
}

/// Sort options for content performance queries.
enum ContentSortField: String {
    case impressions
    case engagement
    case saves
    case shares
    case clickRate = "click_rate"
}

// MARK: - Mock Implementation

final class MockAdvancedAnalyticsRepository: AdvancedAnalyticsRepository {
    func fetchPerformanceReport(range: DateInterval, platforms: [SocialPlatform]) async throws -> PerformanceReport {
        .mock
    }

    func fetchAudienceDemographics() async throws -> [AudienceDemographic] {
        AudienceDemographic.mock
    }

    func fetchContentPerformance(sortBy: ContentSortField, limit: Int) async throws -> [ContentPerformance] {
        let sorted: [ContentPerformance]
        switch sortBy {
        case .impressions: sorted = ContentPerformance.mock.sorted { $0.impressions > $1.impressions }
        case .engagement:  sorted = ContentPerformance.mock.sorted { $0.engagement > $1.engagement }
        case .saves:       sorted = ContentPerformance.mock.sorted { $0.saves > $1.saves }
        case .shares:      sorted = ContentPerformance.mock.sorted { $0.shares > $1.shares }
        case .clickRate:   sorted = ContentPerformance.mock.sorted { $0.clickRate > $1.clickRate }
        }
        return Array(sorted.prefix(limit))
    }

    func fetchPostTimeAnalysis() async throws -> [PostTimeAnalysis] {
        PostTimeAnalysis.mock
    }

    func fetchFunnelData() async throws -> [FunnelStep] {
        FunnelStep.mock
    }

    func fetchPeriodComparison(current: DateInterval, previous: DateInterval) async throws -> [ComparisonPeriod] {
        ComparisonPeriod.mock
    }
}

// MARK: - API Implementation

final class APIAdvancedAnalyticsRepository: AdvancedAnalyticsRepository {
    func fetchPerformanceReport(range: DateInterval, platforms: [SocialPlatform]) async throws -> PerformanceReport {
        let formatter = ISO8601DateFormatter()
        let query = buildQuery([
            "start": formatter.string(from: range.start),
            "end": formatter.string(from: range.end),
            "platforms": platforms.map(\.apiSlug).joined(separator: ",")
        ])
        let response: PerformanceReportResponse = try await APIClient.shared.request(
            endpoint: "analytics/reports\(query)",
            method: .get,
            requiresAuth: true
        )
        return response.toDomain()
    }

    func fetchAudienceDemographics() async throws -> [AudienceDemographic] {
        let response: [AudienceDemographicResponse] = try await APIClient.shared.request(
            endpoint: "analytics/audience",
            method: .get,
            requiresAuth: true
        )
        return response.map { $0.toDomain() }
    }

    func fetchContentPerformance(sortBy: ContentSortField, limit: Int) async throws -> [ContentPerformance] {
        let query = buildQuery([
            "sort_by": sortBy.rawValue,
            "limit": "\(limit)"
        ])
        let response: [ContentPerformanceResponse] = try await APIClient.shared.request(
            endpoint: "analytics/content-performance\(query)",
            method: .get,
            requiresAuth: true
        )
        return response.map { $0.toDomain() }
    }

    func fetchPostTimeAnalysis() async throws -> [PostTimeAnalysis] {
        let response: [PostTimeAnalysisResponse] = try await APIClient.shared.request(
            endpoint: "analytics/post-times",
            method: .get,
            requiresAuth: true
        )
        return response.map { $0.toDomain() }
    }

    func fetchFunnelData() async throws -> [FunnelStep] {
        let response: [FunnelStepResponse] = try await APIClient.shared.request(
            endpoint: "analytics/funnel",
            method: .get,
            requiresAuth: true
        )
        return response.map { $0.toDomain() }
    }

    func fetchPeriodComparison(current: DateInterval, previous: DateInterval) async throws -> [ComparisonPeriod] {
        let formatter = ISO8601DateFormatter()
        let query = buildQuery([
            "current_start": formatter.string(from: current.start),
            "current_end": formatter.string(from: current.end),
            "previous_start": formatter.string(from: previous.start),
            "previous_end": formatter.string(from: previous.end)
        ])
        let response: [ComparisonPeriodResponse] = try await APIClient.shared.request(
            endpoint: "analytics/compare\(query)",
            method: .get,
            requiresAuth: true
        )
        return response.map { $0.toDomain() }
    }

    private func buildQuery(_ params: [String: String]) -> String {
        buildQueryString(params)
    }
}

// MARK: - Provider

enum AdvancedAnalyticsRepositoryProvider {
    static var shared = RepositoryProvider<AdvancedAnalyticsRepository>(
        dev: MockAdvancedAnalyticsRepository(),
        api: APIAdvancedAnalyticsRepository()
    )
}

// MARK: - API Response DTOs

private struct PerformanceReportResponse: Decodable {
    let startDate: String
    let endDate: String
    let platforms: [String]
    let metrics: [MetricDataPointResponse]
    let summary: String

    func toDomain() -> PerformanceReport {
        let formatter = ISO8601DateFormatter()
        let start = formatter.date(from: startDate) ?? Date()
        let end = formatter.date(from: endDate) ?? Date()
        return PerformanceReport(
            dateRange: DateInterval(start: start, end: end),
            platforms: platforms.compactMap { SocialPlatform(rawValue: $0) },
            metrics: metrics.map { $0.toDomain() },
            summary: summary
        )
    }
}

private struct MetricDataPointResponse: Decodable {
    let date: String
    let value: Double
    let platform: String

    func toDomain() -> MetricDataPoint {
        let parsedDate = ISO8601DateFormatter().date(from: date) ?? Date()
        return MetricDataPoint(
            date: parsedDate,
            value: value,
            platform: SocialPlatform(rawValue: platform) ?? .instagram
        )
    }
}

private struct AudienceDemographicResponse: Decodable {
    let ageRange: String
    let gender: String
    let location: String
    let percentage: Double

    func toDomain() -> AudienceDemographic {
        AudienceDemographic(ageRange: ageRange, gender: gender, location: location, percentage: percentage)
    }
}

private struct ContentPerformanceResponse: Decodable {
    let contentID: String
    let title: String
    let platform: String
    let impressions: Int
    let reach: Int
    let engagement: Int
    let saves: Int
    let shares: Int
    let comments: Int
    let clickRate: Double

    func toDomain() -> ContentPerformance {
        ContentPerformance(
            contentID: contentID,
            title: title,
            platform: SocialPlatform(rawValue: platform) ?? .instagram,
            impressions: impressions,
            reach: reach,
            engagement: engagement,
            saves: saves,
            shares: shares,
            comments: comments,
            clickRate: clickRate
        )
    }
}

private struct PostTimeAnalysisResponse: Decodable {
    let dayOfWeek: Int
    let hour: Int
    let avgEngagement: Double
    let postCount: Int

    func toDomain() -> PostTimeAnalysis {
        PostTimeAnalysis(dayOfWeek: dayOfWeek, hour: hour, avgEngagement: avgEngagement, postCount: postCount)
    }
}

private struct FunnelStepResponse: Decodable {
    let name: String
    let count: Int
    let dropoffRate: Double

    func toDomain() -> FunnelStep {
        FunnelStep(name: name, count: count, dropoffRate: dropoffRate)
    }
}

private struct ComparisonPeriodResponse: Decodable {
    let metricName: String
    let current: Double
    let previous: Double
    let changePercent: Double

    func toDomain() -> ComparisonPeriod {
        ComparisonPeriod(metricName: metricName, current: current, previous: previous, changePercent: changePercent)
    }
}
