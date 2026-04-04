import Foundation

final class SocialOAuthManager {
    static let shared = SocialOAuthManager()

    private init() {}

    enum OAuthError: Error {
        case unsupportedPlatform
        case invalidResponse
    }

    func connect(platform: SocialPlatform) async throws -> PlatformConnection {
        guard platform == .instagram else {
            throw OAuthError.unsupportedPlatform
        }

        let response: OAuthConnectionResponse = try await APIClient.shared.request(
            endpoint: "oauth/instagram/connect",
            method: .post,
            body: Optional<String>.none,
            requiresAuth: true
        )

        return PlatformConnection(
            platform: .instagram,
            isConnected: true,
            handle: response.handle,
            followerCount: response.followerCount
        )
    }
}

private struct OAuthConnectionResponse: Decodable {
    let handle: String
    let followerCount: Int?
}
