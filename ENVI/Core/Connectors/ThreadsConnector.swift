//
//  ThreadsConnector.swift
//  ENVI
//
//  Phase 10 — Meta Family Connector, Threads subclass.
//
//  Subclasses `MetaGraphConnector` with the Threads OAuth identity AND
//  overrides the critical `baseGraphURL` hook to point at the dedicated
//  `graph.threads.net/v1.0` host. If this override is ever dropped, every
//  Threads API call will 404 against `graph.facebook.com` — treat the
//  override as a non-negotiable compile-checked contract.
//
//  App ID discriminators
//  ---------------------
//  Threads standalone OAuth uses `1604969460421980` as `client_id`.
//  The parent app group (`1649869446444171`) is a Secret Manager
//  discriminator used by `MetaProvider` to pick `staging-threads-app-secret`
//  — it is NOT the OAuth `client_id`.
//
//  Publishing flow
//  ---------------
//  1. Broker `/publish/jobs` with `platform: "threads"` + payload.
//  2. Broker POSTs `/{threads-user-id}/threads` (media_type = TEXT / IMAGE
//     / VIDEO / CAROUSEL) against `graph.threads.net`.
//  3. Broker waits ~30s for media processing (text can skip the wait).
//  4. Broker POSTs `/{threads-user-id}/threads_publish`.
//
//  Text limits
//  -----------
//  Threads enforces 500 characters per post. We validate client-side and
//  throw `ThreadsConnectorError.textTooLong` BEFORE spending broker round
//  trips — cheaper for the user and keeps Graph quota clean.
//

import Foundation

/// Media kinds accepted by Threads container creation.
enum ThreadsMediaType: String, Codable {
    case image
    case video
}

/// One slide of a Threads carousel.
struct ThreadsCarouselItem: Encodable {
    let mediaURL: URL
    let mediaType: ThreadsMediaType

    enum CodingKeys: String, CodingKey {
        case mediaURL = "media_url"
        case mediaType = "media_type"
    }
}

/// Errors specific to the Threads connector.
enum ThreadsConnectorError: Error, LocalizedError {
    /// Text exceeded Threads' 500-character limit.
    case textTooLong(Int)
    /// Carousel must have at least 2 items.
    case carouselTooFewItems(count: Int)
    /// Carousel capped at 20 items per the Threads API.
    case carouselTooManyItems(count: Int)

    var errorDescription: String? {
        switch self {
        case .textTooLong(let count):
            return "Threads posts are limited to 500 characters — you wrote \(count)."
        case .carouselTooFewItems(let count):
            return "Threads carousels need at least 2 items — you sent \(count)."
        case .carouselTooManyItems(let count):
            return "Threads carousels can hold at most 20 items — you sent \(count)."
        }
    }
}

/// Threads connector. Re-hosts every Graph call at `graph.threads.net`.
final class ThreadsConnector: MetaGraphConnector {

    // MARK: - Constants

    /// OAuth `client_id` for Threads. Public. Secret:
    /// `staging-threads-app-secret`.
    static let threadsAppID = "1604969460421980"

    /// 500-char post ceiling enforced by Threads server-side. We mirror it
    /// client-side to short-circuit expensive publish round trips.
    static let maxTextLength = 500

    /// Carousel bounds per Threads API.
    static let minCarouselItems = 2
    static let maxCarouselItems = 20

    /// CRITICAL: Threads uses a distinct Graph host from FB/IG. If this
    /// override is ever removed the connector silently talks to
    /// `graph.facebook.com` and every publish fails at runtime. The
    /// override is the main reason `MetaGraphConnector.baseGraphURL` is
    /// declared `open var`.
    override var baseGraphURL: URL {
        URL(string: "https://graph.threads.net/v1.0")!
    }

    // MARK: - Singleton

    nonisolated(unsafe) static let shared = ThreadsConnector()

    // MARK: - Init

    convenience init() {
        self.init(
            oauthManager: .shared,
            apiClient: SocialOAuthManager.sharedBrokerAPIClient
        )
    }

    init(
        oauthManager: SocialOAuthManager,
        apiClient: APIClient
    ) {
        super.init(
            metaPlatform: .threads(appID: Self.threadsAppID),
            oauthManager: oauthManager,
            apiClient: apiClient
        )
    }

    // MARK: - Publish

    /// Publish a text-only post. Validates 500-char cap client-side.
    func publishText(text: String) async throws -> PublishTicket {
        try Self.validate(textLength: text.count)

        let body = ThreadsTextPublishRequest(
            platform: "threads",
            kind: "text",
            text: text
        )
        return try await submitPublishJob(endpoint: "publish/jobs", body: body)
    }

    /// Publish a single-media post. Optional text accompaniment, also
    /// capped at 500 characters.
    func publishMedia(
        text: String?,
        mediaURL: URL,
        mediaType: ThreadsMediaType
    ) async throws -> PublishTicket {
        if let text {
            try Self.validate(textLength: text.count)
        }

        let body = ThreadsMediaPublishRequest(
            platform: "threads",
            kind: "media",
            text: text,
            mediaURL: mediaURL.absoluteString,
            mediaType: mediaType
        )
        return try await submitPublishJob(endpoint: "publish/jobs", body: body)
    }

    /// Publish a 2-20 item carousel. Optional top-level text caption,
    /// capped at 500 characters.
    func publishCarousel(
        text: String?,
        items: [ThreadsCarouselItem]
    ) async throws -> PublishTicket {
        let count = items.count
        if count < Self.minCarouselItems {
            throw ThreadsConnectorError.carouselTooFewItems(count: count)
        }
        if count > Self.maxCarouselItems {
            throw ThreadsConnectorError.carouselTooManyItems(count: count)
        }
        if let text {
            try Self.validate(textLength: text.count)
        }

        let body = ThreadsCarouselPublishRequest(
            platform: "threads",
            kind: "carousel",
            text: text,
            items: items
        )
        return try await submitPublishJob(endpoint: "publish/jobs", body: body)
    }

    // MARK: - Validation

    private static func validate(textLength: Int) throws {
        if textLength > maxTextLength {
            throw ThreadsConnectorError.textTooLong(textLength)
        }
    }
}

// MARK: - Publish Request Shapes

private struct ThreadsTextPublishRequest: Encodable {
    let platform: String
    let kind: String
    let text: String
}

private struct ThreadsMediaPublishRequest: Encodable {
    let platform: String
    let kind: String
    let text: String?
    let mediaURL: String
    let mediaType: ThreadsMediaType

    enum CodingKeys: String, CodingKey {
        case platform
        case kind
        case text
        case mediaURL = "media_url"
        case mediaType = "media_type"
    }
}

private struct ThreadsCarouselPublishRequest: Encodable {
    let platform: String
    let kind: String
    let text: String?
    let items: [ThreadsCarouselItem]
}
