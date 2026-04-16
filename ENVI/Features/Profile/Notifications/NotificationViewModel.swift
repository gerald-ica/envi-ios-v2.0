import SwiftUI
import Combine

/// ViewModel for the notifications, automations, and reminders domain.
@MainActor
final class NotificationViewModel: ObservableObject {

    // MARK: - Published State

    @Published var notifications: [AppNotification] = []
    @Published var automationRules: [AutomationRule] = []
    @Published var reminders: [ReminderSchedule] = []

    @Published var isLoadingNotifications = false
    @Published var isLoadingRules = false
    @Published var isLoadingReminders = false
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let repository: NotificationRepository

    // MARK: - Init

    init(repository: NotificationRepository = NotificationRepositoryProvider.shared.repository) {
        self.repository = repository
    }

    // MARK: - Computed

    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    var todayNotifications: [AppNotification] {
        notifications.filter { Calendar.current.isDateInToday($0.createdAt) }
    }

    var earlierNotifications: [AppNotification] {
        notifications.filter {
            !Calendar.current.isDateInToday($0.createdAt)
                && Calendar.current.isDateInYesterday($0.createdAt)
        }
    }

    var thisWeekNotifications: [AppNotification] {
        let calendar = Calendar.current
        return notifications.filter {
            !calendar.isDateInToday($0.createdAt)
                && !calendar.isDateInYesterday($0.createdAt)
                && calendar.isDate($0.createdAt, equalTo: Date(), toGranularity: .weekOfYear)
        }
    }

    var olderNotifications: [AppNotification] {
        let calendar = Calendar.current
        return notifications.filter {
            !calendar.isDate($0.createdAt, equalTo: Date(), toGranularity: .weekOfYear)
        }
    }

    // MARK: - Notifications

    func loadNotifications() async {
        isLoadingNotifications = true
        errorMessage = nil
        do {
            notifications = try await repository.fetchNotifications()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingNotifications = false
    }

    func markAsRead(_ notification: AppNotification) async {
        do {
            try await repository.markRead(notificationID: notification.id)
            if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                notifications[index].isRead = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Automation Rules

    func loadRules() async {
        isLoadingRules = true
        errorMessage = nil
        do {
            automationRules = try await repository.fetchAutomationRules()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingRules = false
    }

    func createRule(_ rule: AutomationRule) async {
        do {
            let created = try await repository.createRule(rule)
            automationRules.append(created)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateRule(_ rule: AutomationRule) async {
        do {
            let updated = try await repository.updateRule(rule)
            if let index = automationRules.firstIndex(where: { $0.id == updated.id }) {
                automationRules[index] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleRule(_ rule: AutomationRule) async {
        var toggled = rule
        toggled.isEnabled.toggle()
        await updateRule(toggled)
    }

    func deleteRule(_ rule: AutomationRule) {
        automationRules.removeAll { $0.id == rule.id }
    }

    // MARK: - Reminders

    func loadReminders() async {
        isLoadingReminders = true
        errorMessage = nil
        do {
            reminders = try await repository.fetchReminders()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingReminders = false
    }

    func createReminder(_ reminder: ReminderSchedule) async {
        do {
            let created = try await repository.createReminder(reminder)
            reminders.append(created)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleReminder(_ reminder: ReminderSchedule) {
        if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
            reminders[index].isEnabled.toggle()
        }
    }

    func deleteReminder(_ reminder: ReminderSchedule) {
        reminders.removeAll { $0.id == reminder.id }
    }
}
