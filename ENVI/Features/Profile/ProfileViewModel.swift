import SwiftUI
import Combine

/// ViewModel for the Profile screen.
final class ProfileViewModel: ObservableObject {
    @Published var user = User.mock
    @Published var themeManager = ThemeManager.shared
    @Published var isConnectingPlatform = false
    @Published var connectionErrorMessage: String?

    struct SettingsItem: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
    }

    let settingsItems: [SettingsItem] = [
        SettingsItem(title: "Account Settings", icon: "person.circle"),
        SettingsItem(title: "Subscription", icon: "crown"),
        SettingsItem(title: "Notifications", icon: "bell"),
        SettingsItem(title: "AI Preferences", icon: "brain"),
        SettingsItem(title: "Privacy & Security", icon: "lock.shield"),
    ]

    func signOut() {
        try? AuthManager.shared.signOut()
    }

    @MainActor
    func connectPlatform(_ platform: SocialPlatform) async {
        guard !isConnectingPlatform else { return }
        isConnectingPlatform = true
        connectionErrorMessage = nil
        defer { isConnectingPlatform = false }

        do {
            let updated = try await SocialOAuthManager.shared.connect(platform: platform)
            if let index = user.connectedPlatforms.firstIndex(where: { $0.platform == platform }) {
                user.connectedPlatforms[index].isConnected = updated.isConnected
                user.connectedPlatforms[index].handle = updated.handle
                user.connectedPlatforms[index].followerCount = updated.followerCount
            }
        } catch {
            connectionErrorMessage = "Unable to connect \(platform.rawValue). Please try again."
        }
    }
}
