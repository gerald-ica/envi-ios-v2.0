//
//  TikTokIntegrationTests.swift
//  ENVITests
//
//  Phase 08 — End-to-end integration test against TikTok sandbox.
//
//  SKIPPED by default. Gate:
//    Set `ENVI_RUN_TIKTOK_INTEGRATION=1` in the scheme's environment AND
//    place a 15s 720p H.264 MP4 (≤5MB) at `ENVITests/Fixtures/test-video.mp4`.
//
//  Prerequisites
//  -------------
//  1. Firebase is configured in the test harness (`FirebaseApp.configure()`
//     in test setUp — wired up by the Phase 7 emulator job).
//  2. The signed-in user is on the TikTok sandbox allowlist.
//  3. `FeatureFlags.shared.useTikTokConnector = true` and
//     `connectorsUseMockOAuth = false`.
//  4. The sandbox TikTok app is configured with redirect URI
//     `enviapp://oauth-callback/tiktok`.
//
//  Expected outcome (sandbox)
//  --------------------------
//  TikTok's sandbox pipeline stops at `SEND_TO_USER_INBOX` — the tester
//  still needs to manually tap "Post" in their TikTok app to graduate the
//  video to `PUBLISH_COMPLETE`. The assertion therefore accepts EITHER
//  terminal state as "success" for the purposes of the publish half of
//  the test.
//

import XCTest
@testable import ENVI

final class TikTokIntegrationTests: XCTestCase {

    private static let integrationEnvKey = "ENVI_RUN_TIKTOK_INTEGRATION"
    private static let fixtureName = "test-video"
    private static let fixtureExt = "mp4"

    override func setUp() async throws {
        try await super.setUp()
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment[Self.integrationEnvKey] == "1",
            "Set \(Self.integrationEnvKey)=1 to run TikTok integration tests"
        )
    }

    // MARK: - Connect / Refresh

    func testRefreshReturnsConnectedSnapshot() async throws {
        // Pre-condition: a Phase 7 OAuth round-trip has already run at
        // least once so Firestore holds a valid token set.
        let connection = try await TikTokConnector.shared.refreshConnection()
        XCTAssertEqual(connection.platform, .tiktok)
        XCTAssertTrue(connection.isConnected)
        XCTAssertFalse((connection.handle ?? "").isEmpty)
    }

    // MARK: - End-to-end publish

    /// Full publish pipeline against the sandbox. Runs long (5-10 minutes)
    /// because TikTok's status poll can take time to settle.
    func testEndToEndSandboxPublish() async throws {
        let bundle = Bundle(for: type(of: self))
        guard let fixtureURL = bundle.url(
            forResource: Self.fixtureName,
            withExtension: Self.fixtureExt
        ) else {
            XCTFail(
                "Missing test fixture \(Self.fixtureName).\(Self.fixtureExt) — "
                + "place a 15s 720p H.264 MP4 (≤5MB) at ENVITests/Fixtures/"
            )
            return
        }

        let caption = "[ENVI Test] \(Date().ISO8601Format())"
        let ticket = try await TikTokConnector.shared.publishVideo(
            at: fixtureURL,
            caption: caption,
            privacy: .onlyMe
        )
        XCTAssertFalse(ticket.jobID.isEmpty)
        XCTAssertEqual(ticket.status, .queued)

        // Poll via PublishingManager until terminal or timeout. The helper
        // retries every ~2s for up to maxAttempts tries — 60 attempts ≈ 2min
        // which is enough for the sandbox's first couple of stage transitions.
        // TikTok may continue polling on the broker side afterwards.
        let finalStatus = try await PublishingManager.shared.waitForFinalStatus(
            jobID: ticket.jobID,
            maxAttempts: 60
        )
        XCTAssertTrue(
            finalStatus == .posted || finalStatus == .processing,
            "Unexpected terminal status: \(finalStatus)"
        )
    }

    // MARK: - List

    func testListVideosAfterPublish() async throws {
        let (videos, _, _) = try await TikTokConnector.shared.listVideos(
            cursor: nil,
            maxCount: 5
        )
        // Sandbox `video.list` can take up to an hour to propagate — a
        // successful call with an empty array is still a pass. We only
        // assert that the endpoint round-trips cleanly.
        XCTAssertNotNil(videos)
    }
}
