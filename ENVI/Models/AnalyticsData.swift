import Foundation

/// Holds analytics data for the dashboard.
struct AnalyticsData: Codable {
    let reach: KPI
    let engagement: KPI
    let engagementRate: KPI
    let dailyEngagement: [DailyMetric]
    let calendarDays: [CalendarDay]

    struct KPI: Identifiable, Codable {
        let id: UUID
        let label: String
        let value: String
        let change: String
        let isPositive: Bool

        init(id: UUID = UUID(), label: String, value: String, change: String, isPositive: Bool) {
            self.id = id
            self.label = label
            self.value = value
            self.change = change
            self.isPositive = isPositive
        }
    }

    struct DailyMetric: Identifiable, Codable {
        let id: UUID
        let day: String      // Mon, Tue, etc.
        let value: Double

        init(id: UUID = UUID(), day: String, value: Double) {
            self.id = id
            self.day = day
            self.value = value
        }
    }

    struct CalendarDay: Identifiable, Codable {
        let id: UUID
        let date: Date
        let hasContent: Bool
        let platform: SocialPlatform?

        init(id: UUID = UUID(), date: Date, hasContent: Bool, platform: SocialPlatform?) {
            self.id = id
            self.date = date
            self.hasContent = hasContent
            self.platform = platform
        }
    }

    static let mock = AnalyticsData(
        reach: KPI(label: "Reach", value: "847.2K", change: "+23.1%", isPositive: true),
        engagement: KPI(label: "Engagement", value: "12.4K", change: "+18.4%", isPositive: true),
        engagementRate: KPI(label: "Rate", value: "4.2%", change: "-0.3%", isPositive: false),
        dailyEngagement: [
            DailyMetric(day: "Mon", value: 1200),
            DailyMetric(day: "Tue", value: 1800),
            DailyMetric(day: "Wed", value: 2400),
            DailyMetric(day: "Thu", value: 1600),
            DailyMetric(day: "Fri", value: 3200),
            DailyMetric(day: "Sat", value: 2800),
            DailyMetric(day: "Sun", value: 2100),
        ],
        calendarDays: {
            var days: [CalendarDay] = []
            let cal = Calendar.current
            let now = Date()
            for i in 0..<30 {
                if let date = cal.date(byAdding: .day, value: -i, to: now) {
                    let hasContent = [0, 2, 3, 5, 7, 10, 12, 15, 18, 21, 24, 27].contains(i)
                    let platform: SocialPlatform? = hasContent ? [.instagram, .tiktok, .youtube].randomElement() : nil
                    days.append(CalendarDay(date: date, hasContent: hasContent, platform: platform))
                }
            }
            return days
        }()
    )
}
