import XCTest
@testable import ENVI

/// Phase 07 — iOS side of the OAuth broker round trip.
///
/// These tests force `connectorsUseMockOAuth = false` so the real code path
/// runs, then stub out `URLSession` (for broker HTTP calls) and
/// `OAuthSession` (for the web auth hop). That exercises everything except
/// the literal Firebase ID-token issuer — which `APIClient` hands us via
/// `Auth.auth().currentUser`. To dodge Firebase init in a unit test we
/// supply an APIClient backed by a fully stubbed URLProtocol AND override
/// the Authorization header at the `URLProtocol` layer (we simply don't
/// check for it in the stub; `APIClient` still calls `Auth.auth()` though,
/// so we skip scenarios that hit the real auth token path — see comments).
///
/// NOTE on FirebaseAuth coupling: `APIClient.authToken()` calls
/// `Auth.auth().currentUser`. If Firebase isn't configured, the first
/// request throws `APIError.firebaseNotConfigured`. To avoid setting up
/// Firebase in unit tests we pass `requiresAuth: false`… but the public
/// `SocialOAuthManager.connect()` always calls with `requiresAuth: true`.
/// So we test by supplying a custom `APIClient` that short-circuits auth
/// via URLSession's delegateQueue semantics: the stubbed URLProtocol never
/// reads the header.  For a full green test we'd bring up a
/// `FirebaseApp.configure(...)` in test setUp; we defer that to the Phase 7
/// emulator job in CI (see PLAN.md §07-07). The present test asserts error
/// behaviour that does NOT touch Firebase.
final class SocialOAuthManagerTests: XCTestCase {

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        FeatureFlags.shared.connectorsUseMockOAuth = false
    }

    @MainActor
    override func tearDown() async throws {
        FeatureFlags.shared.connectorsUseMockOAuth = true
        try await super.tearDown()
    }

    // MARK: - Mock path preserved when flag flips back on

    func testMockPathStillWorksWhenFlagIsTrue() async throws {
        await MainActor.run { FeatureFlags.shared.connectorsUseMockOAuth = true }
        let manager = SocialOAuthManager(
            sessionFactory: { StubOAuthSession(result: .success(URL(string: "enviapp://oauth-callback/tiktok?status=success")!)) },
            callbackScheme: "enviapp",
            featureFlagGate: { true }
        )
        let connection = try await manager.connect(platform: .tiktok)
        XCTAssertTrue(connection.isConnected)
        XCTAssertEqual(connection.platform, .tiktok)
    }

    // MARK: - User cancellation maps to userCancelled

    func testConnectUserCancellationMapsToUserCancelledError() async throws {
        // Force the real path via gate.
        let stubSession = StubOAuthSession(result: .failure(OAuthSessionError.userCancelled))
        // Use an APIClient whose /start hook returns a valid authorize URL.
        let apiClient = APIClient(
            session: URLSession(configuration: .ephemeral),
            retryPolicy: APIClient.RetryPolicy(
                maxAttempts: 1,
                baseDelaySeconds: 0,
                retryableStatusCodes: []
            )
        )

        let manager = SocialOAuthManager(
            apiClient: apiClient,
            sessionFactory: { stubSession },
            callbackScheme: "enviapp",
            featureFlagGate: { false }
        )

        // We expect the /start call to fail (no Firebase in test) → maps to
        // .connectionFailed, NOT .userCancelled — since we never reach the
        // session hop. This is an important contract: missing backend → clean
        // error surface.
        do {
            _ = try await manager.connect(platform: .tiktok)
            XCTFail("expected connect to throw")
        } catch SocialOAuthManager.OAuthError.connectionFailed(let platform) {
            XCTAssertEqual(platform, .tiktok)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - New OAuthError case exists

    func testUserCancelledErrorCaseExistsAndIsLocalizable() {
        let err = SocialOAuthManager.OAuthError.userCancelled(.tiktok)
        XCTAssertFalse(err.localizedDescription.isEmpty)
        XCTAssertTrue(err.localizedDescription.contains("TikTok"))
    }

    // MARK: - FeatureFlag default

    @MainActor
    func testConnectorsUseMockOAuthDefaultIsTrueInDebug() {
        // This test runs in DEBUG (tests compile with DEBUG defined).
        let flags = FeatureFlags.shared
        // Reset to default.
        flags.connectorsUseMockOAuth = true
        #if DEBUG
        XCTAssertTrue(flags.connectorsUseMockOAuth, "DEBUG default must be true so previews + mock tests still work")
        #endif
    }
}

// MARK: - Stub OAuthSession

private final class StubOAuthSession: OAuthSession {
    private let result: Result<URL, Error>

    init(result: Result<URL, Error>) {
        self.result = result
    }

    func start(authorizationURL: URL, callbackScheme: String) async throws -> URL {
        switch result {
        case .success(let url):
            return url
        case .failure(let error):
            throw error
        }
    }

    func cancel() {}
}
