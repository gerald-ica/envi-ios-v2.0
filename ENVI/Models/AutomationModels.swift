import Foundation

// MARK: - ENVI-0451 Notification Type

/// Categories of in-app notifications.
enum NotificationType: String, Codable, CaseIterable, Identifiable {
    case publishSuccess
    case publishFailed
    case scheduleReminder
    case tokenExpiry
    case milestoneReached
    case weeklyReport
    case contentGap
    case trendAlert

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .publishSuccess:   return "Publish Success"
        case .publishFailed:    return "Publish Failed"
        case .scheduleReminder: return "Schedule Reminder"
        case .tokenExpiry:      return "Token Expiry"
        case .milestoneReached: return "Milestone Reached"
        case .weeklyReport:     return "Weekly Report"
        case .contentGap:       return "Content Gap"
        case .trendAlert:       return "Trend Alert"
        }
    }

    var systemImage: String {
        switch self {
        case .publishSuccess:   return "checkmark.circle.fill"
        case .publishFailed:    return "xmark.circle.fill"
        case .scheduleReminder: return "clock.fill"
        case .tokenExpiry:      return "key.fill"
        case .milestoneReached: return "star.fill"
        case .weeklyReport:     return "chart.bar.fill"
        case .contentGap:       return "exclamationmark.triangle.fill"
        case .trendAlert:       return "arrow.up.right.circle.fill"
        }
    }
}

// MARK: - ENVI-0452 App Notification

/// A single in-app notification displayed to the user.
struct AppNotification: Identifiable, Codable, Hashable {
    let id: UUID
    let type: NotificationType
    let title: String
    let body: String
    var isRead: Bool
    let createdAt: Date
    let actionURL: String?
}

// MARK: - Mock Data

extension AppNotification {
    static let mock: [AppNotification] = [
        AppNotification(
            id: UUID(),
            type: .publishSuccess,
            title: "Post Published",
            body: "Your reel has been published to Instagram successfully.",
            isRead: false,
            createdAt: Date(),
            actionURL: nil
        ),
        AppNotification(
            id: UUID(),
            type: .milestoneReached,
            title: "1K Followers!",
            body: "Congratulations! You reached 1,000 followers on TikTok.",
            isRead: false,
            createdAt: Date().addingTimeInterval(-3600),
            actionURL: nil
        ),
        AppNotification(
            id: UUID(),
            type: .scheduleReminder,
            title: "Post Due Tomorrow",
            body: "Your Instagram carousel is scheduled for 9:00 AM tomorrow.",
            isRead: true,
            createdAt: Date().addingTimeInterval(-7200),
            actionURL: nil
        ),
        AppNotification(
            id: UUID(),
            type: .tokenExpiry,
            title: "Reconnect TikTok",
            body: "Your TikTok connection expires in 3 days. Reconnect to avoid interruptions.",
            isRead: false,
            createdAt: Date().addingTimeInterval(-86400),
            actionURL: nil
        ),
        AppNotification(
            id: UUID(),
            type: .weeklyReport,
            title: "Weekly Performance",
            body: "Your content reached 12.4K accounts this week — up 18% from last week.",
            isRead: true,
            createdAt: Date().addingTimeInterval(-172800),
            actionURL: nil
        ),
        AppNotification(
            id: UUID(),
            type: .publishFailed,
            title: "Publish Failed",
            body: "Your post to X failed due to a rate limit. Tap to retry.",
            isRead: false,
            createdAt: Date().addingTimeInterval(-259200),
            actionURL: nil
        ),
        AppNotification(
            id: UUID(),
            type: .contentGap,
            title: "Content Gap Detected",
            body: "You haven't posted on Instagram in 5 days. Stay consistent to keep engagement up.",
            isRead: true,
            createdAt: Date().addingTimeInterval(-345600),
            actionURL: nil
        ),
        AppNotification(
            id: UUID(),
            type: .trendAlert,
            title: "Trending Audio",
            body: "A trending audio in your niche is gaining traction. Create content now!",
            isRead: false,
            createdAt: Date().addingTimeInterval(-432000),
            actionURL: nil
        ),
    ]
}

// MARK: - ENVI-0460 Automation Trigger Type

/// The event type that triggers an automation rule.
enum AutomationTriggerType: String, Codable, CaseIterable, Identifiable {
    case postPublished
    case postFailed
    case followerMilestone
    case engagementDrop
    case scheduleTime
    case tokenExpiring

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .postPublished:     return "Post Published"
        case .postFailed:        return "Post Failed"
        case .followerMilestone: return "Follower Milestone"
        case .engagementDrop:    return "Engagement Drop"
        case .scheduleTime:      return "Scheduled Time"
        case .tokenExpiring:     return "Token Expiring"
        }
    }
}

// MARK: - ENVI-0461 Automation Action Type

/// The action executed when an automation rule fires.
enum AutomationActionType: String, Codable, CaseIterable, Identifiable {
    case sendNotification
    case retryPublish
    case crossPost
    case generateReport
    case pauseSchedule
    case sendEmail

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sendNotification: return "Send Notification"
        case .retryPublish:     return "Retry Publish"
        case .crossPost:        return "Cross-Post"
        case .generateReport:   return "Generate Report"
        case .pauseSchedule:    return "Pause Schedule"
        case .sendEmail:        return "Send Email"
        }
    }
}

// MARK: - ENVI-0462 Automation Trigger

/// Describes when an automation rule should fire.
struct AutomationTrigger: Identifiable, Codable, Hashable {
    let id: UUID
    let type: AutomationTriggerType
    var conditions: [String: String]

    init(id: UUID = UUID(), type: AutomationTriggerType, conditions: [String: String] = [:]) {
        self.id = id
        self.type = type
        self.conditions = conditions
    }
}

// MARK: - ENVI-0463 Automation Action

/// Describes what happens when an automation rule fires.
struct AutomationAction: Identifiable, Codable, Hashable {
    let id: UUID
    let type: AutomationActionType
    var parameters: [String: String]

    init(id: UUID = UUID(), type: AutomationActionType, parameters: [String: String] = [:]) {
        self.id = id
        self.type = type
        self.parameters = parameters
    }
}

// MARK: - ENVI-0464 Automation Rule

/// A user-defined automation rule combining triggers and actions.
struct AutomationRule: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var trigger: AutomationTrigger
    var actions: [AutomationAction]
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        trigger: AutomationTrigger,
        actions: [AutomationAction] = [],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.trigger = trigger
        self.actions = actions
        self.isEnabled = isEnabled
    }
}

extension AutomationRule {
    static let mock: [AutomationRule] = [
        AutomationRule(
            name: "Retry failed posts",
            trigger: AutomationTrigger(type: .postFailed),
            actions: [AutomationAction(type: .retryPublish)],
            isEnabled: true
        ),
        AutomationRule(
            name: "Milestone celebration",
            trigger: AutomationTrigger(type: .followerMilestone, conditions: ["threshold": "1000"]),
            actions: [AutomationAction(type: .sendNotification, parameters: ["message": "You hit a milestone!"])],
            isEnabled: true
        ),
        AutomationRule(
            name: "Engagement alert",
            trigger: AutomationTrigger(type: .engagementDrop, conditions: ["dropPercent": "20"]),
            actions: [
                AutomationAction(type: .sendNotification, parameters: ["message": "Engagement dropped"]),
                AutomationAction(type: .generateReport),
            ],
            isEnabled: false
        ),
    ]
}

// MARK: - ENVI-0470 Reminder Frequency

/// How often a reminder repeats.
enum ReminderFrequency: String, Codable, CaseIterable, Identifiable {
    case daily
    case weekly
    case biweekly
    case monthly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily:    return "Daily"
        case .weekly:   return "Weekly"
        case .biweekly: return "Bi-weekly"
        case .monthly:  return "Monthly"
        }
    }
}

// MARK: - ENVI-0471 Reminder Schedule

/// A recurring reminder the user sets for content creation tasks.
struct ReminderSchedule: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var frequency: ReminderFrequency
    var time: Date
    var daysOfWeek: [Int]   // 1 = Sunday … 7 = Saturday
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        title: String,
        frequency: ReminderFrequency = .daily,
        time: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date(),
        daysOfWeek: [Int] = [],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.title = title
        self.frequency = frequency
        self.time = time
        self.daysOfWeek = daysOfWeek
        self.isEnabled = isEnabled
    }
}

extension ReminderSchedule {
    static let mock: [ReminderSchedule] = [
        ReminderSchedule(title: "Plan weekly content", frequency: .weekly, daysOfWeek: [2]),
        ReminderSchedule(title: "Check analytics", frequency: .daily),
        ReminderSchedule(title: "Review scheduled posts", frequency: .biweekly, daysOfWeek: [2, 5], isEnabled: false),
    ]
}
