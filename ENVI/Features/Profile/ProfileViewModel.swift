import SwiftUI
import Combine

/// ViewModel for the Profile screen.
final class ProfileViewModel: ObservableObject {
    @Published var user = User.mock
    @Published var themeManager = ThemeManager.shared

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
    ]

    func signOut() {
        UserDefaultsManager.shared.resetAll()
    }
}
