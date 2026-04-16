//
//  XTwitterConnectorTests.swift
//  ENVITests
//
//  Phase 09 — X Connector unit tests.
//
//  Coverage
//  --------
//  - Feature-flag-OFF mock paths return deterministic PublishTicket /
//    XAccount payloads (no network).
//  - XConnectorError envelope decoding: `rate_limited`, `media_*`,
//    `tweet_rejected`, unknown codes.
//  - `XMediaConstraints.videoCategory(for:)` picks `tweet_video` vs.
//    `amplify_video` correctly around the 140s boundary.
//  - Error translation maps `.unauthorized` → `.notConnected`.
//
//  Network-backed integration tests live behind the feature flag in
//  Phase 9's UAT script — not wired into CI because X provides no
//  sandbox environment.
//

import XCTest
@testable import ENVI

final class XTwitterConnectorTests: XCTestCase {

    // MARK: - Mock path

    func test_publishTweet_flagOff_returnsMockTicket() async throws {
        let connector = XTwitterConnector(
            apiClient: .shared,
            oauthManager: .shared,
            featureFlagGate: { false }
        )

        let ticket = try await connector.publishTweet(
            text: "Hello from Phase 9",
            mediaPath: nil,
            replyToID: nil
        )

        XCTAssertEqual(ticket.status, .posted)
        XCTAssertFalse(ticket.jobID.isEmpty)
        XCTAssertEqual(ticket.jobID, ticket.tweetID)
    }

    func test_fetchAccount_flagOff_returnsMockAccount() async throws {
        let connector = XTwitterConnector(
            apiClient: .shared,
            oauthManager: .shared,
            featureFlagGate: { false }
        )

        let account = try await connector.fetchAccount()
        XCTAssertEqual(account.username, "envi_user")
        XCTAssertGreaterThan(account.followerCount, 0)
    }

    // MARK: - Error envelope decoding

    func test_errorEnvelope_rateLimited_decodesRetryAfter() throws {
        let iso = "2026-04-16T12:34:56Z"
        let json = """
        {
          "error": "rate_limited",
          "retryAfter": "\(iso)"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(
            XConnectorErrorEnvelope.self, from: json
        )

        let xError = XConnectorError.from(envelope: envelope)
        guard case .rateLimited(let date) = xError else {
            return XCTFail("expected .rateLimited, got \(xError)")
        }
        XCTAssertEqual(
            Int(date.timeIntervalSince1970),
            Int(ISO8601DateFormatter().date(from: iso)!.timeIntervalSince1970)
        )
    }

    func test_errorEnvelope_mediaProcessing_carriesDetail() throws {
        let json = """
        {
          "error": "media_processing",
          "detail": "InvalidMediaType"
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(
            XConnectorErrorEnvelope.self, from: json
        )
        let xError = XConnectorError.from(envelope: envelope)

        XCTAssertEqual(
            xError,
            .mediaProcessingFailed(reason: "InvalidMediaType")
        )
    }

    func test_errorEnvelope_unknown_fallsBackToTransport() throws {
        let json = """
        { "error": "unknown_future_code" }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(
            XConnectorErrorEnvelope.self, from: json
        )
        let xError = XConnectorError.from(envelope: envelope)

        XCTAssertEqual(
            xError,
            .transport(underlying: "unknown_future_code")
        )
    }

    func test_errorEnvelope_rateLimited_withoutRetryAfter_degradesToTransport() throws {
        let json = """
        { "error": "rate_limited" }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(
            XConnectorErrorEnvelope.self, from: json
        )
        let xError = XConnectorError.from(envelope: envelope)

        XCTAssertEqual(
            xError,
            .transport(underlying: "rate_limited (no retryAfter)")
        )
    }

    // MARK: - Constraints

    func test_videoCategory_tweetVideoUnder140s() {
        XCTAssertEqual(
            XMediaConstraints.videoCategory(for: 30),
            "tweet_video"
        )
        XCTAssertEqual(
            XMediaConstraints.videoCategory(for: 140),
            "tweet_video"
        )
    }

    func test_videoCategory_amplifyVideoOver140s() {
        XCTAssertEqual(
            XMediaConstraints.videoCategory(for: 141),
            "amplify_video"
        )
        XCTAssertEqual(
            XMediaConstraints.videoCategory(for: 600),
            "amplify_video"
        )
    }

    func test_supportedExtensions_coverHappyPath() {
        XCTAssertTrue(XMediaConstraints.supportedVideoExtensions.contains("mp4"))
        XCTAssertTrue(XMediaConstraints.supportedVideoExtensions.contains("mov"))
        XCTAssertTrue(XMediaConstraints.supportedImageExtensions.contains("png"))
        XCTAssertTrue(XMediaConstraints.supportedImageExtensions.contains("jpg"))
        XCTAssertFalse(XMediaConstraints.supportedVideoExtensions.contains("avi"))
    }

    // MARK: - Translation

    func test_translate_unauthorized_mapsToNotConnected() {
        let translated = XTwitterConnector.translate(APIClient.APIError.unauthorized)
        XCTAssertEqual(translated, .notConnected)
    }

    func test_translate_httpError_mapsToTransport() {
        let translated = XTwitterConnector.translate(
            APIClient.APIError.httpError(statusCode: 502)
        )
        XCTAssertEqual(translated, .transport(underlying: "HTTP 502"))
    }

    func test_translate_passesThroughXConnectorError() {
        let original: XConnectorError = .mediaTooLarge
        let translated = XTwitterConnector.translate(original)
        XCTAssertEqual(translated, .mediaTooLarge)
    }
}
