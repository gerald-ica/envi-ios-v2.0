import SwiftUI
import Combine

/// ViewModel powering the advanced analytics views (reports, demographics, content, timing, funnels).
@MainActor
final class AdvancedAnalyticsViewModel: ObservableObject {

    // MARK: - Published State

    @Published var report: PerformanceReport = .mock
    @Published var demographics: [AudienceDemographic] = []
    @Published var contentPerformance: [ContentPerformance] = []
    @Published var postTimeAnalysis: [PostTimeAnalysis] = []
    @Published var funnelSteps: [FunnelStep] = []
    @Published var periodComparison: [ComparisonPeriod] = []

    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var selectedPlatformFilter: SocialPlatform? = nil
    @Published var contentSortField: ContentSortField = .impressions
    @Published var contentLimit: Int = 10

    // MARK: - Dependencies

    private let repository: AdvancedAnalyticsRepository

    // MARK: - Init

    init(repository: AdvancedAnalyticsRepository = AdvancedAnalyticsRepositoryProvider.shared.repository) {
        self.repository = repository
        Task { await loadAll() }
    }

    // MARK: - Loading

    func loadAll() async {
        isLoading = true
        errorMessage = nil

        do {
            let now = Date()
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
            let currentRange = DateInterval(start: thirtyDaysAgo, end: now)
            let sixtyDaysAgo = Calendar.current.date(byAdding: .day, value: -60, to: now) ?? now
            let previousRange = DateInterval(start: sixtyDaysAgo, end: thirtyDaysAgo)

            async let reportTask = repository.fetchPerformanceReport(
                range: currentRange,
                platforms: selectedPlatformFilter.map { [$0] } ?? SocialPlatform.allCases.map { $0 }
            )
            async let demoTask = repository.fetchAudienceDemographics()
            async let contentTask = repository.fetchContentPerformance(sortBy: contentSortField, limit: contentLimit)
            async let timeTask = repository.fetchPostTimeAnalysis()
            async let funnelTask = repository.fetchFunnelData()
            async let compareTask = repository.fetchPeriodComparison(current: currentRange, previous: previousRange)

            let (r, d, c, t, f, p) = try await (reportTask, demoTask, contentTask, timeTask, funnelTask, compareTask)
            report = r
            demographics = d
            contentPerformance = c
            postTimeAnalysis = t
            funnelSteps = f
            periodComparison = p
        } catch {
            if AppEnvironment.current == .dev {
                report = .mock
                demographics = AudienceDemographic.mock
                contentPerformance = ContentPerformance.mock
                postTimeAnalysis = PostTimeAnalysis.mock
                funnelSteps = FunnelStep.mock
                periodComparison = ComparisonPeriod.mock
            } else {
                errorMessage = "Unable to load advanced analytics."
            }
        }

        isLoading = false
    }

    func reloadContent() async {
        do {
            contentPerformance = try await repository.fetchContentPerformance(sortBy: contentSortField, limit: contentLimit)
        } catch {
            if AppEnvironment.current == .dev {
                contentPerformance = ContentPerformance.mock
            }
        }
    }

    // MARK: - Derived Data

    /// Metrics filtered by the current platform selection.
    var filteredMetrics: [MetricDataPoint] {
        guard let platform = selectedPlatformFilter else { return report.metrics }
        return report.metrics.filter { $0.platform == platform }
    }

    /// Demographics grouped by age range.
    var demographicsByAge: [(label: String, total: Double)] {
        Dictionary(grouping: demographics, by: \.ageRange)
            .map { (label: $0.key, total: $0.value.reduce(0) { $0 + $1.percentage }) }
            .sorted { $0.total > $1.total }
    }

    /// Demographics grouped by gender.
    var demographicsByGender: [(label: String, total: Double)] {
        Dictionary(grouping: demographics, by: \.gender)
            .map { (label: $0.key, total: $0.value.reduce(0) { $0 + $1.percentage }) }
            .sorted { $0.total > $1.total }
    }

    /// Demographics grouped by location.
    var demographicsByLocation: [(label: String, total: Double)] {
        Dictionary(grouping: demographics, by: \.location)
            .map { (label: $0.key, total: $0.value.reduce(0) { $0 + $1.percentage }) }
            .sorted { $0.total > $1.total }
    }

    /// Best posting time based on highest average engagement.
    var bestPostTime: PostTimeAnalysis? {
        postTimeAnalysis.max(by: { $0.avgEngagement < $1.avgEngagement })
    }

    /// Maximum engagement across all time slots (for normalizing the heatmap).
    var maxEngagement: Double {
        postTimeAnalysis.map(\.avgEngagement).max() ?? 1
    }
}
