import SwiftUI

/// Grouped notification list with today / earlier / this week sections,
/// swipe-to-mark-read, and tap-to-navigate.
struct NotificationListView: View {

    @ObservedObject var viewModel: NotificationViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
                header

                if viewModel.isLoadingNotifications {
                    loadingState
                } else if viewModel.notifications.isEmpty {
                    emptyState
                } else {
                    notificationSections
                }
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .task { await viewModel.loadNotifications() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("NOTIFICATIONS")
                .font(.spaceMonoBold(18))
                .tracking(-1)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Spacer()

            if viewModel.unreadCount > 0 {
                Text("\(viewModel.unreadCount) unread")
                    .font(.interMedium(12))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .padding(.horizontal, ENVISpacing.sm)
                    .padding(.vertical, ENVISpacing.xs)
                    .background(ENVITheme.surfaceHigh(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Sections

    private var notificationSections: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
            if !viewModel.todayNotifications.isEmpty {
                sectionView(title: "Today", items: viewModel.todayNotifications)
            }
            if !viewModel.earlierNotifications.isEmpty {
                sectionView(title: "Yesterday", items: viewModel.earlierNotifications)
            }
            if !viewModel.thisWeekNotifications.isEmpty {
                sectionView(title: "This Week", items: viewModel.thisWeekNotifications)
            }
            if !viewModel.olderNotifications.isEmpty {
                sectionView(title: "Earlier", items: viewModel.olderNotifications)
            }
        }
    }

    private func sectionView(title: String, items: [AppNotification]) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Text(title.uppercased())
                .font(.spaceMonoBold(11))
                .tracking(1)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .padding(.horizontal, ENVISpacing.xl)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, notification in
                    notificationRow(notification)

                    if index < items.count - 1 {
                        Divider()
                            .background(ENVITheme.border(for: colorScheme))
                            .padding(.horizontal, ENVISpacing.md)
                    }
                }
            }
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            .padding(.horizontal, ENVISpacing.xl)
        }
    }

    // MARK: - Row

    private func notificationRow(_ notification: AppNotification) -> some View {
        HStack(spacing: ENVISpacing.md) {
            // Type icon
            Circle()
                .fill(iconColor(notification.type).opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: notification.type.systemImage)
                        .font(.system(size: 14))
                        .foregroundColor(iconColor(notification.type))
                )

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(notification.title)
                    .font(.interMedium(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text(notification.body)
                    .font(.interRegular(12))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .lineLimit(2)
            }

            Spacer()

            // Unread indicator
            if !notification.isRead {
                Circle()
                    .fill(ENVITheme.text(for: colorScheme))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, ENVISpacing.md)
        .padding(.vertical, ENVISpacing.md)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing) {
            if !notification.isRead {
                Button {
                    Task { await viewModel.markAsRead(notification) }
                } label: {
                    Label("Read", systemImage: "envelope.open")
                }
                .tint(ENVITheme.surfaceHigh(for: colorScheme))
            }
        }
    }

    // MARK: - States

    private var loadingState: some View {
        HStack {
            ProgressView()
            Text("Loading notifications...")
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    private var emptyState: some View {
        VStack(spacing: ENVISpacing.md) {
            Image(systemName: "bell.slash")
                .font(.system(size: 32))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Text("No notifications yet")
                .font(.interMedium(15))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("You'll see updates about your content, milestones, and more here.")
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ENVISpacing.xxxxl)
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Helpers

    private func iconColor(_ type: NotificationType) -> Color {
        switch type {
        case .publishSuccess, .milestoneReached:
            return .green
        case .publishFailed, .tokenExpiry:
            return .red
        case .scheduleReminder, .weeklyReport:
            return ENVITheme.text(for: colorScheme)
        case .contentGap:
            return .orange
        case .trendAlert:
            return .blue
        }
    }
}
