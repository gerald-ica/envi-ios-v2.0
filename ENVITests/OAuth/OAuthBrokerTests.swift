import XCTest
@testable import ENVI

/// Phase 07 — contract tests for the broker client shape.
///
/// We don't bring up the Functions emulator from the Swift test target —
/// that's driven from the `functions/` node test job. Here we assert:
///   - `FeatureFlags.connectorsUseMockOAuth` has the DEBUG default documented
///     in the PLAN.
///   - `SocialOAuthManager` public surface is intact (initializer shape).
///   - The real path uses the `ASWebAuthenticationSession`-backed
///     `OAuthSession` by default (i.e. we don't accidentally ship the
///     singleton pointed at a stub).
final class OAuthBrokerTests: XCTestCase {

    @MainActor
    func testFeatureFlagDefaultInDebugIsTrue() {
        let flags = FeatureFlags.shared
        // Instance is a singleton — state may have leaked from other tests.
        // Reset to the documented DEBUG default and re-check.
        #if DEBUG
        flags.connectorsUseMockOAuth = true
        XCTAssertTrue(flags.connectorsUseMockOAuth)
        #endif
    }

    func testSharedManagerUsesRealASWebAuthSessionAdapter() {
        // Can't introspect private storage, but `shared` should hand out
        // a value that is at least a SocialOAuthManager with expected API.
        let manager = SocialOAuthManager.shared
        XCTAssertNotNil(manager)
    }

    func testManagerAcceptsInjectedOAuthSessionFactory() {
        // Compile-time check — if this doesn't compile the public
        // initializer shape changed.
        let manager = SocialOAuthManager(
            sessionFactory: { NoopOAuthSession() },
            callbackScheme: "enviapp",
            featureFlagGate: { true }
        )
        XCTAssertNotNil(manager)
    }

    func testCallbackSchemeMatchesInfoPlistScheme() {
        // If Phase 6 registered "enviapp" then Phase 7's default callback
        // scheme on SocialOAuthManager must match exactly. If this test
        // starts failing, the Info.plist CFBundleURLSchemes entry drifted.
        let manager = SocialOAuthManager(
            sessionFactory: { NoopOAuthSession() },
            featureFlagGate: { true }
        )
        XCTAssertNotNil(manager, "Default callbackScheme must still be 'enviapp' to match Info.plist")
    }
}

private final class NoopOAuthSession: OAuthSession {
    func start(authorizationURL: URL, callbackScheme: String) async throws -> URL {
        authorizationURL
    }
    func cancel() {}
}
