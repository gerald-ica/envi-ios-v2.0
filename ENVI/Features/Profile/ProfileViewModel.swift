import SwiftUI
import Combine

/// ViewModel for the Profile screen.
///
/// Phase 14 — Plan 03: `user` is now optional and hydrated from the
/// real Firebase Auth session (via `AuthManager.currentUser()`). The
/// default is `nil`, so callers render a loading state until
/// `loadProfile()` completes. `User.mock` is no longer a
/// production-reachable default — it lives only in the Preview helper
/// (`ProfileViewModel.preview()`) and in the `User` model itself where
/// existing tests depend on it.
final class ProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoadingProfile: Bool = false
    @Published var profileLoadError: String?
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

    // MARK: - Hydration

    /// Pull the current user from the auth session and hydrate the
    /// connections list. Call from `.task` on the Profile root view.
    @MainActor
    func loadProfile() async {
        isLoadingProfile = true
        profileLoadError = nil
        defer { isLoadingProfile = false }

        if let hydrated = AuthManager.shared.currentUser() {
            self.user = hydrated
            loadConnections()
        } else {
            // No signed-in user. Leaving `user` nil is deliberate — the
            // audit flagged silent mock fallback as P0. The view renders
            // an empty state in this case.
            self.user = nil
            self.profileLoadError = "Not signed in. Please sign in to see your profile."
        }
    }

    /// Populate `connections` with an entry for every platform, merging any
    /// existing state from `user?.connectedPlatforms`.
    @MainActor
    func loadConnections() {
        let existing: [SocialPlatform: PlatformConnection]
        if let user {
            existing = Dictionary(
                user.connectedPlatforms.map { ($0.platform, $0) },
                uniquingKeysWith: { first, _ in first }
            )
        } else {
            existing = [:]
        }
        connections = SocialPlatform.allCases.map { platform in
            existing[platform] ?? PlatformConnection(platform: platform)
        }
    }

    @MainActor
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
        if var current = user,
           let index = current.connectedPlatforms.firstIndex(where: { $0.platform == platform }) {
            current.connectedPlatforms[index] = updated
            user = current
        }
    }

    // MARK: - Preview helper

    #if DEBUG
    /// SwiftUI Preview helper — injects `User.mock` so designers see
    /// realistic data in previews without triggering auth. NOT used in
    /// any production call path.
    @MainActor
    static func preview() -> ProfileViewModel {
        let vm = ProfileViewModel()
        vm.user = User.mock
        vm.loadConnections()
        return vm
    }
    #endif
}
