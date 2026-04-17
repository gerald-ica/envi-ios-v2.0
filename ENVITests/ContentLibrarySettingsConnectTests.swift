//
//  ContentLibrarySettingsConnectTests.swift
//  ENVITests
//
//  Phase 18 — Plan 02. Pins the contract that the CONNECT rows at
//  `ContentLibrarySettingsView.swift:247` (YouTube / X / LinkedIn)
//  no longer render `Button {} label: { Text("CONNECT") }` no-ops
//  — they now route through `SocialOAuthManager.connect(platform:)`,
//  the same entry point `ConnectedAccountsViewModel` uses.
//

import XCTest
@testable import ENVI

@MainActor
final class ContentLibrarySettingsConnectTests: XCTestCase {

    // MARK: - Test Doubles

    /// Spy subclass of `SocialOAuthManager` that records every
    /// `connect(platform:)` call. `SocialOAuthManager` is intentionally
    /// not `final` (see class header comment) so Phase 08/09 connectors
    /// and tests can subclass it — we reuse that seam here.
    final class SpyOAuthManager: SocialOAuthManager, @unchecked Sendable {
        struct Call: Equatable {
            let platform: SocialPlatform
        }

        var calls: [Call] = []
        var shouldThrow: Bool = false
        var returnConnected: Bool = true

        struct BoomError: Error, LocalizedError {
            var errorDescription: String? { "OAuth failed." }
        }

        override func connect(platform: SocialPlatform) async throws -> PlatformConnection {
            calls.append(Call(platform: platform))
            if shouldThrow { throw BoomError() }
            return PlatformConnection(
                platform: platform,
                isConnected: returnConnected,
                handle: "@spy",
                followerCount: 0,
                tokenExpiresAt: Date().addingTimeInterval(3600),
                lastRefreshedAt: Date(),
                scopes: []
            )
        }
    }

    // MARK: - Tests

    /// The audit finding: ContentLibrarySettingsView:247 shipped
    /// `Button {} label: { Text("CONNECT") }`. After 18-02 the tap
    /// reaches `SocialOAuthManager.connect(platform:)` with the correct
    /// `SocialPlatform` derived from the row.
    func testConnectButtonInvokesSocialOAuthManagerForX() async {
        let spy = SpyOAuthManager()
        var view = ContentLibrarySettingsView()
        view.oauth = spy

        view.connect(.x)

        // connect kicks off a Task — give it a hop to run.
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(spy.calls, [SpyOAuthManager.Call(platform: .x)],
            "Tapping CONNECT on the X row must invoke SocialOAuthManager.connect(platform: .x) once.")
    }

    /// LinkedIn row must route through the same code path.
    func testConnectButtonInvokesSocialOAuthManagerForLinkedIn() async {
        let spy = SpyOAuthManager()
        var view = ContentLibrarySettingsView()
        view.oauth = spy

        view.connect(.linkedin)
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(spy.calls, [SpyOAuthManager.Call(platform: .linkedin)],
            "LinkedIn CONNECT must route through SocialOAuthManager.connect(platform: .linkedin).")
    }

    /// YouTube is a valid `SocialPlatform` case (verified during plan
    /// implementation — `case youtube = "YouTube"` in Platform.swift).
    /// The plan documented a skip-if-absent fallback, but we can wire it.
    func testConnectButtonInvokesSocialOAuthManagerForYouTube() async {
        let spy = SpyOAuthManager()
        var view = ContentLibrarySettingsView()
        view.oauth = spy

        view.connect(.youtube)
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(spy.calls, [SpyOAuthManager.Call(platform: .youtube)],
            "YouTube CONNECT must route through SocialOAuthManager.connect(platform: .youtube).")
    }

    /// A failed OAuth connect must propagate to the spy but not crash.
    /// The view owns the error-surfacing @State; we cover the failure
    /// path here by confirming the call was still dispatched.
    func testFailedConnectStillCallsOAuthManager() async {
        let spy = SpyOAuthManager()
        spy.shouldThrow = true
        var view = ContentLibrarySettingsView()
        view.oauth = spy

        view.connect(.x)
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(spy.calls.count, 1,
            "Even when OAuth throws, the manager must see the call so the view can surface an error.")
    }
}
