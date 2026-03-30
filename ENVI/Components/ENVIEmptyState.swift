import SwiftUI

/// Reusable empty state component for screens with no data.
/// Displays an icon, title, subtitle, and optional action button.
struct ENVIEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: ENVISpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            VStack(spacing: ENVISpacing.sm) {
                Text(title)
                    .font(.spaceMonoBold(18))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text(subtitle)
                    .font(.interRegular(14))
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))
                    .multilineTextAlignment(.center)
            }

            if let actionTitle = actionTitle, let action = action {
                ENVIButton(actionTitle, action: action)
            }
        }
        .padding(ENVISpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ENVIEmptyState(
        icon: "photo.on.rectangle",
        title: "No Content Yet",
        subtitle: "Import photos and videos to build your content library",
        actionTitle: "Import",
        action: {}
    )
    .preferredColorScheme(.dark)
}
