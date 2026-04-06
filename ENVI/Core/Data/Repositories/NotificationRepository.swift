import Foundation

// MARK: - Protocol

/// Repository contract for notifications, automation rules, and reminders.
protocol NotificationRepository {
    func fetchNotifications() async throws -> [AppNotification]
    func markRead(notificationID: UUID) async throws
    func fetchAutomationRules() async throws -> [AutomationRule]
    func createRule(_ rule: AutomationRule) async throws -> AutomationRule
    func updateRule(_ rule: AutomationRule) async throws -> AutomationRule
    func fetchReminders() async throws -> [ReminderSchedule]
    func createReminder(_ reminder: ReminderSchedule) async throws -> ReminderSchedule
}

// MARK: - Mock Implementation (Dev)

final class MockNotificationRepository: NotificationRepository {

    func fetchNotifications() async throws -> [AppNotification] {
        try await Task.sleep(for: .milliseconds(400))
        return AppNotification.mock
    }

    func markRead(notificationID: UUID) async throws {
        try await Task.sleep(for: .milliseconds(200))
    }

    func fetchAutomationRules() async throws -> [AutomationRule] {
        try await Task.sleep(for: .milliseconds(350))
        return AutomationRule.mock
    }

    func createRule(_ rule: AutomationRule) async throws -> AutomationRule {
        try await Task.sleep(for: .milliseconds(300))
        return rule
    }

    func updateRule(_ rule: AutomationRule) async throws -> AutomationRule {
        try await Task.sleep(for: .milliseconds(300))
        return rule
    }

    func fetchReminders() async throws -> [ReminderSchedule] {
        try await Task.sleep(for: .milliseconds(350))
        return ReminderSchedule.mock
    }

    func createReminder(_ reminder: ReminderSchedule) async throws -> ReminderSchedule {
        try await Task.sleep(for: .milliseconds(300))
        return reminder
    }
}

// MARK: - API Implementation (Staging / Prod)

final class APINotificationRepository: NotificationRepository {

    func fetchNotifications() async throws -> [AppNotification] {
        try await APIClient.shared.request(
            endpoint: "notifications/",
            method: .get,
            requiresAuth: true
        )
    }

    func markRead(notificationID: UUID) async throws {
        try await APIClient.shared.requestVoid(
            endpoint: "notifications/read",
            method: .post,
            body: ["id": notificationID.uuidString],
            requiresAuth: true
        )
    }

    func fetchAutomationRules() async throws -> [AutomationRule] {
        try await APIClient.shared.request(
            endpoint: "automations/rules",
            method: .get,
            requiresAuth: true
        )
    }

    func createRule(_ rule: AutomationRule) async throws -> AutomationRule {
        try await APIClient.shared.request(
            endpoint: "automations/rules",
            method: .post,
            body: rule,
            requiresAuth: true
        )
    }

    func updateRule(_ rule: AutomationRule) async throws -> AutomationRule {
        try await APIClient.shared.request(
            endpoint: "automations/rules/\(rule.id.uuidString)",
            method: .put,
            body: rule,
            requiresAuth: true
        )
    }

    func fetchReminders() async throws -> [ReminderSchedule] {
        try await APIClient.shared.request(
            endpoint: "automations/reminders",
            method: .get,
            requiresAuth: true
        )
    }

    func createReminder(_ reminder: ReminderSchedule) async throws -> ReminderSchedule {
        try await APIClient.shared.request(
            endpoint: "automations/reminders",
            method: .post,
            body: reminder,
            requiresAuth: true
        )
    }
}

// MARK: - Factory

enum NotificationRepositoryFactory {
    static func make() -> NotificationRepository {
        switch AppEnvironment.current {
        case .dev:
            return MockNotificationRepository()
        case .staging, .prod:
            return APINotificationRepository()
        }
    }
}
