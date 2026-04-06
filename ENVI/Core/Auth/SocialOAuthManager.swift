import Foundation

final class SocialOAuthManager {
    static let shared = SocialOAuthManager()

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
