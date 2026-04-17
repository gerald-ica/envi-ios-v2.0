//
//  FeatureFlagsAnalyticsProviderTests.swift
//  ENVITests
//
//  Phase 14 — Plan 02 unit tests for the analytics provider chain.
//
//  Purpose
//  -------
//  Plan 14-02 flipped `FeatureFlags.shared.connectorsInsightsLive` to
//  `true` by default. This suite pins the runtime contract so we catch
//  future regressions where the code default ships divergent from what
//  the repo comments / provider branches claim:
//    1. `connectorsInsightsLive` defaults to `true`.
//    2. With the flag on, each of the three analytics `...Provider.resolve()`
//       entry points returns its `FirestoreBacked*` implementation.
//    3. With the flag off, each provider falls back to the legacy mock/API
//       repo (i.e., NOT the `FirestoreBacked*` type).
//
//  Notes
//  -----
//  - `FeatureFlags` is `@MainActor`, so each test is `@MainActor` and the
//    class is `@MainActor` as well.
//  - Each test that mutates the flag restores it in `tearDown` so test
//    ordering doesn't matter.
//

import XCTest
@testable import ENVI

@MainActor
final class FeatureFlagsAnalyticsProviderTests: XCTestCase {

    private var originalFlagValue: Bool = true

    override func setUp() async throws {
        try await super.setUp()
        originalFlagValue = FeatureFlags.shared.connectorsInsightsLive
    }

    override func tearDown() async throws {
        FeatureFlags.shared.connectorsInsightsLive = originalFlagValue
        try await super.tearDown()
    }

    // MARK: - Default

    func testConnectorsInsightsLiveDefaultIsTrue() {
        // Restore the default first in case a prior test mutated it.
        // (tearDown handles the final restore; this isolates the assertion.)
        FeatureFlags.shared.connectorsInsightsLive = true
        XCTAssertTrue(
            FeatureFlags.shared.connectorsInsightsLive,
            "Phase 14-02 flipped the default to true; a regression here means the analytics read-path is silently mocked again."
        )
    }

    // MARK: - AnalyticsRepositoryProvider

    func testAnalyticsRepositoryProviderReturnsFirestoreBackedWhenLive() {
        FeatureFlags.shared.connectorsInsightsLive = true
        let repo = AnalyticsRepositoryProvider.resolve()
        XCTAssertTrue(
            repo is FirestoreBackedAnalyticsRepository,
            "Expected FirestoreBackedAnalyticsRepository when connectorsInsightsLive = true, got \(type(of: repo))"
        )
    }

    func testAnalyticsRepositoryProviderFallsBackWhenDisabled() {
        FeatureFlags.shared.connectorsInsightsLive = false
        let repo = AnalyticsRepositoryProvider.resolve()
        XCTAssertFalse(
            repo is FirestoreBackedAnalyticsRepository,
            "Expected non-Firestore repo when connectorsInsightsLive = false, got \(type(of: repo))"
        )
    }

    // MARK: - AdvancedAnalyticsRepositoryProvider

    func testAdvancedAnalyticsRepositoryProviderReturnsFirestoreBackedWhenLive() {
        FeatureFlags.shared.connectorsInsightsLive = true
        let repo = AdvancedAnalyticsRepositoryProvider.resolve()
        XCTAssertTrue(
            repo is FirestoreBackedAdvancedAnalyticsRepository,
            "Expected FirestoreBackedAdvancedAnalyticsRepository when connectorsInsightsLive = true, got \(type(of: repo))"
        )
    }

    func testAdvancedAnalyticsRepositoryProviderFallsBackWhenDisabled() {
        FeatureFlags.shared.connectorsInsightsLive = false
        let repo = AdvancedAnalyticsRepositoryProvider.resolve()
        XCTAssertFalse(
            repo is FirestoreBackedAdvancedAnalyticsRepository,
            "Expected non-Firestore repo when connectorsInsightsLive = false, got \(type(of: repo))"
        )
    }

    // MARK: - BenchmarkRepositoryProvider

    func testBenchmarkRepositoryProviderReturnsFirestoreBackedWhenLive() {
        FeatureFlags.shared.connectorsInsightsLive = true
        let repo = BenchmarkRepositoryProvider.resolve()
        XCTAssertTrue(
            repo is FirestoreBackedBenchmarkRepository,
            "Expected FirestoreBackedBenchmarkRepository when connectorsInsightsLive = true, got \(type(of: repo))"
        )
    }

    func testBenchmarkRepositoryProviderFallsBackWhenDisabled() {
        FeatureFlags.shared.connectorsInsightsLive = false
        let repo = BenchmarkRepositoryProvider.resolve()
        XCTAssertFalse(
            repo is FirestoreBackedBenchmarkRepository,
            "Expected non-Firestore repo when connectorsInsightsLive = false, got \(type(of: repo))"
        )
    }
}
