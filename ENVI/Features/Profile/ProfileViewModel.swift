import SwiftUI
import Combine

/// ViewModel for the Profile screen.
final class ProfileViewModel: ObservableObject {
    @Published var user = User.mock
    @Published var themeManager = ThemeManager.shared
    @Published var isConnectingPlatform = false
    @Published var connectionErrorMessage: String?
    @Published var connections: [PlatformConnection] = []

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

    /// Populate `connections` with an entry for every platform, merging any
    /// existing state from `user.connectedPlatforms`.
    @MainActor
    func loadConnections() {
        let existing = Dictionary(
            user.connectedPlatforms.map { ($0.platform, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        connections = SocialPlatform.allCases.map { platform in
            existing[platform] ?? PlatformConnection(platform: platform)
        }
    }

    func signOut() {
        try? AuthManager.shared.signOut()
    }

    // MARK: - Platform Actions

    @MainActor
    func connectPlatform(_ platform: SocialPlatform) async {
        guard !isConnectingPlatform else { return }
        isConnectingPlatform = true
        connectionErrorMessage = nil
        defer { isConnectingPlatform = false }

        do {
            let updated = try await SocialOAuthManager.shared.connect(platform: platform)
            applyConnectionUpdate(updated, for: platform)
        } catch {
            connectionErrorMessage = "Unable to connect \(platform.rawValue). Please try again."
        }
    }

    @MainActor
    func disconnectPlatform(_ platform: SocialPlatform) async {
        guard !isConnectingPlatform else { return }
        isConnectingPlatform = true
        connectionErrorMessage = nil
        defer { isConnectingPlatform = false }

        do {
            try await SocialOAuthManager.shared.disconnect(platform: platform)
            let disconnected = PlatformConnection(platform: platform)
            applyConnectionUpdate(disconnected, for: platform)
        } catch {
            connectionErrorMessage = "Unable to disconnect \(platform.rawValue). Please try again."
        }
    }

    @MainActor
    func refreshPlatformToken(_ platform: SocialPlatform) async {
        connectionErrorMessage = nil

        do {
            let refreshed = try await SocialOAuthManager.shared.refreshToken(platform: platform)
            applyConnectionUpdate(refreshed, for: platform)
        } catch {
            connectionErrorMessage = "Unable to refresh \(platform.rawValue) token. Please reconnect."
        }
    }

    // MARK: - Helpers

    @MainActor
    private func applyConnectionUpdate(_ updated: PlatformConnection, for platform: SocialPlatform) {
        // Update the connections array
        if let index = connections.firstIndex(where: { $0.platform == platform }) {
            connections[index] = updated
        }
        // Keep user.connectedPlatforms in sync
        if let index = user.connectedPlatforms.firstIndex(where: { $0.platform == platform }) {
            user.connectedPlatforms[index] = updated
        }
    }
}
