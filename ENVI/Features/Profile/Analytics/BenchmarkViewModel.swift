import SwiftUI
import Combine

/// ViewModel powering benchmark comparisons, insights, trends, and weekly digest views.
@MainActor
final class BenchmarkViewModel: ObservableObject {

    // MARK: - Published State

    @Published var benchmarks: [Benchmark] = []
    @Published var insights: [InsightCard] = []
    @Published var trendSignals: [TrendSignal] = []
    @Published var weeklyDigest: WeeklyDigest = .mock

    @Published var selectedCategory: IndustryCategory = .lifestyle
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// Phase 13 — set when `connectorsInsightsLive` is on AND the user
    /// has neither benchmarks nor insights yet. The Benchmark view binds
    /// this to the `ConnectAccountEmptyStateView`.
    @Published var showEmptyState = false

    // MARK: - Dependencies

    private let repository: BenchmarkRepository

    // MARK: - Init

    init(repository: BenchmarkRepository? = nil) {
        self.repository = repository ?? BenchmarkRepositoryProvider.resolve()
        Task { await loadAll() }
    }

    // MARK: - Loading

    func loadAll() async {
        isLoading = true
        errorMessage = nil

        do {
            async let benchmarksTask = repository.fetchBenchmarks(category: selectedCategory)
            async let insightsTask = repository.fetchInsights()
            async let trendsTask = repository.fetchTrendSignals()
            async let digestTask = repository.fetchWeeklyDigest()

            let (b, i, t, d) = try await (benchmarksTask, insightsTask, trendsTask, digestTask)
            benchmarks = b
            insights = i
            trendSignals = t
            weeklyDigest = d

            if FeatureFlags.shared.connectorsInsightsLive {
                showEmptyState = b.isEmpty && i.isEmpty && t.isEmpty && d.highlights.isEmpty
            } else {
                showEmptyState = false
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadBenchmarks() async {
        do {
            benchmarks = try await repository.fetchBenchmarks(category: selectedCategory)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func changeCategory(_ category: IndustryCategory) {
        selectedCategory = category
        Task { await loadBenchmarks() }
    }

    // MARK: - Computed Helpers

    /// Benchmarks where user exceeds industry average.
    var aboveAverageBenchmarks: [Benchmark] {
        benchmarks.filter { $0.userValue > $0.industryAvg }
    }

    /// Benchmarks where user trails industry average.
    var belowAverageBenchmarks: [Benchmark] {
        benchmarks.filter { $0.userValue <= $0.industryAvg }
    }

    /// High-impact insights sorted by confidence.
    var prioritizedInsights: [InsightCard] {
        insights
            .sorted { $0.confidence > $1.confidence }
            .sorted { impactWeight($0.impact) > impactWeight($1.impact) }
    }

    /// Trends sorted by momentum descending.
    var hotTrends: [TrendSignal] {
        trendSignals.sorted { $0.momentum > $1.momentum }
    }

    // MARK: - Private

    private func impactWeight(_ level: ImpactLevel) -> Int {
        switch level {
        case .high:   return 3
        case .medium: return 2
        case .low:    return 1
        }
    }
}
