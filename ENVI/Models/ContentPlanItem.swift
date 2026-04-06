import Foundation

struct ContentPlanItem: Identifiable {
    enum Status: String {
        case draft
        case ready
        case scheduled
    }

    let id: UUID
    var title: String
    var platform: SocialPlatform
    var scheduledAt: Date
    var status: Status
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        title: String,
        platform: SocialPlatform,
        scheduledAt: Date,
        status: Status,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.title = title
        self.platform = platform
        self.scheduledAt = scheduledAt
        self.status = status
        self.sortOrder = sortOrder
    }
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
                status: .ready,
                sortOrder: 0
            ),
            ContentPlanItem(
                id: UUID(),
                title: "Weekly trend recap",
                platform: .tiktok,
                scheduledAt: calendar.date(byAdding: .day, value: 2, to: now) ?? now,
                status: .draft,
                sortOrder: 1
            ),
            ContentPlanItem(
                id: UUID(),
                title: "Behind-the-scenes short",
                platform: .youtube,
                scheduledAt: calendar.date(byAdding: .day, value: 3, to: now) ?? now,
                status: .scheduled,
                sortOrder: 2
            )
        ]
    }
}
