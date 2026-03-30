import SwiftUI

/// Settings section of the Profile screen.
struct SettingsSection: View {
    let items: [ProfileViewModel.SettingsItem]
    @Environment(\.colorScheme) private var colorScheme

    @State private var activeAlert: SettingsAlert?

    private enum SettingsAlert: Identifiable {
        case accountSettings
        case notifications
        case aiPreferences
        case privacyAndSecurity
        case helpAndSupport
        case about

        var id: String {
            switch self {
            case .accountSettings: return "accountSettings"
            case .notifications: return "notifications"
            case .aiPreferences: return "aiPreferences"
            case .privacyAndSecurity: return "privacyAndSecurity"
            case .helpAndSupport: return "helpAndSupport"
            case .about: return "about"
            }
        }

        var title: String {
            switch self {
            case .accountSettings: return "Account Settings"
            case .notifications: return "Notifications"
            case .aiPreferences: return "AI Preferences"
            case .privacyAndSecurity: return "Privacy & Security"
            case .helpAndSupport: return "Help & Support"
            case .about: return "About"
            }
        }

        var message: String {
            switch self {
            case .accountSettings: return "Account settings coming soon."
            case .notifications: return "Notification preferences coming soon."
            case .aiPreferences: return "AI preferences coming soon."
            case .privacyAndSecurity: return "Privacy & security settings coming soon."
            case .helpAndSupport: return "Help & support coming soon."
            case .about:
                let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                return "ENVI v\(version) (\(build))"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("SETTINGS")
                .font(.spaceMono(11))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            ForEach(items) { item in
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    activeAlert = alertType(for: item.title)
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
        .alert(item: $activeAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func alertType(for title: String) -> SettingsAlert? {
        switch title {
        case "Account Settings": return .accountSettings
        case "Notifications": return .notifications
        case "AI Preferences": return .aiPreferences
        case "Privacy & Security": return .privacyAndSecurity
        case "Help & Support": return .helpAndSupport
        case "About": return .about
        default: return nil
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
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        themeManager.mode = mode
                    }) {
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
