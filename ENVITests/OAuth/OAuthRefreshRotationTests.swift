import XCTest
@testable import ENVI

/// Phase 07 — iOS side of refresh-token rotation behaviour.
///
/// The actual reuse-detection logic lives in Cloud Functions (see
/// `functions/src/__tests__/oauthRefreshRotation.test.ts`). From the iOS
/// side we care about ERROR MAPPING: the broker returns 401 with
/// `{ error: "REFRESH_TOKEN_REUSE" }`, and `SocialOAuthManager.refreshToken`
/// must translate that into `OAuthError.tokenExpired(platform)` so the UI
/// triggers a reauth flow.
///
/// We don't drive a live URLSession here — the public API doesn't expose
/// enough hooks to stub the HTTP response without `FirebaseApp.configure`.
/// Instead we rely on the broker-side tests for the wire-level invariants
/// and assert the TYPE shape of `OAuthError.tokenExpired` here.
final class OAuthRefreshRotationTests: XCTestCase {

    func testTokenExpiredErrorExistsAndIsLocalizable() {
        let err = SocialOAuthManager.OAuthError.tokenExpired(.tiktok)
        XCTAssertFalse(err.localizedDescription.isEmpty)
        XCTAssertTrue(err.localizedDescription.contains("TikTok"))
        XCTAssertTrue(err.localizedDescription.contains("reconnect") || err.localizedDescription.contains("expired"))
    }

    @MainActor
    func testRefreshTokenUsesMockPathWhenFlagEnabled() async throws {
        FeatureFlags.shared.connectorsUseMockOAuth = true
        defer { FeatureFlags.shared.connectorsUseMockOAuth = true }

        let manager = SocialOAuthManager(
            sessionFactory: { NoopOAuthSession() },
            featureFlagGate: { true }
        )
        let connection = try await manager.refreshToken(platform: .tiktok)
        XCTAssertEqual(connection.platform, .tiktok)
        XCTAssertTrue(connection.isConnected)
    }
}

private final class NoopOAuthSession: OAuthSession {
    func start(authorizationURL: URL, callbackScheme: String) async throws -> URL {
        authorizationURL
    }
    func cancel() {}
}
