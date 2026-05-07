import SwiftUI
import Combine

/// ViewModel for `SystemHealthView` (Phase 19 — Plan 01).
///
/// Replaces the prior "repo-in-view" anti-pattern where the view itself held
/// `private let repository = AdminRepositoryProvider.shared.repository`.
/// The VM owns loading + state + error surfaces, so the view can stay a dumb
/// renderer and tests can inject a fake repository.
@MainActor
final class SystemHealthViewModel: ObservableObject {

    // MARK: - Published State

    @Published var metrics: [SystemHealthMetric] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private nonisolated(unsafe) let repository: AdminRepository

    // MARK: - Init

    init(repository: AdminRepository? = nil) {
        self.repository = repository ?? AdminRepositoryProvider.shared.repository
    }

    // MARK: - Derived

    /// Rolled-up status, worst-wins across all metrics.
    var overallStatus: HealthStatus {
        if metrics.contains(where: { $0.status == .critical }) { return .critical }
        if metrics.contains(where: { $0.status == .degraded }) { return .degraded }
        return .healthy
    }

    var healthyCount: Int {
        metrics.filter { $0.status == .healthy }.count
    }

    // MARK: - Loading

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            metrics = try await repository.fetchSystemHealth()
        } catch {
            errorMessage = "Unable to load system health."
            metrics = []
        }
        isLoading = false
    }
}
