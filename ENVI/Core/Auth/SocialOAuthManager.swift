import Foundation

/// Entry point for social-connector OAuth flows.
///
/// Phase 07 reshaped the internals but preserved the public shape:
///   - `connect(platform:)`
///   - `disconnect(platform:)`
///   - `refreshToken(platform:)`
///   - `connectionStatus(platform:)`
///
/// What changed in Phase 07
/// ------------------------
/// - The static `useMockOAuth: Bool` flag was removed. Mock vs. real is
///   now driven by `FeatureFlags.shared.connectorsUseMockOAuth` so we
///   can flip behaviour via Remote Config without a resubmission.
/// - The real path hits the Cloud Functions broker (Phase 07):
///     `POST /oauth/{slug}/start` → `ASWebAuthenticationSession` →
///     provider 302 → Functions exchange + KMS persist →
///     `GET /oauth/{slug}/status` on the way back in.
/// - `OAuthSession` is now injectable in `init` so tests can swap in a
///   recording stub. A singleton `.shared` is still available and uses
///   the real `ASWebAuthenticationSessionAdapter`.
/// Not marked `final` so unit-test subclasses (Phase 08 `TikTokConnector`
/// test harness) can override `connectViaBroker(platform:)` and
/// `refreshToken(platform:)` without a full protocol extraction. Production
/// code should still instantiate via `.shared` or the primary `init`.
class SocialOAuthManager {

    /// Process-wide singleton. Backed by the real web auth adapter; prefer
    /// `SocialOAuthManager(session:apiClient:)` from tests.
    nonisolated(unsafe) static let shared = SocialOAuthManager(
        apiClient: SocialOAuthManager.sharedBrokerAPIClient
    )

    /// Shared `APIClient` instance pointed at the Cloud Functions broker
    /// (`AppConfig.connectorFunctionsBaseURL`). Reused by connectors
    /// (TikTok, X, LinkedIn, Meta, Instagram, Threads, Facebook) so every
    /// broker-routed HTTP call shares the same connection pool and decoder.
    ///
    /// Prefer this over `APIClient.shared` for anything that talks to
    /// Cloud Functions — `APIClient.shared` targets the legacy app-API host
    /// and is not served by the broker.
    nonisolated(unsafe) static let sharedBrokerAPIClient: APIClient = SocialOAuthManager.makeDefaultAPIClient()

    private let apiClient: APIClient
    private let sessionFactory: @MainActor () -> OAuthSession
    private let callbackScheme: String
    private let featureFlagGate: @Sendable () async -> Bool
    private let tiktokConnectorFlagGate: @Sendable () async -> Bool
    private let xConnectorFlagGate: @Sendable () async -> Bool

    /// Builds an APIClient that targets the Cloud Functions broker with a
    /// decoder that parses ISO-8601 date fields.
    ///
    /// Why a dedicated client:
    ///   - Base URL. The default `APIClient.shared` targets
    ///     `AppConfig.apiBaseURL` (`https://api-<env>.envi.app/v1`), which is
    ///     the legacy product-API host and does NOT serve `/oauth/*`. The
    ///     broker lives at `AppConfig.connectorFunctionsBaseURL`
    ///     (`https://<region>-<project>.cloudfunctions.net`). Pointing the
    ///     OAuth `POST /oauth/:provider/start` call at the wrong host was
    ///     the cause of the connect-button hang: the domain wouldn't
    ///     resolve and URLSession ran out its retry budget before surfacing
    ///     the error.
    ///   - Date strategy. The broker emits `tokenExpiresAt` /
    ///     `lastRefreshedAt` as ISO-8601 strings (see
    ///     `status.ts#timestampToIso`), so decoding into
    ///     `PlatformConnection.tokenExpiresAt: Date?` needs an explicit
    ///     strategy.
    ///
    /// Scoped to the manager rather than flipping `APIClient`'s default so
    /// we don't disturb the 16+ other repositories in the app that parse
    /// server-derived dates with their own conventions.
    static func makeDefaultAPIClient() -> APIClient {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return APIClient(
            baseURL: AppConfig.connectorFunctionsBaseURL,
            decoder: decoder
        )
    }

    /// - Parameters:
    ///   - apiClient: API client used for broker calls. Tests inject a
    ///     URLSession-backed stub.
    ///   - sessionFactory: Produces a fresh `OAuthSession` per connect
    ///     attempt. The default builds an `ASWebAuthenticationSessionAdapter`
    ///     on the main actor.
    ///   - callbackScheme: Custom URL scheme the provider redirects back to
    ///     (matches `CFBundleURLSchemes` in Info.plist).
    ///   - featureFlagGate: Override the mock/real gate. Defaults to
    ///     `FeatureFlags.shared.connectorsUseMockOAuth` (main-actor read).
    init(
        apiClient: APIClient = .shared,
        sessionFactory: @escaping @MainActor () -> OAuthSession = {
            ASWebAuthenticationSessionAdapter()
        },
        callbackScheme: String = "enviapp",
        featureFlagGate: @escaping @Sendable () async -> Bool = {
            await MainActor.run { FeatureFlags.shared.connectorsUseMockOAuth }
        },
        tiktokConnectorFlagGate: @escaping @Sendable () async -> Bool = {
            await MainActor.run { FeatureFlags.shared.useTikTokConnector }
        },
        xConnectorFlagGate: @escaping @Sendable () async -> Bool = {
            await MainActor.run { FeatureFlags.shared.useXConnector }
        }
    ) {
        self.apiClient = apiClient
        self.sessionFactory = sessionFactory
        self.callbackScheme = callbackScheme
        self.featureFlagGate = featureFlagGate
        self.tiktokConnectorFlagGate = tiktokConnectorFlagGate
        self.xConnectorFlagGate = xConnectorFlagGate
    }

    /// Phase 08 — resolves the real-TikTok-connector feature flag. Kept as a
    /// distinct hook so tests can flip it without touching global
    /// FeatureFlags state.
    fileprivate func useTikTokConnectorFlag() async -> Bool {
        await tiktokConnectorFlagGate()
    }

    /// Phase 09 — resolves the real-X-connector feature flag.
    fileprivate func useXConnectorFlag() async -> Bool {
        await xConnectorFlagGate()
    }

    // MARK: - Errors

    enum OAuthError: Error, LocalizedError {
        case invalidResponse
        case connectionFailed(SocialPlatform)
        case tokenExpired(SocialPlatform)
        case disconnectFailed(SocialPlatform)
        case userCancelled(SocialPlatform)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Received an invalid response from the server."
            case .connectionFailed(let platform):
                return "Failed to connect \(platform.rawValue)."
            case .tokenExpired(let platform):
                return "\(platform.rawValue) token has expired. Please reconnect."
            case .disconnectFailed(let platform):
                return "Failed to disconnect \(platform.rawValue)."
            case .userCancelled(let platform):
                return "You cancelled the \(platform.rawValue) sign-in."
            }
        }
    }

    // MARK: - Connect

    func connect(platform: SocialPlatform) async throws -> PlatformConnection {
        if await featureFlagGate() {
            try await Task.sleep(for: .seconds(1))
            let connection = PlatformConnection(
                platform: platform,
                isConnected: true,
                handle: mockHandle(for: platform),
                followerCount: Int.random(in: 1000...50000),
                tokenExpiresAt: Date().addingTimeInterval(86400 * 30),
                lastRefreshedAt: Date(),
                scopes: mockScopes(for: platform)
            )
            // Phase 12 — even in mock mode, emit the canonical success event
            // so downstream dashboards and QA fixtures behave identically.
            TelemetryManager.shared.trackOAuth(
                .oauthConnectSuccess,
                platform: platform.apiSlug
            )
            return connection
        }

        do {
            let connection: PlatformConnection
            // Phase 08 — route TikTok through its dedicated connector when the
            // feature flag is on. The connector delegates back to this class
            // via `connectViaBroker(platform:)` (the `bypassConnectorRoute`
            // internal entry point), so no recursion.
            if platform == .tiktok, await useTikTokConnectorFlag() {
                connection = try await TikTokConnector.shared.connect()
            } else if platform == .x, await useXConnectorFlag() {
                // Phase 09 — same pattern for X. `XTwitterConnector.connect()`
                // calls `connectViaBroker(platform: .x)` directly to avoid
                // looping back through this dispatch.
                connection = try await XTwitterConnector.shared.connect()
            } else {
                connection = try await connectViaBroker(platform: platform)
            }
            TelemetryManager.shared.trackOAuth(
                .oauthConnectSuccess,
                platform: platform.apiSlug
            )
            return connection
        } catch {
            TelemetryManager.shared.trackOAuth(
                .oauthConnectFailure,
                platform: platform.apiSlug,
                error: Self.sanitizedErrorCode(error)
            )
            throw error
        }
    }

    /// Internal entry point used both by `connect(platform:)` (when no
    /// per-provider connector is registered) AND by `TikTokConnector` so
    /// it can reuse the broker round-trip without re-triggering its own
    /// routing logic.
    ///
    /// Kept `internal` (default) so same-module Phase 08 / Phase 09
    /// connectors can share the implementation. External callers should
    /// continue to use `connect(platform:)`.
    func connectViaBroker(platform: SocialPlatform) async throws -> PlatformConnection {
        // 1. Ask the broker to mint a PKCE + state package and hand us an
        //    authorization URL. The broker persists the PKCE verifier
        //    keyed by the `stateToken` returned here.
        let startResponse: OAuthStartResponse
        do {
            startResponse = try await apiClient.request(
                endpoint: "oauth/\(platform.apiSlug)/start",
                method: .post,
                body: Optional<String>.none,
                requiresAuth: true
            )
        } catch {
            throw OAuthError.connectionFailed(platform)
        }

        guard let authURL = URL(string: startResponse.authorizationUrl) else {
            throw OAuthError.invalidResponse
        }

        // 2. Drive the system web auth session. On iOS this surfaces the
        //    provider's sign-in UI inside an SFSafariViewController-style
        //    sheet that the provider can share cookies with.
        do {
            _ = try await runSession(authorizationURL: authURL)
        } catch OAuthSessionError.userCancelled {
            throw OAuthError.userCancelled(platform)
        } catch {
            throw OAuthError.connectionFailed(platform)
        }

        // 3. By this point the broker has already written the encrypted
        //    token set to Firestore via its `callback` handler. Fetch the
        //    status to learn the user's handle, scopes, expiry, etc.
        let statusResponse: OAuthConnectionResponse
        do {
            statusResponse = try await apiClient.request(
                endpoint: "oauth/\(platform.apiSlug)/status",
                method: .get,
                requiresAuth: true
            )
        } catch {
            throw OAuthError.connectionFailed(platform)
        }

        return PlatformConnection(
            platform: platform,
            isConnected: statusResponse.isConnected ?? true,
            handle: statusResponse.handle,
            followerCount: statusResponse.followerCount,
            tokenExpiresAt: statusResponse.tokenExpiresAt,
            lastRefreshedAt: statusResponse.lastRefreshedAt ?? Date(),
            scopes: statusResponse.scopes ?? []
        )
    }

    // MARK: - Disconnect

    func disconnect(platform: SocialPlatform) async throws {
        if await featureFlagGate() {
            try await Task.sleep(for: .milliseconds(500))
            TelemetryManager.shared.trackOAuth(
                .oauthDisconnect,
                platform: platform.apiSlug
            )
            return
        }

        do {
            try await apiClient.requestVoid(
                endpoint: "oauth/\(platform.apiSlug)/disconnect",
                method: .post,
                body: Optional<String>.none,
                requiresAuth: true
            )
            TelemetryManager.shared.trackOAuth(
                .oauthDisconnect,
                platform: platform.apiSlug
            )
        } catch {
            // Phase 12 — disconnect failure is rare but observable. We still
            // emit a disconnect event tagged with the error so dashboards can
            // distinguish user-initiated vs. server-side successes.
            TelemetryManager.shared.trackOAuth(
                .oauthDisconnect,
                platform: platform.apiSlug,
                error: Self.sanitizedErrorCode(error)
            )
            throw OAuthError.disconnectFailed(platform)
        }
    }

    // MARK: - Refresh Token

    func refreshToken(platform: SocialPlatform) async throws -> PlatformConnection {
        if await featureFlagGate() {
            try await Task.sleep(for: .milliseconds(500))
            TelemetryManager.shared.trackOAuth(
                .oauthRefreshSuccess,
                platform: platform.apiSlug
            )
            return PlatformConnection(
                platform: platform,
                isConnected: true,
                handle: mockHandle(for: platform),
                followerCount: Int.random(in: 1000...50000),
                tokenExpiresAt: Date().addingTimeInterval(86400 * 30),
                lastRefreshedAt: Date(),
                scopes: mockScopes(for: platform)
            )
        }

        let response: OAuthConnectionResponse

        do {
            response = try await apiClient.request(
                endpoint: "oauth/\(platform.apiSlug)/refresh",
                method: .post,
                body: Optional<String>.none,
                requiresAuth: true
            )
        } catch {
            TelemetryManager.shared.trackOAuth(
                .oauthRefreshFailure,
                platform: platform.apiSlug,
                error: Self.sanitizedErrorCode(error)
            )
            throw OAuthError.tokenExpired(platform)
        }

        TelemetryManager.shared.trackOAuth(
            .oauthRefreshSuccess,
            platform: platform.apiSlug
        )
        return PlatformConnection(
            platform: platform,
            isConnected: response.isConnected ?? true,
            handle: response.handle,
            followerCount: response.followerCount,
            tokenExpiresAt: response.tokenExpiresAt,
            lastRefreshedAt: response.lastRefreshedAt ?? Date(),
            scopes: response.scopes ?? []
        )
    }

    // MARK: - Telemetry Helpers

    /// Reduces an arbitrary Swift error to a short sanitized code. Keeps raw
    /// provider error bodies out of analytics (no-PII rule).
    fileprivate static func sanitizedErrorCode(_ error: Error) -> String {
        switch error {
        case OAuthError.userCancelled: return "user_cancelled"
        case OAuthError.tokenExpired:  return "auth_expired"
        case OAuthError.invalidResponse: return "invalid_response"
        case OAuthError.connectionFailed: return "connection_failed"
        case OAuthError.disconnectFailed: return "disconnect_failed"
        default:
            let raw = String(describing: type(of: error))
            // Defense-in-depth: never emit an arbitrary string longer than
            // 32 chars into analytics parameters.
            return String(raw.prefix(32))
        }
    }

    // MARK: - Connection Status

    func connectionStatus(platform: SocialPlatform) async throws -> PlatformConnection {
        if await featureFlagGate() {
            return PlatformConnection(
                platform: platform,
                isConnected: true,
                handle: mockHandle(for: platform),
                followerCount: Int.random(in: 1000...50000),
                tokenExpiresAt: Date().addingTimeInterval(86400 * 30),
                lastRefreshedAt: Date(),
                scopes: mockScopes(for: platform)
            )
        }

        let response: OAuthConnectionResponse = try await apiClient.request(
            endpoint: "oauth/\(platform.apiSlug)/status",
            method: .get,
            requiresAuth: true
        )

        return PlatformConnection(
            platform: platform,
            isConnected: response.isConnected ?? false,
            handle: response.handle,
            followerCount: response.followerCount,
            tokenExpiresAt: response.tokenExpiresAt,
            lastRefreshedAt: response.lastRefreshedAt,
            scopes: response.scopes ?? []
        )
    }

    // MARK: - Private

    /// Hop to the main actor to run the injected `OAuthSession`. The
    /// session factory produces a fresh instance per connect attempt;
    /// `ASWebAuthenticationSession` is UIKit-backed so the factory must
    /// run on main. Once we have a session, its `start(...)` call handles
    /// its own actor isolation — the protocol doesn't pin us to main.
    private func runSession(authorizationURL: URL) async throws -> URL {
        let scheme = callbackScheme
        let factory = sessionFactory
        let session: OAuthSession = await MainActor.run { factory() }
        return try await session.start(
            authorizationURL: authorizationURL,
            callbackScheme: scheme
        )
    }

    // MARK: - Mock Helpers

    private func mockHandle(for platform: SocialPlatform) -> String {
        switch platform {
        case .instagram: return "envi_user"
        case .facebook: return "ENVI Page"
        case .tiktok: return "envi_user"
        case .x: return "envi_user"
        case .threads: return "envi_user"
        case .linkedin: return "ENVI User"
        case .youtube: return "ENVI Channel"
        }
    }

    private func mockScopes(for platform: SocialPlatform) -> [String] {
        switch platform {
        case .instagram: return ["basic", "publish_media", "insights"]
        case .facebook: return ["pages_show_list", "pages_manage_posts", "pages_read_engagement"]
        case .tiktok: return ["user.info.basic", "video.list", "video.publish"]
        case .x: return ["tweet.read", "tweet.write", "users.read"]
        case .threads: return ["threads_basic", "threads_publish"]
        case .linkedin: return ["r_liteprofile", "w_member_social"]
        case .youtube: return ["youtube.readonly", "youtube.upload"]
        }
    }
}

// MARK: - API Responses

/// Broker `/oauth/:provider/start` response.
private struct OAuthStartResponse: Decodable {
    let authorizationUrl: String
    let stateToken: String
}

/// Shared shape returned by `/status` and `/refresh`. Kept permissive
/// (all optional) so minor broker additions don't break decoding.
private struct OAuthConnectionResponse: Decodable {
    let handle: String?
    let followerCount: Int?
    let isConnected: Bool?
    let tokenExpiresAt: Date?
    let lastRefreshedAt: Date?
    let scopes: [String]?
    let requiresReauth: Bool?
}
