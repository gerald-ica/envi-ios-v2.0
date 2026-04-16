import Foundation

final class SocialOAuthManager {
    static let shared = SocialOAuthManager()
    static var useMockOAuth: Bool = true

    private init() {}

    // MARK: - Errors

    enum OAuthError: Error, LocalizedError {
        case invalidResponse
        case connectionFailed(SocialPlatform)
        case tokenExpired(SocialPlatform)
        case disconnectFailed(SocialPlatform)

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
            }
        }
    }

    // MARK: - Connect

    func connect(platform: SocialPlatform) async throws -> PlatformConnection {
        if Self.useMockOAuth {
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

        let response: OAuthConnectionResponse = try await APIClient.shared.request(
            endpoint: "oauth/\(platform.apiSlug)/connect",
            method: .post,
            body: Optional<String>.none,
            requiresAuth: true
        )

        return PlatformConnection(
            platform: platform,
            isConnected: true,
            handle: response.handle,
            followerCount: response.followerCount,
            tokenExpiresAt: response.tokenExpiresAt,
            lastRefreshedAt: Date(),
            scopes: response.scopes ?? []
        )
    }

    // MARK: - Disconnect

    func disconnect(platform: SocialPlatform) async throws {
        if Self.useMockOAuth {
            try await Task.sleep(for: .milliseconds(500))
            return
        }

        do {
            try await APIClient.shared.requestVoid(
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
        if Self.useMockOAuth {
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
            response = try await APIClient.shared.request(
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
            isConnected: true,
            handle: response.handle,
            followerCount: response.followerCount,
            tokenExpiresAt: response.tokenExpiresAt,
            lastRefreshedAt: Date(),
            scopes: response.scopes ?? []
        )
    }

    // MARK: - Connection Status

    func connectionStatus(platform: SocialPlatform) async throws -> PlatformConnection {
        if Self.useMockOAuth {
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

        let response: OAuthConnectionResponse = try await APIClient.shared.request(
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

// MARK: - API Response

private struct OAuthConnectionResponse: Decodable {
    let handle: String?
    let followerCount: Int?
    let isConnected: Bool?
    let tokenExpiresAt: Date?
    let lastRefreshedAt: Date?
    let scopes: [String]?
}
