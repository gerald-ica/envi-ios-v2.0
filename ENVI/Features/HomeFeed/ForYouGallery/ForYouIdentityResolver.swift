import Foundation

/// Resolves user-owned identity fields for Tab 1 cards.
struct ForYouIdentityResolver {
    typealias CurrentUserProvider = @MainActor () -> User?
    typealias FallbackNameProvider = @MainActor () -> String?

    struct Identity {
        let displayName: String
        let handle: String
    }

    private let currentUserProvider: CurrentUserProvider
    private let fallbackNameProvider: FallbackNameProvider

    init(
        currentUserProvider: @escaping CurrentUserProvider = { @MainActor in AuthManager.shared.currentUser() },
        fallbackNameProvider: @escaping FallbackNameProvider = { @MainActor in UserDefaultsManager.shared.userName }
    ) {
        self.currentUserProvider = currentUserProvider
        self.fallbackNameProvider = fallbackNameProvider
    }

    @MainActor
    func resolve(preferredPlatform: SocialPlatform?) -> Identity {
        if let user = currentUserProvider() {
            let displayName = user.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            if let platform = preferredPlatform,
               let connection = user.connectedPlatforms.first(where: { $0.platform == platform }),
               let handle = normalizedHandle(connection.handle) {
                return Identity(
                    displayName: displayName.isEmpty ? "You" : displayName,
                    handle: handle
                )
            }

            if let handle = normalizedHandle(user.handle) {
                return Identity(
                    displayName: displayName.isEmpty ? "You" : displayName,
                    handle: handle
                )
            }

            return Identity(displayName: displayName.isEmpty ? "You" : displayName, handle: "@you")
        }

        let fallbackName = fallbackNameProvider()?.trimmingCharacters(in: .whitespacesAndNewlines)
        return Identity(
            displayName: (fallbackName?.isEmpty == false) ? fallbackName! : "You",
            handle: "@you"
        )
    }

    private func normalizedHandle(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.hasPrefix("@") ? trimmed : "@\(trimmed)"
    }
}
