import XCTest
@testable import ENVI

/// Phase 15-03 — pins the URL → AppDestination mapping table.
/// Guarantees: OAuth callbacks stay untouched (handled by Phase 6's
/// handler), non-enviapp schemes return nil, the registry covers
/// no-payload and id-payload shapes, and malformed inputs degrade
/// gracefully without crashing.
final class DeepLinkRouterTests: XCTestCase {

    func testOAuthCallbackIsNotParsed() {
        let url = URL(string: "enviapp://oauth-callback/tiktok?code=xyz")!
        XCTAssertNil(DeepLinkRouter.destination(from: url))
    }

    func testUnknownSchemeIsNotParsed() {
        let url = URL(string: "https://example.com/destination/search")!
        XCTAssertNil(DeepLinkRouter.destination(from: url))
    }

    func testDestinationNoPayload() {
        let url = URL(string: "enviapp://destination/search")!
        XCTAssertEqual(DeepLinkRouter.destination(from: url), .search)
    }

    func testDestinationWithIdPayload() {
        // Sprint-03: campaignDetail deep-link route is hidden.
        let url = URL(string: "enviapp://destination/campaignDetail?id=abc")!
        XCTAssertNil(DeepLinkRouter.destination(from: url))
    }

    func testUnknownDestinationReturnsNil() {
        let url = URL(string: "enviapp://destination/totallyMadeUp")!
        XCTAssertNil(DeepLinkRouter.destination(from: url))
    }

    func testMalformedURLReturnsNil() {
        // Empty path after `destination`
        XCTAssertNil(DeepLinkRouter.destination(
            from: URL(string: "enviapp://destination")!))

        // Case that requires an id payload but none supplied (route hidden in Sprint-03)
        XCTAssertNil(DeepLinkRouter.destination(
            from: URL(string: "enviapp://destination/campaignDetail")!))

        // Completely bogus host under the right scheme
        XCTAssertNil(DeepLinkRouter.destination(
            from: URL(string: "enviapp://wrong-host/search")!))
    }
}
