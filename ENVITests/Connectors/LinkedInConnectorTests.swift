//
//  LinkedInConnectorTests.swift
//  ENVITests
//
//  Phase 11 — LinkedIn Connector (v1.1 Real Social Connectors).
//
//  Scope
//  -----
//  Exercise the mock path of `LinkedInConnector` and the shape-level
//  contracts the connector promises its callers (scope constants,
//  `LinkedInAuthorOption` stability, media-type validation in
//  `publishPost`). The real network path is covered end-to-end by the
//  Cloud Function tests in `functions/src/providers/linkedin*.test.ts`;
//  here we stay entirely on-device so CI doesn't need a live Firebase
//  emulator to run.
//
//  Strategy
//  --------
//  - `connectorsUseMockOAuth = true` for every test that touches
//    `connect()` / `fetchAdminOrganizations()` so we don't round-trip
//    the broker.
//  - `publishPost` tests pass local file URLs with synthetic extensions
//    to assert the iOS-side media-type router throws for unsupported
//    containers BEFORE we spend a Cloud Function invocation on them.
//

import XCTest
@testable import ENVI

final class LinkedInConnectorTests: XCTestCase {

    // MARK: - Setup

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        FeatureFlags.shared.connectorsUseMockOAuth = true
    }

    @MainActor
    override func tearDown() async throws {
        FeatureFlags.shared.connectorsUseMockOAuth = true
        try await super.tearDown()
    }

    // MARK: - Scope constants

    /// The split between member-tier and org-tier scopes is load-bearing —
    /// the author picker reads them to decide whether to show the locked
    /// upgrade row. Lock the shape in.
    func testScopeConstantsMatchSpec() {
        XCTAssertEqual(
            LinkedInConnector.memberScopes,
            ["r_liteprofile", "w_member_social"]
        )
        XCTAssertEqual(
            LinkedInConnector.orgScopes,
            ["r_organization_social", "w_organization_social"]
        )
        // Union should never contain duplicates — guards against the classic
        // cut-and-paste hazard when someone adds a new scope to one list
        // and forgets to remove the duplicate in the other.
        let union = Set(LinkedInConnector.memberScopes + LinkedInConnector.orgScopes)
        XCTAssertEqual(
            union.count,
            LinkedInConnector.memberScopes.count + LinkedInConnector.orgScopes.count
        )
    }

    // MARK: - Mock connect

    func testConnectMockReturnsMemberConnection() async throws {
        let connector = LinkedInConnector(
            featureFlagGate: { true }
        )
        let connection = try await connector.connect()
        XCTAssertTrue(connection.isConnected)
        XCTAssertEqual(connection.platform, .linkedin)
        XCTAssertFalse(connection.scopes.isEmpty)
    }

    func testConnectMockWithOrgScopesSurfacedInTelemetryPath() async throws {
        // The tier-gated overload just forwards to the base `connect()` in
        // the mock path but we still want it to compile + exercise the
        // branch on every run.
        let connector = LinkedInConnector(
            featureFlagGate: { true }
        )
        let connection = try await connector.connect(includeOrganizationScopes: true)
        XCTAssertTrue(connection.isConnected)
    }

    // MARK: - Mock fetchAdminOrganizations

    func testFetchAdminOrganizationsMockReturnsSample() async throws {
        let connector = LinkedInConnector(
            featureFlagGate: { true }
        )
        let orgs = try await connector.fetchAdminOrganizations()
        XCTAssertFalse(orgs.isEmpty)
        let first = try XCTUnwrap(orgs.first)
        XCTAssertTrue(first.urn.hasPrefix("urn:li:organization:"))
    }

    // MARK: - Publish media-type validation

    /// Text-only posts must not throw at the validation stage — they hit
    /// the network-stub path and (because we're offline) should surface a
    /// transport error rather than `.mediaInvalid`.
    func testPublishTextPostDoesNotThrowMediaInvalid() async {
        let connector = LinkedInConnector(
            featureFlagGate: { true }
        )
        do {
            _ = try await connector.publishPost(
                content: "hello world",
                mediaPath: nil,
                asOrganization: nil
            )
            // Network stub path MAY succeed — no assertion needed either way.
        } catch LinkedInConnectorError.mediaInvalid {
            XCTFail("text-only post should not surface .mediaInvalid")
        } catch {
            // Any other error (transport, decoding) is expected in unit scope.
        }
    }

    func testPublishUnsupportedExtensionThrowsMediaInvalid() async {
        let connector = LinkedInConnector(
            featureFlagGate: { true }
        )
        let bogus = URL(fileURLWithPath: "/tmp/example.webm")
        do {
            _ = try await connector.publishPost(
                content: "hi",
                mediaPath: bogus,
                asOrganization: nil
            )
            XCTFail("expected .mediaInvalid for .webm")
        } catch LinkedInConnectorError.mediaInvalid(let reason) {
            XCTAssertTrue(reason.contains("webm"))
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    func testPublishJPEGExtensionReachesDispatchPath() async {
        let connector = LinkedInConnector(
            featureFlagGate: { true }
        )
        let jpeg = URL(fileURLWithPath: "/tmp/example.jpg")
        do {
            _ = try await connector.publishPost(
                content: "hi",
                mediaPath: jpeg,
                asOrganization: nil
            )
        } catch LinkedInConnectorError.mediaInvalid {
            XCTFail(".jpg should pass media-type validation")
        } catch {
            // Transport/decoding errors are fine in unit scope.
        }
    }

    func testPublishMP4ExtensionReachesDispatchPath() async {
        let connector = LinkedInConnector(
            featureFlagGate: { true }
        )
        let mp4 = URL(fileURLWithPath: "/tmp/example.mp4")
        do {
            _ = try await connector.publishPost(
                content: "hi",
                mediaPath: mp4,
                asOrganization: nil
            )
        } catch LinkedInConnectorError.mediaInvalid {
            XCTFail(".mp4 should pass media-type validation")
        } catch {
            // Transport/decoding errors are fine in unit scope.
        }
    }

    // MARK: - Organization model

    func testLinkedInOrganizationCodableRoundTrip() throws {
        let original = LinkedInOrganization(
            id: "12345",
            urn: "urn:li:organization:12345",
            localizedName: "ENVI Studio",
            logoImageUrn: "urn:li:digitalmediaAsset:abc"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LinkedInOrganization.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Author option display

    func testAuthorOptionDisplayFields() {
        let member = LinkedInAuthorOption.member(handle: "Jane Doe")
        XCTAssertEqual(member.displayName, "Jane Doe")
        XCTAssertEqual(member.subtitle, "Personal profile")
        XCTAssertEqual(member.id, "member:Jane Doe")

        let org = LinkedInAuthorOption.organization(
            LinkedInOrganization(
                id: "99",
                urn: "urn:li:organization:99",
                localizedName: "ENVI Studio",
                logoImageUrn: nil
            )
        )
        XCTAssertEqual(org.displayName, "ENVI Studio")
        XCTAssertEqual(org.subtitle, "Company page")
        XCTAssertEqual(org.id, "org:urn:li:organization:99")
    }
}
