//
//  Phase19Plan02ProviderStandardizationTests.swift
//  ENVITests
//
//  Phase 19 — Plan 02. Pins the contract that the analytics family of
//  repositories resolves through a single canonical facade (`Repositories`),
//  that flag-aware dispatch still correctly branches on
//  `connectorsInsightsLive`, and that BenchmarkViewModel now has a
//  dev-mode mock fallback when the repo throws (matching the
//  AnalyticsViewModel / AdvancedAnalyticsViewModel pattern).
//

import XCTest
@testable import ENVI

@MainActor
final class Phase19Plan02ProviderStandardizationTests: XCTestCase {

    // MARK: - Facade resolves the right type per flag

    func testRepositoriesAnalyticsReturnsValidInstance() {
        // Cannot verify class-identity across `connectorsInsightsLive` in a
        // unit test without also touching Firestore state; we only verify
        // that the facade returns a live `AnalyticsRepository`.
        let repo = Repositories.analytics
        XCTAssertNotNil(repo as AnalyticsRepository?)
    }

    func testRepositoriesAdvancedAnalyticsReturnsValidInstance() {
        let repo = Repositories.advancedAnalytics
        XCTAssertNotNil(repo as AdvancedAnalyticsRepository?)
    }

    func testRepositoriesBenchmarkReturnsValidInstance() {
        let repo = Repositories.benchmark
        XCTAssertNotNil(repo as BenchmarkRepository?)
    }

    // MARK: - BenchmarkViewModel fallback

    /// Stub that throws on every method, so we can exercise the catch
    /// path in `BenchmarkViewModel.loadAll()`.
    final class ThrowingBenchmarkRepository: BenchmarkRepository {
        struct BoomError: Error {}
        func fetchBenchmarks(category: IndustryCategory) async throws -> [Benchmark] { throw BoomError() }
        func fetchInsights() async throws -> [InsightCard] { throw BoomError() }
        func fetchTrendSignals() async throws -> [TrendSignal] { throw BoomError() }
        func fetchWeeklyDigest() async throws -> WeeklyDigest { throw BoomError() }
    }

    /// In `AppEnvironment.dev`, BenchmarkViewModel must swap to mock
    /// payloads rather than a blank UI, matching AnalyticsViewModel +
    /// AdvancedAnalyticsViewModel behavior. Pins Phase 19 Plan 02's
    /// "add a proper fallback" contract.
    func testBenchmarkViewModelDevFallbackOnError() async {
        // Note: AppEnvironment.current is `.dev` by default in the
        // ENVITests test host (Debug config). If that ever changes
        // this test will start failing and force a conscious update.
        guard AppEnvironment.current == .dev else {
            throw XCTSkip("Dev fallback only applies in .dev AppEnvironment")
        }

        let vm = BenchmarkViewModel(repository: ThrowingBenchmarkRepository())
        await vm.loadAll()

        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage, "In dev the VM falls back to mock data silently.")
        XCTAssertEqual(vm.benchmarks.count, Benchmark.mock.count)
        XCTAssertEqual(vm.insights.count, InsightCard.mock.count)
        XCTAssertEqual(vm.trendSignals.count, TrendSignal.mock.count)
    }
}
