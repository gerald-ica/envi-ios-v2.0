import SwiftUI
import Combine

/// ViewModel for the Analytics dashboard.
@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published var data = AnalyticsData.mock
    @Published var growth = CreatorGrowthSnapshot.mock
    @Published var cohorts: [RetentionCohort] = RetentionCohort.mock
    @Published var attribution: [SourceAttribution] = SourceAttribution.mock
    @Published var selectedPlatform: SocialPlatform? = nil
    @Published var dateRange = "Jun 10 – Jun 16, 2024"
    @Published var isLoading = false
    @Published var loadErrorMessage: String?

    /// Phase 13 — surfaced when `connectorsInsightsLive` is on AND the
    /// user has no data yet. The Analytics view binds this to show
    /// `ConnectAccountEmptyStateView` in place of the KPI strip.
    @Published var showEmptyState = false

    private let repository: AnalyticsRepository

    init(repository: AnalyticsRepository? = nil) {
        // Resolve the repository lazily so the FeatureFlags main-actor read
        // happens inside a MainActor context.
        self.repository = repository ?? Repositories.analytics
        Task { await reload() }
    }

    var platforms: [SocialPlatform?] {
        [nil, .instagram, .tiktok, .youtube]
    }

    var displayedCalendarDays: [AnalyticsData.CalendarDay] {
        guard let selectedPlatform else { return data.calendarDays }
        return data.calendarDays.filter { $0.platform == selectedPlatform }
    }

    func platformLabel(_ platform: SocialPlatform?) -> String {
        platform?.rawValue ?? "All"
    }

    func reload() async {
        isLoading = true
        loadErrorMessage = nil
        TelemetryManager.shared.track(.analyticsViewed)
        do {
            let fetched = try await repository.fetchDashboard()
            data = fetched
            growth = try await repository.fetchCreatorGrowth()
            cohorts = try await repository.fetchRetentionCohorts()
            attribution = try await repository.fetchAttribution()
            // Phase 13 — decide empty-state by asking the data whether any
            // connected provider has produced a signal yet. Only engage
            // when the live-insights flag is on (otherwise the mock data
            // would always report `hasConnectedData == true`).
            if FeatureFlags.shared.connectorsInsightsLive {
                showEmptyState = !fetched.hasConnectedData
            } else {
                showEmptyState = false
            }
        } catch {
            if AppEnvironment.current == .dev {
                data = .mock
                growth = .mock
                cohorts = RetentionCohort.mock
                attribution = SourceAttribution.mock
                showEmptyState = false
            } else {
                loadErrorMessage = "Unable to load analytics right now."
            }
        }
        isLoading = false
    }
}
