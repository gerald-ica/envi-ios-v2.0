import SwiftUI
import Combine

/// ViewModel for the Growth dashboard and Referral program.
///
/// Phase 17 — Plan 01. Replaces the prior pattern where `GrowthDashboardView`
/// and `ReferralView` held `GrowthMetric.mockList`, `ReferralProgram.mock`,
/// and `ReferralInvite.mockList` in `@State` defaults, bypassing
/// `GrowthRepository` entirely. The repository is wired via
/// `GrowthRepositoryProvider.shared.repository` so dev builds continue to
/// receive mock data and staging/prod builds hit the real API.
@MainActor
final class GrowthViewModel: ObservableObject {
    // MARK: - Dashboard State
    @Published var metrics: [GrowthMetric] = []
    @Published var viralLoops: [ViralLoop] = []
    @Published var shareableAssets: [ShareableAsset] = []

    // MARK: - Referral State
    @Published var referralProgram: ReferralProgram?
    @Published var referralInvites: [ReferralInvite] = []

    // MARK: - Load / Error
    @Published var isLoading = false
    @Published var errorMessage: String?

    nonisolated(unsafe) private let repository: GrowthRepository

    init(repository: GrowthRepository = GrowthRepositoryProvider.shared.repository) {
        self.repository = repository
    }

    // MARK: - Dashboard

    @MainActor
    func loadDashboard() async {
        isLoading = true
        errorMessage = nil

        do {
            async let metricsTask = repository.fetchMetrics()
            async let loopsTask = repository.fetchViralLoops()
            async let assetsTask = repository.fetchShareableAssets()

            let (m, l, a) = try await (metricsTask, loopsTask, assetsTask)
            metrics = m
            viralLoops = l
            shareableAssets = a
        } catch {
            errorMessage = "Unable to load growth data."
        }

        isLoading = false
    }

    // MARK: - Referral

    @MainActor
    func loadReferrals() async {
        isLoading = true
        errorMessage = nil

        do {
            async let programTask = repository.fetchReferralProgram()
            async let invitesTask = repository.fetchInvites()

            let (program, invites) = try await (programTask, invitesTask)
            referralProgram = program
            referralInvites = invites
        } catch {
            errorMessage = "Unable to load referral program."
        }

        isLoading = false
    }

    @MainActor
    func sendInvite(email: String) async {
        guard !email.isEmpty else { return }
        errorMessage = nil

        do {
            let invite = try await repository.sendInvite(email: email)
            referralInvites.insert(invite, at: 0)
            if var program = referralProgram {
                program.referralCount += 1
                referralProgram = program
            }
        } catch {
            errorMessage = "Unable to send invite."
        }
    }
}

// MARK: - Preview Helper

#if DEBUG
extension GrowthViewModel {
    /// Preview helper that pre-populates state from mocks without
    /// depending on async work. Not used in production code paths.
    static func preview() -> GrowthViewModel {
        let vm = GrowthViewModel(repository: MockGrowthRepository())
        vm.metrics = GrowthMetric.mockList
        vm.viralLoops = ViralLoop.mockList
        vm.shareableAssets = ShareableAsset.mockList
        vm.referralProgram = .mock
        vm.referralInvites = ReferralInvite.mockList
        return vm
    }
}
#endif
