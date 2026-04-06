import Foundation

struct ContentPlanItem: Identifiable {
    enum Status: String {
        case draft
        case ready
        case scheduled
    }

    let id: UUID
    let title: String
    let platform: SocialPlatform
    let scheduledAt: Date
    let status: Status
}

extension ContentPlanItem {
    static var mockPlan: [ContentPlanItem] {
        let calendar = Calendar.current
        let now = Date()

        return [
            ContentPlanItem(
                id: UUID(),
                title: "Product teaser reel",
                platform: .instagram,
                scheduledAt: calendar.date(byAdding: .day, value: 1, to: now) ?? now,
                status: .ready
            ),
            ContentPlanItem(
                id: UUID(),
                title: "Weekly trend recap",
                platform: .tiktok,
                scheduledAt: calendar.date(byAdding: .day, value: 2, to: now) ?? now,
                status: .draft
            ),
            ContentPlanItem(
                id: UUID(),
                title: "Behind-the-scenes short",
                platform: .youtube,
                scheduledAt: calendar.date(byAdding: .day, value: 3, to: now) ?? now,
                status: .scheduled
            )
        ]
    }
}
