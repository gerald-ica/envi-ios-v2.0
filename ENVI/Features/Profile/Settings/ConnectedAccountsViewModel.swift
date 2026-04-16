import Foundation
import SwiftUI

/// View model for ``ConnectedAccountsView`` (Phase 12).
///
/// Responsibilities
/// ----------------
/// - Load the full list of `PlatformConnection` objects, one per
///   `SocialPlatform.allCases`, by calling `SocialOAuthManager.connectionStatus`
///   on every platform in parallel.
/// - Expose the four action verbs the view binds to: `connect`,
///   `reconnect`, `refresh`, `disconnect`. Each delegates to the shared
///   `SocialOAuthManager` and refires telemetry via the manager's existing
///   instrumentation (see Phase 12-07 wiring in `SocialOAuthManager.swift`).
/// - Surface a single `errorMessage` banner for the view to render.
///
/// Threading
/// ---------
/// `@MainActor`-isolated so `@Published` mutations are safe; the async
/// manager calls hop off-main via `Task.detached` implicitly via `await`.
@MainActor
final class ConnectedAccountsViewModel: ObservableObject {

    // MARK: - Published state

    @Published var connections: [PlatformConnection] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    /// Platform slugs currently undergoing a connect/refresh/disconnect
    /// action. Used to throttle taps and render spinner affordances.
    @Published var inFlight: Set<String> = []

    // MARK: - Dependencies

    private let oauth: SocialOAuthManager

    init(oauth: SocialOAuthManager = .shared) {
        self.oauth = oauth
    }

    // MARK: - Loading

    /// Fetch the latest connection state for every known platform in parallel.
    /// Platforms that 404 or throw are rendered as disconnected stubs so the
    /// view shows a full grid regardless of partial backend outages.
    func load() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        // Parallel fan-out via TaskGroup. `SocialOAuthManager.connectionStatus`
        // already mock-gates internally, so calling unconditionally is fine.
        let platforms = SocialPlatform.allCases
        var fetched: [PlatformConnection] = []
        fetched.reserveCapacity(platforms.count)

        await withTaskGroup(of: PlatformConnection.self) { group in
            for platform in platforms {
                group.addTask { [oauth] in
                    do {
                        return try await oauth.connectionStatus(platform: platform)
                    } catch {
                        return PlatformConnection(platform: platform)
                    }
                }
            }
            for await connection in group {
                fetched.append(connection)
            }
        }

        // Preserve the enum's declaration order so UI rendering is stable
        // across refreshes (TaskGroup does not guarantee ordering).
        let order = Dictionary(
            uniqueKeysWithValues: SocialPlatform.allCases.enumerated()
                .map { ($0.element, $0.offset) }
        )
        fetched.sort { (order[$0.platform] ?? 0) < (order[$1.platform] ?? 0) }
        connections = fetched
    }

    // MARK: - Actions

    /// Begin a fresh OAuth flow. Used for both disconnected platforms AND
    /// the `revokedAt != nil` RECONNECT state — reconnect is just a connect
    /// that clobbers the prior revoked connection in Firestore.
    func connect(_ platform: SocialPlatform) async {
        await run(platform: platform) {
            _ = try await self.oauth.connect(platform: platform)
        }
    }

    /// Alias kept explicit so the view's state machine reads cleanly:
    /// `revokedAt != nil → reconnect(platform)` even though the underlying
    /// SDK call is identical.
    func reconnect(_ platform: SocialPlatform) async {
        await connect(platform)
    }

    /// Refresh the access token (Phase 7 `/oauth/{provider}/refresh`). The
    /// daily refresh cron normally handles this; the manual affordance is
    /// a fallback for the amber `EXPIRING SOON` state.
    func refresh(_ platform: SocialPlatform) async {
        await run(platform: platform) {
            _ = try await self.oauth.refreshToken(platform: platform)
        }
    }

    func disconnect(_ platform: SocialPlatform) async {
        await run(platform: platform) {
            try await self.oauth.disconnect(platform: platform)
        }
    }

    // MARK: - Shared action runner

    /// Wraps an action with in-flight bookkeeping, error capture, and a
    /// reload. All four verbs route through here so the view's state only
    /// updates in one place.
    private func run(
        platform: SocialPlatform,
        action: @escaping () async throws -> Void
    ) async {
        let slug = platform.apiSlug
        inFlight.insert(slug)
        defer { inFlight.remove(slug) }

        do {
            try await action()
            await load()
        } catch {
            if let localized = (error as? LocalizedError)?.errorDescription {
                errorMessage = localized
            } else {
                errorMessage = "Something went wrong. Please try again."
            }
        }
    }
}
