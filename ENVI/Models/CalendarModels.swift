import Foundation

// MARK: - Calendar View Mode

enum CalendarViewMode: String, CaseIterable, Identifiable {
    case day
    case week
    case month
    case quarter

    var id: String { rawValue }

    var displayName: String { rawValue.uppercased() }
}

// MARK: - Calendar Slot

struct CalendarSlot: Identifiable, Codable {
    let id: UUID
    var planItemID: UUID?
    var platform: SocialPlatform
    var scheduledAt: Date
    var status: ContentPlanItem.Status
    var campaignColor: String?
    var isOptimalTime: Bool
    var title: String

    init(
        id: UUID = UUID(),
        planItemID: UUID? = nil,
        platform: SocialPlatform,
        scheduledAt: Date,
        status: ContentPlanItem.Status,
        campaignColor: String? = nil,
        isOptimalTime: Bool = false,
        title: String = ""
    ) {
        self.id = id
        self.planItemID = planItemID
        self.platform = platform
        self.scheduledAt = scheduledAt
        self.status = status
        self.campaignColor = campaignColor
        self.isOptimalTime = isOptimalTime
        self.title = title
    }
}

// MARK: - Posting Streak

struct PostingStreak: Codable {
    let currentStreak: Int
    let longestStreak: Int
    let targetPerWeek: Int

    static let empty = PostingStreak(currentStreak: 0, longestStreak: 0, targetPerWeek: 5)
}

// MARK: - Content Gap

struct ContentGap: Identifiable, Codable {
    let id: UUID
    let date: Date
    let platform: SocialPlatform
    let suggestion: String

    init(
        id: UUID = UUID(),
        date: Date,
        platform: SocialPlatform,
        suggestion: String
    ) {
        self.id = id
        self.date = date
        self.platform = platform
        self.suggestion = suggestion
    }
}

// MARK: - Holiday Event

struct HolidayEvent: Identifiable, Codable {
    let id: UUID
    let name: String
    let date: Date
    let relevanceScore: Double

    init(
        id: UUID = UUID(),
        name: String,
        date: Date,
        relevanceScore: Double
    ) {
        self.id = id
        self.name = name
        self.date = date
        self.relevanceScore = relevanceScore
    }
}

// MARK: - Best Time Slot

struct BestTimeSlot: Codable, Identifiable {
    let platform: SocialPlatform
    let dayOfWeek: Int
    let hour: Int
    let score: Double

    var id: String { "\(platform.rawValue)-\(dayOfWeek)-\(hour)" }
}

// MARK: - Mock Data

extension CalendarSlot {
    static var mockSlots: [CalendarSlot] {
        let calendar = Calendar.current
        let now = Date()
        return [
            CalendarSlot(
                platform: .instagram,
                scheduledAt: calendar.date(byAdding: .hour, value: 2, to: now) ?? now,
                status: .scheduled,
                isOptimalTime: true,
                title: "Product teaser reel"
            ),
            CalendarSlot(
                platform: .tiktok,
                scheduledAt: calendar.date(byAdding: .day, value: 1, to: now) ?? now,
                status: .ready,
                isOptimalTime: false,
                title: "Weekly trend recap"
            ),
            CalendarSlot(
                platform: .youtube,
                scheduledAt: calendar.date(byAdding: .day, value: 2, to: now) ?? now,
                status: .draft,
                isOptimalTime: true,
                title: "Behind-the-scenes short"
            ),
            CalendarSlot(
                platform: .linkedin,
                scheduledAt: calendar.date(byAdding: .day, value: 3, to: now) ?? now,
                status: .scheduled,
                campaignColor: "#30217C",
                isOptimalTime: false,
                title: "Thought leadership post"
            ),
            CalendarSlot(
                platform: .x,
                scheduledAt: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
                status: .scheduled,
                isOptimalTime: true,
                title: "Thread on AI trends"
            ),
            CalendarSlot(
                platform: .threads,
                scheduledAt: calendar.date(byAdding: .day, value: 4, to: now) ?? now,
                status: .draft,
                isOptimalTime: false,
                title: "Community Q&A"
            ),
        ]
    }
}

extension PostingStreak {
    static let mock = PostingStreak(currentStreak: 12, longestStreak: 30, targetPerWeek: 5)
}

extension ContentGap {
    static var mock: [ContentGap] {
        let calendar = Calendar.current
        let now = Date()
        return [
            ContentGap(
                date: calendar.date(byAdding: .day, value: 5, to: now) ?? now,
                platform: .instagram,
                suggestion: "Schedule a Reel for peak engagement"
            ),
            ContentGap(
                date: calendar.date(byAdding: .day, value: 7, to: now) ?? now,
                platform: .tiktok,
                suggestion: "No TikTok posts this week"
            ),
        ]
    }
}

extension HolidayEvent {
    static var mock: [HolidayEvent] {
        let calendar = Calendar.current
        let now = Date()
        return [
            HolidayEvent(
                name: "Earth Day",
                date: calendar.date(byAdding: .day, value: 10, to: now) ?? now,
                relevanceScore: 0.85
            ),
            HolidayEvent(
                name: "National Pet Day",
                date: calendar.date(byAdding: .day, value: 15, to: now) ?? now,
                relevanceScore: 0.6
            ),
        ]
    }
}

extension BestTimeSlot {
    static var mock: [BestTimeSlot] {
        [
            BestTimeSlot(platform: .instagram, dayOfWeek: 1, hour: 9, score: 0.92),
            BestTimeSlot(platform: .instagram, dayOfWeek: 1, hour: 12, score: 0.85),
            BestTimeSlot(platform: .instagram, dayOfWeek: 1, hour: 18, score: 0.78),
            BestTimeSlot(platform: .instagram, dayOfWeek: 2, hour: 10, score: 0.88),
            BestTimeSlot(platform: .instagram, dayOfWeek: 2, hour: 14, score: 0.70),
            BestTimeSlot(platform: .instagram, dayOfWeek: 3, hour: 9, score: 0.95),
            BestTimeSlot(platform: .instagram, dayOfWeek: 3, hour: 17, score: 0.82),
            BestTimeSlot(platform: .instagram, dayOfWeek: 4, hour: 11, score: 0.75),
            BestTimeSlot(platform: .instagram, dayOfWeek: 5, hour: 10, score: 0.90),
            BestTimeSlot(platform: .instagram, dayOfWeek: 5, hour: 15, score: 0.72),
            BestTimeSlot(platform: .tiktok, dayOfWeek: 1, hour: 19, score: 0.94),
            BestTimeSlot(platform: .tiktok, dayOfWeek: 2, hour: 20, score: 0.88),
            BestTimeSlot(platform: .tiktok, dayOfWeek: 3, hour: 18, score: 0.91),
            BestTimeSlot(platform: .tiktok, dayOfWeek: 4, hour: 21, score: 0.80),
            BestTimeSlot(platform: .tiktok, dayOfWeek: 5, hour: 19, score: 0.86),
            BestTimeSlot(platform: .youtube, dayOfWeek: 1, hour: 14, score: 0.76),
            BestTimeSlot(platform: .youtube, dayOfWeek: 3, hour: 15, score: 0.83),
            BestTimeSlot(platform: .youtube, dayOfWeek: 5, hour: 13, score: 0.79),
            BestTimeSlot(platform: .x, dayOfWeek: 1, hour: 8, score: 0.87),
            BestTimeSlot(platform: .x, dayOfWeek: 2, hour: 12, score: 0.81),
            BestTimeSlot(platform: .x, dayOfWeek: 4, hour: 9, score: 0.84),
            BestTimeSlot(platform: .linkedin, dayOfWeek: 2, hour: 8, score: 0.93),
            BestTimeSlot(platform: .linkedin, dayOfWeek: 3, hour: 10, score: 0.89),
            BestTimeSlot(platform: .linkedin, dayOfWeek: 4, hour: 8, score: 0.85),
        ]
    }
}
