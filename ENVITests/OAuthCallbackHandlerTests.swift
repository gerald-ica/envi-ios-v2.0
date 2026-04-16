import XCTest
@testable import ENVI

/// Phase 06-04 — OAuthCallbackHandler URL parsing.
///
/// Six canonical URL cases covered:
///   1. Happy-path: scheme+host+provider+code+state
///   2. Provider-level error (access_denied)
///   3. Unknown provider slug → rejected
///   4. Missing provider segment → rejected
///   5. Wrong scheme → passes through untouched (`.unrelated`)
///   6. Uppercase scheme + host + provider slug → still handled
final class OAuthCallbackHandlerTests: XCTestCase {

    func testParsesHappyPathCallback() {
        let url = URL(string: "enviapp://oauth-callback/tiktok?code=ABC123&state=xyz")!
        guard let parsed = OAuthCallbackHandler.parse(url) else {
            XCTFail("Expected parse to succeed"); return
        }
        XCTAssertEqual(parsed.provider, .tiktok)
        XCTAssertEqual(parsed.code, "ABC123")
        XCTAssertEqual(parsed.state, "xyz")
        XCTAssertNil(parsed.error)
        XCTAssertEqual(parsed.rawURL, url)
    }

    func testSurfacesProviderErrorParameter() {
        let url = URL(string: "enviapp://oauth-callback/x?error=access_denied&state=abc")!
        guard let parsed = OAuthCallbackHandler.parse(url) else {
            XCTFail("Expected parse to succeed on error responses"); return
        }
        XCTAssertEqual(parsed.provider, .x)
        XCTAssertNil(parsed.code)
        XCTAssertEqual(parsed.error, "access_denied")
    }

    func testRejectsUnknownProviderSlug() {
        let url = URL(string: "enviapp://oauth-callback/snapchat?code=nope")!
        XCTAssertNil(OAuthCallbackHandler.parse(url))
    }

    func testRejectsMissingProviderPath() {
        let url = URL(string: "enviapp://oauth-callback/?code=nope")!
        XCTAssertNil(OAuthCallbackHandler.parse(url))
    }

    func testWrongSchemePassesThroughAsUnrelated() {
        let url = URL(string: "https://envi.app/oauth-callback/tiktok?code=ABC")!
        XCTAssertEqual(OAuthCallbackHandler.handle(url), .unrelated)
    }

    func testSchemeAndProviderSlugAreCaseInsensitive() {
        let url = URL(string: "ENVIAPP://OAUTH-CALLBACK/TikTok?code=ABC&state=xyz")!
        guard let parsed = OAuthCallbackHandler.parse(url) else {
            XCTFail("Expected case-insensitive parse to succeed"); return
        }
        XCTAssertEqual(parsed.provider, .tiktok)
        XCTAssertEqual(parsed.code, "ABC")
    }

    // MARK: - Notification dispatch

    func testHandlePostsNotificationWithParsedPayload() {
        let center = NotificationCenter()
        let url = URL(string: "enviapp://oauth-callback/instagram?code=IG123&state=s1")!

        let expectation = expectation(description: "notification posted")
        var received: OAuthCallbackHandler.Parsed?
        let observer = center.addObserver(
            forName: OAuthCallbackHandler.notificationName,
            object: nil,
            queue: .main
        ) { note in
            received = note.userInfo?["parsed"] as? OAuthCallbackHandler.Parsed
            expectation.fulfill()
        }
        defer { center.removeObserver(observer) }

        let outcome = OAuthCallbackHandler.handle(url, notificationCenter: center)
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(outcome, .handled)
        XCTAssertEqual(received?.provider, .instagram)
        XCTAssertEqual(received?.code, "IG123")
    }
}
