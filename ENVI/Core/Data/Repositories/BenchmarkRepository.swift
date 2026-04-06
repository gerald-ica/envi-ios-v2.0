import Foundation

// MARK: - Protocol

protocol BenchmarkRepository {
    func fetchBenchmarks(category: IndustryCategory) async throws -> [Benchmark]
    func fetchInsights() async throws -> [InsightCard]
    func fetchTrendSignals() async throws -> [TrendSignal]
    func fetchWeeklyDigest() async throws -> WeeklyDigest
}

// MARK: - Mock Implementation

final class MockBenchmarkRepository: BenchmarkRepository {
    func fetchBenchmarks(category: IndustryCategory) async throws -> [Benchmark] {
        Benchmark.mock
    }

    func fetchInsights() async throws -> [InsightCard] {
        InsightCard.mock
    }

    func fetchTrendSignals() async throws -> [TrendSignal] {
        TrendSignal.mock
    }

    func fetchWeeklyDigest() async throws -> WeeklyDigest {
        .mock
    }
}

// MARK: - API Implementation

final class APIBenchmarkRepository: BenchmarkRepository {
    func fetchBenchmarks(category: IndustryCategory) async throws -> [Benchmark] {
        let query = buildQuery(["category": category.rawValue])
        let response: [BenchmarkResponse] = try await APIClient.shared.request(
            endpoint: "analytics/benchmarks\(query)",
            method: .get,
            requiresAuth: true
        )
        return response.map { $0.toDomain() }
    }

    func fetchInsights() async throws -> [InsightCard] {
        let response: [InsightCardResponse] = try await APIClient.shared.request(
            endpoint: "analytics/insights",
            method: .get,
            requiresAuth: true
        )
        return response.map { $0.toDomain() }
    }

    func fetchTrendSignals() async throws -> [TrendSignal] {
        let response: [TrendSignalResponse] = try await APIClient.shared.request(
            endpoint: "analytics/trends",
            method: .get,
            requiresAuth: true
        )
        return response.map { $0.toDomain() }
    }

    func fetchWeeklyDigest() async throws -> WeeklyDigest {
        let response: WeeklyDigestResponse = try await APIClient.shared.request(
            endpoint: "analytics/weekly-digest",
            method: .get,
            requiresAuth: true
        )
        return response.toDomain()
    }

    private func buildQuery(_ params: [String: String]) -> String {
        buildQueryString(params)
    }
}

// MARK: - Provider

enum BenchmarkRepositoryProvider {
    static var shared = RepositoryProvider<BenchmarkRepository>(
        dev: MockBenchmarkRepository(),
        api: APIBenchmarkRepository()
    )
}

// MARK: - API Response DTOs

private struct BenchmarkResponse: Decodable {
    let metric: String
    let userValue: Double
    let industryAvg: Double
    let topPerformer: Double
    let percentile: Int

    func toDomain() -> Benchmark {
        Benchmark(
            metric: metric,
            userValue: userValue,
            industryAvg: industryAvg,
            topPerformer: topPerformer,
            percentile: percentile
        )
    }
}

private struct InsightCardResponse: Decodable {
    let title: String
    let description: String
    let actionableAdvice: String
    let impact: String
    let confidence: Double

    func toDomain() -> InsightCard {
        InsightCard(
            title: title,
            description: description,
            actionableAdvice: actionableAdvice,
            impact: ImpactLevel(rawValue: impact) ?? .medium,
            confidence: confidence
        )
    }
}

private struct TrendSignalResponse: Decodable {
    let topic: String
    let momentum: Double
    let direction: String
    let platforms: [String]
    let timeframe: String

    func toDomain() -> TrendSignal {
        TrendSignal(
            topic: topic,
            momentum: momentum,
            direction: TrendDirection(rawValue: direction) ?? .stable,
            platforms: platforms.compactMap { SocialPlatform(rawValue: $0) },
            timeframe: timeframe
        )
    }
}

private struct WeeklyDigestResponse: Decodable {
    let weekStarting: String
    let highlights: [String]
    let topContent: [ContentPerformanceResponse]
    let keyMetrics: [BenchmarkResponse]
    let recommendations: [String]

    func toDomain() -> WeeklyDigest {
        let date = ISO8601DateFormatter().date(from: weekStarting) ?? Date()
        return WeeklyDigest(
            weekStarting: date,
            highlights: highlights,
            topContent: topContent.map { $0.toDomain() },
            keyMetrics: keyMetrics.map { $0.toDomain() },
            recommendations: recommendations
        )
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
