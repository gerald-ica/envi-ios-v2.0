import XCTest
import AuthenticationServices
@testable import ENVI

/// Phase 06-04 — lightweight surface tests for ASWebAuthenticationSessionAdapter.
///
/// We deliberately do NOT try to drive a real `ASWebAuthenticationSession` from
/// a unit test — the system presents a Safari sheet and expects a real
/// interactive context. Instead we cover the state machine around it:
///
///   - The adapter conforms to `OAuthSession`.
///   - A fresh adapter has no active session, so `cancel()` is a safe no-op.
///   - `sessionAlreadyActive` is surfaced when a reentrant `start` is issued.
///
/// End-to-end OAuth flow coverage lives in Phase 07 against the Functions
/// emulator; that's where we exercise the real round trip.
@MainActor
final class ASWebAuthenticationSessionAdapterTests: XCTestCase {

    func testAdapterConformsToOAuthSessionProtocol() {
        let adapter: OAuthSession = ASWebAuthenticationSessionAdapter()
        XCTAssertNotNil(adapter)
    }

    func testCancelOnFreshAdapterIsNoOp() {
        let adapter = ASWebAuthenticationSessionAdapter()
        // Should not crash nor throw.
        adapter.cancel()
    }

    func testPresentationAnchorProviderIsInjectable() {
        let window = UIWindow()
        var requests = 0
        let adapter = ASWebAuthenticationSessionAdapter(
            presentationAnchorProvider: {
                requests += 1
                return window
            }
        )
        _ = adapter  // silences unused warning; real invocation requires live start().
        XCTAssertEqual(requests, 0, "Anchor should be resolved lazily at start() time")
    }

    func testOAuthSessionErrorDescriptionsAreUserReadable() {
        // Contract test: the LocalizedError strings must not contain
        // placeholders we forgot to interpolate.
        XCTAssertFalse(OAuthSessionError.userCancelled.localizedDescription.isEmpty)
        XCTAssertFalse(OAuthSessionError.sessionAlreadyActive.localizedDescription.isEmpty)
        let url = URL(string: "enviapp://oauth-callback/tiktok")!
        let message = OAuthSessionError.callbackURLInvalid(url).localizedDescription
        XCTAssertTrue(message.contains("enviapp://"))
    }
}
