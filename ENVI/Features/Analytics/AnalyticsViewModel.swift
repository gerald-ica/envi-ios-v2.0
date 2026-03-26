import SwiftUI
import Combine

/// ViewModel for the Analytics dashboard.
final class AnalyticsViewModel: ObservableObject {
    @Published var data = AnalyticsData.mock
    @Published var selectedPlatform: SocialPlatform? = nil
    @Published var dateRange = "Jun 10 – Jun 16, 2024"

    var platforms: [SocialPlatform?] {
        [nil, .instagram, .tiktok, .youtube]
    }

    func platformLabel(_ platform: SocialPlatform?) -> String {
        platform?.rawValue ?? "All"
    }
}
