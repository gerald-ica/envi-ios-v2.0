import SwiftUI

/// Settings section of the Profile screen with NavigationLink to Analytics.
/// Shared across: Main App Profile (17), Secondary Screens page (18).
struct ProfileSettingsSection: View {
    let items: [ProfileViewModel.SettingsItem]
    @Environment(\.colorScheme) private var colorScheme
    @State private var showAccountManagement = false

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("SETTINGS")
                .font(.spaceMono(11))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            ForEach(items) { item in
                Button(action: {
                    if item.title == "Account Settings" {
                        showAccountManagement = true
                    }
                }) {
                    settingsRow(icon: item.icon, title: item.title)
                }
            }

            // View Analytics — NavigationLink pushing AnalyticsView
            NavigationLink {
                AnalyticsView()
            } label: {
                settingsRow(icon: "chart.bar.xaxis", title: "View Analytics")
            }
        }
        .sheet(isPresented: $showAccountManagement) {
            AccountManagementView()
        }
    }

    @ViewBuilder
    private func settingsRow(icon: String, title: String) -> some View {
        HStack(spacing: ENVISpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))
                .frame(width: 24)

            Text(title)
                .font(.interRegular(15))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))
        }
        .padding(.vertical, ENVISpacing.sm)
    }
}

/// Settings section kept for backward compat — maps to ProfileSettingsSection.
struct SettingsSection: View {
    let items: [ProfileViewModel.SettingsItem]

    var body: some View {
        ProfileSettingsSection(items: items)
    }
}

/// Appearance toggle for Light / Dark / System.
struct AppearanceToggle: View {
    @ObservedObject var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("APPEARANCE")
                .font(.spaceMono(11))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            HStack(spacing: 0) {
                ForEach(ThemeManager.AppearanceMode.allCases, id: \.self) { mode in
                    Button(action: { themeManager.mode = mode }) {
                        Text(mode.rawValue.capitalized)
                            .font(.interMedium(13))
                            .foregroundColor(
                                themeManager.mode == mode
                                    ? .white
                                    : ENVITheme.textLight(for: colorScheme)
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, ENVISpacing.sm)
                            .background(
                                themeManager.mode == mode
                                    ? ENVITheme.primary(for: colorScheme)
                                    : .clear
                            )
                    }
                }
            }
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        }
    }
}
