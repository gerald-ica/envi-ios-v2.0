import SwiftUI

/// Reusable empty state placeholder for the ENVI design system.
/// Displays a system icon, title, and optional subtitle centered in the available space.
struct ENVIEmptyState: View {
    let icon: String
    let title: String
    var subtitle: String?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: ENVISpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Text(title)
                .font(.interMedium(15))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            if let subtitle {
                Text(subtitle)
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ENVISpacing.xxxl)
    }
}

#Preview {
    ENVIEmptyState(
        icon: "tray",
        title: "No items yet",
        subtitle: "Create your first item to get started."
    )
    .preferredColorScheme(.dark)
}
