//
//  GrowthViewModelTests.swift
//  ENVITests
//
//  Phase 17 — Plan 01. Pins the contract that GrowthViewModel no longer
//  defaults to `GrowthMetric.mockList` / `ReferralProgram.mock` /
//  `ReferralInvite.mockList` in production, and that it correctly
//  populates state from the injected repository (and surfaces an error
//  message on failure rather than silently falling back to mocks).
//

import XCTest
@testable import ENVI

@MainActor
final class GrowthViewModelTests: XCTestCase {

    // MARK: - Test Doubles

    /// Spyable repository used across tests. Separate from
    /// `MockGrowthRepository` to give tests full control over the
    /// payloads returned and to exercise error paths.
    final class StubRepository: GrowthRepository {
        var metrics: [GrowthMetric] = []
        var loops: [ViralLoop] = []
        var assets: [ShareableAsset] = []
        var program: ReferralProgram = .mock
        var invites: [ReferralInvite] = []
        var shouldThrow: Bool = false

        struct BoomError: Error {}

        func fetchReferralProgram() async throws -> ReferralProgram {
            if shouldThrow { throw BoomError() }
            return program
        }

        func fetchInvites() async throws -> [ReferralInvite] {
            if shouldThrow { throw BoomError() }
            return invites
        }

        func sendInvite(email: String) async throws -> ReferralInvite {
            if shouldThrow { throw BoomError() }
            return ReferralInvite(recipientEmail: email)
        }

        func fetchMetrics() async throws -> [GrowthMetric] {
            if shouldThrow { throw BoomError() }
            return metrics
        }

        func fetchViralLoops() async throws -> [ViralLoop] {
            if shouldThrow { throw BoomError() }
            return loops
        }

        func fetchShareableAssets() async throws -> [ShareableAsset] {
            if shouldThrow { throw BoomError() }
            return assets
        }

        func createShareableAsset(contentID: UUID, shareURL: String) async throws -> ShareableAsset {
            if shouldThrow { throw BoomError() }
            return ShareableAsset(contentID: contentID, shareURL: shareURL)
        }
    }

    // MARK: - Tests

    /// v1.2 Audit finding: Growth views were rendering `GrowthMetric.mockList`
    /// etc. by default because the views held those mocks as `@State`
    /// defaults. The VM must start empty so a regression surfaces as an
    /// empty UI, not silently-shipped mock data.
    func testDefaultStateIsEmpty() {
        let vm = GrowthViewModel(repository: StubRepository())
        XCTAssertTrue(vm.metrics.isEmpty, "GrowthViewModel should start with no metrics.")
        XCTAssertTrue(vm.viralLoops.isEmpty, "GrowthViewModel should start with no viral loops.")
        XCTAssertTrue(vm.shareableAssets.isEmpty, "GrowthViewModel should start with no assets.")
        XCTAssertNil(vm.referralProgram, "GrowthViewModel should start with nil program.")
        XCTAssertTrue(vm.referralInvites.isEmpty, "GrowthViewModel should start with no invites.")
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    /// `loadDashboard()` must populate metrics / loops / assets from the
    /// repository and clear the loading flag.
    func testLoadDashboardPopulatesFromRepo() async {
        let repo = StubRepository()
        repo.metrics = GrowthMetric.mockList
        repo.loops = ViralLoop.mockList
        repo.assets = ShareableAsset.mockList

        let vm = GrowthViewModel(repository: repo)
        await vm.loadDashboard()

        XCTAssertEqual(vm.metrics.count, GrowthMetric.mockList.count)
        XCTAssertEqual(vm.viralLoops.count, ViralLoop.mockList.count)
        XCTAssertEqual(vm.shareableAssets.count, ShareableAsset.mockList.count)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    /// When the repository throws we must surface an `errorMessage` and
    /// NOT silently fall back to mock data — that was the audit's whole
    /// concern with the old mock-in-@State pattern.
    func testLoadDashboardErrorSetsErrorMessage() async {
        let repo = StubRepository()
        repo.shouldThrow = true

        let vm = GrowthViewModel(repository: repo)
        await vm.loadDashboard()

        XCTAssertNotNil(vm.errorMessage, "An error from the repo must populate errorMessage.")
        XCTAssertFalse(vm.isLoading)
        XCTAssertTrue(vm.metrics.isEmpty, "Metrics must stay empty on error, NOT fall back to mocks.")
        XCTAssertTrue(vm.viralLoops.isEmpty)
        XCTAssertTrue(vm.shareableAssets.isEmpty)
    }
}
