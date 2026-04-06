import SwiftUI

/// Settings section of the Profile screen.
struct SettingsSection: View {
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
                    HStack(spacing: ENVISpacing.md) {
                        Image(systemName: item.icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(ENVITheme.textLight(for: colorScheme))
                            .frame(width: 24)

                        Text(item.title)
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
        }
        .sheet(isPresented: $showAccountManagement) {
            AccountManagementView()
        }
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
