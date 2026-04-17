import SwiftUI
import Combine

/// ViewModel for `ContractManagerView` (Phase 19 — Plan 01).
///
/// Replaces the prior "repo-in-view" anti-pattern where the view itself held
/// `private let repository = EnterpriseRepositoryProvider.shared.repository`.
@MainActor
final class ContractManagerViewModel: ObservableObject {

    // MARK: - Published State

    @Published var contracts: [EnterpriseContract] = []
    @Published var certifications: [ComplianceCertification] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let repository: EnterpriseRepository

    // MARK: - Init

    init(repository: EnterpriseRepository? = nil) {
        self.repository = repository ?? EnterpriseRepositoryProvider.shared.repository
    }

    // MARK: - Derived

    var totalSeats: Int {
        contracts.reduce(0) { $0 + $1.seats }
    }

    var activeCount: Int {
        contracts.filter { $0.renewalStatus == .active }.count
    }

    var renewalCount: Int {
        contracts.filter { $0.renewalStatus == .pendingRenewal }.count
    }

    // MARK: - Loading

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let c = repository.fetchContracts()
            async let certs = repository.fetchCertifications()
            contracts = try await c
            certifications = try await certs
        } catch {
            errorMessage = "Unable to load contracts."
            contracts = []
            certifications = []
        }
        isLoading = false
    }
}
