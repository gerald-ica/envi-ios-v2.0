import SwiftUI
import Combine

/// ViewModel for the Analytics dashboard.
final class AnalyticsViewModel: ObservableObject {
    @Published var data = AnalyticsData.mock
    @Published var growth = CreatorGrowthSnapshot.mock
    @Published var cohorts: [RetentionCohort] = RetentionCohort.mock
    @Published var attribution: [SourceAttribution] = SourceAttribution.mock
    @Published var selectedPlatform: SocialPlatform? = nil
    @Published var dateRange = "Jun 10 – Jun 16, 2024"
    @Published var isLoading = false
    @Published var loadErrorMessage: String?

    private let repository: AnalyticsRepository

    init(repository: AnalyticsRepository = AnalyticsRepositoryProvider.shared.repository) {
        self.repository = repository
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

    @MainActor
    func reload() async {
        isLoading = true
        loadErrorMessage = nil
        do {
            data = try await repository.fetchDashboard()
            growth = try await repository.fetchCreatorGrowth()
            cohorts = try await repository.fetchRetentionCohorts()
            attribution = try await repository.fetchAttribution()
        } catch {
            if AppEnvironment.current == .dev {
                data = .mock
                growth = .mock
                cohorts = RetentionCohort.mock
                attribution = SourceAttribution.mock
            } else {
                loadErrorMessage = "Unable to load analytics right now."
            }
        }
        isLoading = false
    }
}
