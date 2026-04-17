//
//  Phase19Plan01RepoInViewRefactorTests.swift
//  ENVITests
//
//  Phase 19 — Plan 01. Pins the contract that `SystemHealthView`,
//  `SSOConfigView`, and `ContractManagerView` are no longer injecting a
//  repository directly onto the `View` struct (the "repo-in-view"
//  anti-pattern). Each now has a dedicated ViewModel that owns the repo
//  interaction, exposes a `load()` method, and surfaces errors via
//  `errorMessage`.
//

import XCTest
@testable import ENVI

@MainActor
final class Phase19Plan01RepoInViewRefactorTests: XCTestCase {

    // MARK: - Admin (SystemHealth) Test Doubles

    final class StubAdminRepository: AdminRepository {
        var metrics: [SystemHealthMetric] = []
        var shouldThrow = false
        struct BoomError: Error {}

        func fetchFeatureFlags() async throws -> [FeatureFlag] { [] }
        func toggleFlag(id: UUID, isEnabled: Bool) async throws -> FeatureFlag {
            FeatureFlag(id: id, name: "stub", isEnabled: isEnabled, targetPercentage: 0, description: "")
        }
        func fetchModerationQueue() async throws -> [ModerationItem] { [] }
        func moderateItem(id: UUID, status: ModerationStatus) async throws -> ModerationItem {
            ModerationItem(id: id, contentType: "post", reportReason: "stub", status: status, reportedAt: Date())
        }

        func fetchSystemHealth() async throws -> [SystemHealthMetric] {
            if shouldThrow { throw BoomError() }
            return metrics
        }
    }

    // MARK: - Enterprise (SSOConfig + ContractManager) Test Doubles

    final class StubEnterpriseRepository: EnterpriseRepository {
        var ssoConfig: SSOConfig = .mock
        var scimConfig: SCIMConfig = .mock
        var contracts: [EnterpriseContract] = []
        var certifications: [ComplianceCertification] = []
        var shouldThrow = false
        struct BoomError: Error {}

        func fetchSSOConfig() async throws -> SSOConfig {
            if shouldThrow { throw BoomError() }
            return ssoConfig
        }
        func updateSSOConfig(_ config: SSOConfig) async throws -> SSOConfig {
            if shouldThrow { throw BoomError() }
            return config
        }
        func fetchSCIMConfig() async throws -> SCIMConfig {
            if shouldThrow { throw BoomError() }
            return scimConfig
        }
        func fetchProcurements() async throws -> [ProcurementRequest] { [] }
        func createProcurement(_ request: ProcurementRequest) async throws -> ProcurementRequest { request }
        func fetchContracts() async throws -> [EnterpriseContract] {
            if shouldThrow { throw BoomError() }
            return contracts
        }
        func fetchCertifications() async throws -> [ComplianceCertification] {
            if shouldThrow { throw BoomError() }
            return certifications
        }
    }

    // MARK: - SystemHealthViewModel

    func testSystemHealthViewModelDefaultStateIsEmpty() {
        let vm = SystemHealthViewModel(repository: StubAdminRepository())
        XCTAssertTrue(vm.metrics.isEmpty)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    func testSystemHealthViewModelLoadPopulatesFromRepo() async {
        let repo = StubAdminRepository()
        repo.metrics = SystemHealthMetric.mock

        let vm = SystemHealthViewModel(repository: repo)
        await vm.load()

        XCTAssertEqual(vm.metrics.count, SystemHealthMetric.mock.count)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    func testSystemHealthViewModelErrorSetsErrorMessage() async {
        let repo = StubAdminRepository()
        repo.shouldThrow = true

        let vm = SystemHealthViewModel(repository: repo)
        await vm.load()

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertTrue(vm.metrics.isEmpty)
        XCTAssertFalse(vm.isLoading)
    }

    // MARK: - SSOConfigViewModel

    func testSSOConfigViewModelDefaultStateNotLoading() {
        let vm = SSOConfigViewModel(repository: StubEnterpriseRepository())
        XCTAssertFalse(vm.isLoading)
        XCTAssertFalse(vm.isSaving)
        XCTAssertNil(vm.errorMessage)
    }

    func testSSOConfigViewModelLoadPopulatesFromRepo() async {
        let repo = StubEnterpriseRepository()
        repo.ssoConfig = .mock

        let vm = SSOConfigViewModel(repository: repo)
        await vm.load()

        XCTAssertFalse(vm.isLoading)
        XCTAssertEqual(vm.config.domain, SSOConfig.mock.domain)
        XCTAssertNil(vm.errorMessage)
    }

    func testSSOConfigViewModelLoadErrorSetsErrorMessage() async {
        let repo = StubEnterpriseRepository()
        repo.shouldThrow = true

        let vm = SSOConfigViewModel(repository: repo)
        await vm.load()

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertFalse(vm.isLoading)
    }

    // MARK: - ContractManagerViewModel

    func testContractManagerViewModelDefaultStateIsEmpty() {
        let vm = ContractManagerViewModel(repository: StubEnterpriseRepository())
        XCTAssertTrue(vm.contracts.isEmpty)
        XCTAssertTrue(vm.certifications.isEmpty)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    func testContractManagerViewModelLoadPopulatesFromRepo() async {
        let repo = StubEnterpriseRepository()
        repo.contracts = EnterpriseContract.mock
        repo.certifications = ComplianceCertification.mock

        let vm = ContractManagerViewModel(repository: repo)
        await vm.load()

        XCTAssertEqual(vm.contracts.count, EnterpriseContract.mock.count)
        XCTAssertEqual(vm.certifications.count, ComplianceCertification.mock.count)
        XCTAssertEqual(vm.totalSeats, EnterpriseContract.mock.reduce(0) { $0 + $1.seats })
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    func testContractManagerViewModelErrorSetsErrorMessage() async {
        let repo = StubEnterpriseRepository()
        repo.shouldThrow = true

        let vm = ContractManagerViewModel(repository: repo)
        await vm.load()

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertTrue(vm.contracts.isEmpty)
        XCTAssertTrue(vm.certifications.isEmpty)
        XCTAssertFalse(vm.isLoading)
    }
}
