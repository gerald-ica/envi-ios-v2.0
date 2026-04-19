import XCTest
@testable import ENVI

final class ForYouIdentityResolverTests: XCTestCase {

    func testResolveUsesConnectedPlatformHandle() {
        let user = User(
            id: UUID(),
            firstName: "Wendy",
            lastName: "Ly",
            email: "wendy@example.com",
            dateOfBirth: nil,
            location: nil,
            birthplace: nil,
            avatarURL: nil,
            handle: "@wendyly",
            bio: nil,
            connectedPlatforms: [
                PlatformConnection(platform: .instagram, isConnected: true, handle: "wendy.ig")
            ],
            publishedCount: 0,
            draftsCount: 0,
            templatesCount: 0
        )
        let resolver = ForYouIdentityResolver(
            currentUserProvider: { user },
            fallbackNameProvider: { nil }
        )

        let identity = resolver.resolve(preferredPlatform: .instagram)
        XCTAssertEqual(identity.displayName, "Wendy Ly")
        XCTAssertEqual(identity.handle, "@wendy.ig")
    }

    func testResolveFallsBackToOnboardingNameWhenNoUserSession() {
        let resolver = ForYouIdentityResolver(
            currentUserProvider: { nil },
            fallbackNameProvider: { "Creator Name" }
        )

        let identity = resolver.resolve(preferredPlatform: nil)
        XCTAssertEqual(identity.displayName, "Creator Name")
        XCTAssertEqual(identity.handle, "@you")
    }
}
