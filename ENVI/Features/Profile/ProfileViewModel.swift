import SwiftUI

/// ViewModel for the Profile screen.
final class ProfileViewModel: ObservableObject {
    @Published var user = User.mock
    @Published var showSignOutConfirmation = false

    let themeManager = ThemeManager.shared

    struct SettingsItem: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
    }

    let settingsItems: [SettingsItem] = [
        SettingsItem(title: "Account Settings", icon: "person.circle"),
        SettingsItem(title: "Notifications", icon: "bell"),
        SettingsItem(title: "AI Preferences", icon: "brain"),
        SettingsItem(title: "Privacy & Security", icon: "lock.shield"),
        SettingsItem(title: "Help & Support", icon: "questionmark.circle"),
        SettingsItem(title: "About", icon: "info.circle"),
    ]

    func signOut() {
        UserDefaultsManager.shared.resetAll()
    }
}
