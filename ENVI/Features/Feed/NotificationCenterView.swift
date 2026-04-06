import SwiftUI

/// Activity-style notification center presented as a sheet from the feed.
struct NotificationCenterView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private let notifications: [NotificationItem] = [
        NotificationItem(
            icon: "play.rectangle.fill",
            title: "Your reel gained 1.2K views",
            subtitle: "Keep the momentum going",
            timestamp: "2h ago"
        ),
        NotificationItem(
            icon: "person.2.fill",
            title: "New follower milestone: 5,000",
            subtitle: "You're growing fast",
            timestamp: "5h ago"
        ),
        NotificationItem(
            icon: "chart.bar.fill",
            title: "Weekly analytics report ready",
            subtitle: "Tap to view your performance summary",
            timestamp: "1d ago"
        ),
        NotificationItem(
            icon: "checkmark.circle.fill",
            title: "Instagram post published successfully",
            subtitle: "Your scheduled post is now live",
            timestamp: "1d ago"
        ),
        NotificationItem(
            icon: "exclamationmark.triangle.fill",
            title: "TikTok token expires in 5 days",
            subtitle: "Reconnect to avoid interruptions",
            timestamp: "2d ago"
        ),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("NOTIFICATIONS")
                    .font(.spaceMonoBold(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ENVITheme.textLight(for: colorScheme))
                }
            }
            .padding(.horizontal, ENVISpacing.xl)
            .padding(.top, ENVISpacing.xl)
            .padding(.bottom, ENVISpacing.lg)

            Divider()
                .background(ENVITheme.border(for: colorScheme))

            // Notification list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(notifications) { item in
                        notificationRow(item)
                    }
                }
            }
        }
        .background(ENVITheme.background(for: colorScheme))
    }

    @ViewBuilder
    private func notificationRow(_ item: NotificationItem) -> some View {
        HStack(alignment: .top, spacing: ENVISpacing.md) {
            Image(systemName: item.icon)
                .font(.system(size: 20))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .frame(width: 36, height: 36)
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))

            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                Text(item.title)
                    .font(.interMedium(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text(item.subtitle)
                    .font(.interRegular(12))
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))
            }

            Spacer()

            Text(item.timestamp)
                .font(.spaceMono(11))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.xl)
        .padding(.vertical, ENVISpacing.md)

        Divider()
            .background(ENVITheme.border(for: colorScheme))
            .padding(.leading, ENVISpacing.xl + 36 + ENVISpacing.md)
    }
}

// MARK: - Model

private struct NotificationItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let timestamp: String
}
