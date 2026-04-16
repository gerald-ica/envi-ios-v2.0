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
final class SocialOAuthManager {

    /// Process-wide singleton. Backed by the real web auth adapter; prefer
    /// `SocialOAuthManager(session:apiClient:)` from tests.
    static let shared = SocialOAuthManager(
        apiClient: SocialOAuthManager.makeDefaultAPIClient()
    )

    private let apiClient: APIClient
    private let sessionFactory: @MainActor () -> OAuthSession
    private let callbackScheme: String
    private let featureFlagGate: @Sendable () async -> Bool

    /// Builds an APIClient whose JSONDecoder uses ISO-8601 for `Date` fields.
    /// The broker emits `tokenExpiresAt` / `lastRefreshedAt` as ISO-8601
    /// strings (see `status.ts#timestampToIso`), so decoding into
    /// `PlatformConnection.tokenExpiresAt: Date?` needs an explicit strategy.
    ///
    /// Scoped to the manager rather than flipping `APIClient`'s default so
    /// we don't disturb the 16+ other repositories in the app that parse
    /// server-derived dates with their own conventions.
    private static func makeDefaultAPIClient() -> APIClient {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return APIClient(decoder: decoder)
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
        }
    ) {
        self.apiClient = apiClient
        self.sessionFactory = sessionFactory
        self.callbackScheme = callbackScheme
        self.featureFlagGate = featureFlagGate
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
            return
        }

        do {
            try await apiClient.requestVoid(
                endpoint: "oauth/\(platform.apiSlug)/disconnect",
                method: .post,
                body: Optional<String>.none,
                requiresAuth: true
            )
        } catch {
            throw OAuthError.disconnectFailed(platform)
        }
    }

    // MARK: - Refresh Token

    func refreshToken(platform: SocialPlatform) async throws -> PlatformConnection {
        if await featureFlagGate() {
            try await Task.sleep(for: .milliseconds(500))
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
            throw OAuthError.tokenExpired(platform)
        }

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
