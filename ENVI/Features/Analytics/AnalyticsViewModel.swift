import SwiftUI
import Combine

/// ViewModel for the Analytics dashboard.
final class AnalyticsViewModel: ObservableObject {
    @Published var data = AnalyticsData.mock
    @Published var selectedPlatform: SocialPlatform? = nil
    @Published var isLoading = false
    @Published var error: String? = nil

    var platforms: [SocialPlatform?] {
        [nil, .instagram, .tiktok, .youtube]
    }

    // MARK: - Filtered Data

    /// Returns analytics data filtered by the currently selected platform.
    var filteredData: AnalyticsData {
        guard let platform = selectedPlatform else { return data }

        let filteredEngagement = data.dailyEngagement // Daily metrics aren't platform-specific in mock
        let filteredCalendar = data.calendarDays.filter { day in
            !day.hasContent || day.platform == platform
        }

        return AnalyticsData(
            reach: data.reach,
            engagement: data.engagement,
            engagementRate: data.engagementRate,
            dailyEngagement: filteredEngagement,
            calendarDays: filteredCalendar
        )
    }

    // MARK: - Date Range

    /// Dynamic date range derived from actual calendar data dates.
    var dateRange: String {
        let dates = data.calendarDays.map(\.date)
        guard let earliest = dates.min(), let latest = dates.max() else {
            return "No data"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = ", yyyy"
        return "\(formatter.string(from: earliest)) – \(formatter.string(from: latest))\(yearFormatter.string(from: latest))"
    }

    // MARK: - Actions

    func platformLabel(_ platform: SocialPlatform?) -> String {
        platform?.rawValue ?? "All"
    }

    /// Refresh analytics data from the server, falling back to mock data.
    func refresh() async {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        defer { Task { @MainActor in isLoading = false } }

        do {
            let analyticsData: AnalyticsData = try await APIClient.shared.get("/analytics")
            await MainActor.run { self.data = analyticsData }
        } catch {
            // Fall back to mock data while backend is unavailable
            await MainActor.run {
                self.data = AnalyticsData.mock
                // Don't surface error for mock fallback during development
            }
        }
    }
}
