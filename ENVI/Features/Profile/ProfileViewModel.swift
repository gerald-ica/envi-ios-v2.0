import SwiftUI

/// ViewModel for the Profile screen.
final class ProfileViewModel: ObservableObject {
    @Published var user = User.mock
    @Published var showSignOutConfirmation = false
    @Published var isLoading = false
    @Published var error: String?

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

    // MARK: - Async Loading

    /// Load the user profile from the API, falling back to mock data.
    func loadProfile() async {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }

        do {
            let profile: User = try await APIClient.shared.get("/profile")
            await MainActor.run { self.user = profile }
        } catch {
            // Fall back to mock data while backend is unavailable
            await MainActor.run {
                self.user = User.mock
                // Don't surface error for mock fallback during development
            }
        }
    }

    /// Sign out the current user.
    func signOut() async {
        await AuthService.shared.signOut()
        UserDefaultsManager.shared.resetAll()
    }
}
