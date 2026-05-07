//
//  InstagramConnector.swift
//  ENVI
//
//  Phase 10 — Meta Family Connector, Instagram Business/Creator subclass.
//
//  Subclasses `MetaGraphConnector` with the Instagram Graph API identity.
//  Shares the Graph host (`graph.facebook.com/v21.0`) with Facebook — IG
//  Content Publishing lives under the FB Graph, not a separate host. Only
//  Threads has its own host.
//
//  Account-type gating
//  -------------------
//  IG Content Publishing requires a Business or Creator account linked to a
//  Facebook Page. The broker's `detectIGAccountType(uid)` surfaces one of
//  `BUSINESS` / `MEDIA_CREATOR` / `PERSONAL`. iOS reads that and:
//    - `BUSINESS` / `MEDIA_CREATOR`: proceed.
//    - `PERSONAL`: throw `.personalAccount` → show
//      `InstagramAccountTypeErrorView` with the Switch-to-Pro help link.
//    - No linked Page: throw `.noLinkedPage` → show the Link-Page help link.
//
//  Publishing flow (all server-side via broker)
//  --------------------------------------------
//  1. iOS hits broker `/publish/jobs` with `platform: "instagram"` + payload.
//  2. Broker calls `POST /{ig-user-id}/media` (container creation).
//  3. Broker polls `status_code` (1/min, max 5 attempts).
//  4. Broker calls `POST /{ig-user-id}/media_publish`.
//
//  Carousels are capped at 10 items by the Graph API. Reels use `REELS`
//  media type per the Oct 2023 IG API update.
//
//  Client token
//  ------------
//  `3bb10460a0360e4adcdfc98609ae0cb0` is an IG app-level public token,
//  documented as safe to ship in client binaries. NOT a user access token
//  and NOT a client secret. Kept in Swift because SDKs may request it when
//  Meta adds client-side enrichment (timeline: 2026+).
//

import Foundation

/// IG media kinds the Graph API accepts via `/media` container creation.
enum IGMediaType: String, Codable {
    case image
    case video
    case reel
}

/// One slide of a carousel. Each item gets its own child container before
/// the parent carousel container is created.
struct IGCarouselItem: Encodable {
    let mediaURL: URL
    let mediaType: IGMediaType

    enum CodingKeys: String, CodingKey {
        case mediaURL = "media_url"
        case mediaType = "media_type"
    }
}

/// Instagram-specific error surface. Kept distinct from
/// `MetaConnectorError` because the UI branches off these cases.
enum InstagramConnectorError: Error, LocalizedError {
    /// User connected a personal IG account. Must be Business or Creator.
    case personalAccount
    /// No Facebook Page is linked to this IG account.
    case noLinkedPage
    /// Broker failed to create the `/media` container.
    case containerCreationFailed
    /// Container never reached `FINISHED` within the broker's poll budget.
    case publishTimeout
    /// Carousel violated the 10-item cap.
    case carouselTooManyItems(count: Int)
    /// Carousel needs at least 2 items.
    case carouselTooFewItems(count: Int)

    var errorDescription: String? {
        switch self {
        case .personalAccount:
            return "Instagram Content Publishing requires a Business or Creator account."
        case .noLinkedPage:
            return "Your Instagram account must be linked to a Facebook Page."
        case .containerCreationFailed:
            return "Couldn't create the Instagram media container."
        case .publishTimeout:
            return "Instagram took too long to process this post. Try again in a few minutes."
        case .carouselTooManyItems(let count):
            return "Carousels can have at most 10 items — you sent \(count)."
        case .carouselTooFewItems(let count):
            return "Carousels need at least 2 items — you sent \(count)."
        }
    }
}

/// Instagram Business/Creator connector.
final class InstagramConnector: MetaGraphConnector {

    // MARK: - App IDs

    /// Meta dev-app id for ENVI's Instagram Graph integration. Public.
    /// Server-side secret: `staging-instagram-app-secret`.
    static let instagramAppID = "1811522229543951"

    /// Instagram app-level client token. Safe to ship in iOS binary —
    /// Meta documents this as a public app identifier. Kept explicit
    /// because future IG SDK integrations may read it at runtime.
    static let instagramClientToken = "3bb10460a0360e4adcdfc98609ae0cb0"

    // MARK: - Config

    /// Max carousel items per the Graph API (Oct 2024 docs).
    static let maxCarouselItems = 10

    /// Min carousel items — a "carousel" of 1 is just a single-media post.
    static let minCarouselItems = 2

    // MARK: - Singleton

    static let shared = InstagramConnector()

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
            metaPlatform: .instagram(
                appID: Self.instagramAppID,
                clientToken: Self.instagramClientToken
            ),
            oauthManager: oauthManager,
            apiClient: apiClient
        )
    }

    // MARK: - Account Type Detection

    /// Ask the broker to detect the connected IG account's type. Called
    /// right after `connect()` resolves, before surfacing any publish UI.
    /// Throws `.personalAccount` or `.noLinkedPage` when the account is
    /// ineligible for Content Publishing.
    func detectAccountType() async throws -> IGAccountType {
        let response: IGAccountTypeResponse = try await apiClient.request(
            endpoint: "meta/ig-account-type",
            method: .post,
            body: Optional<String>.none,
            requiresAuth: true
        )

        switch response.accountType {
        case .business, .mediaCreator:
            return response.accountType
        case .personal:
            throw InstagramConnectorError.personalAccount
        case .unknown:
            throw InstagramConnectorError.noLinkedPage
        }
    }

    // MARK: - Publish

    /// Publish a single photo or video. Delegates to the broker which owns
    /// container creation + status polling + `media_publish`.
    func publishSingleMedia(
        caption: String,
        mediaURL: URL,
        mediaType: IGMediaType
    ) async throws -> PublishTicket {
        guard mediaType != .reel else {
            // Reels go through the dedicated `publishReel` path — they
            // require a specific `REELS` media type on the container.
            return try await publishReel(caption: caption, videoURL: mediaURL)
        }

        let body = IGSinglePublishRequest(
            platform: "instagram",
            kind: "single",
            caption: caption,
            mediaURL: mediaURL.absoluteString,
            mediaType: mediaType
        )
        return try await submitPublishJob(endpoint: "publish/jobs", body: body)
    }

    /// Publish a carousel (2-10 items). Each item becomes a child container
    /// server-side; the broker composes them under a parent carousel
    /// container before `media_publish`.
    func publishCarousel(
        caption: String,
        mediaItems: [IGCarouselItem]
    ) async throws -> PublishTicket {
        let count = mediaItems.count
        if count < Self.minCarouselItems {
            throw InstagramConnectorError.carouselTooFewItems(count: count)
        }
        if count > Self.maxCarouselItems {
            throw InstagramConnectorError.carouselTooManyItems(count: count)
        }

        let body = IGCarouselPublishRequest(
            platform: "instagram",
            kind: "carousel",
            caption: caption,
            items: mediaItems
        )
        return try await submitPublishJob(endpoint: "publish/jobs", body: body)
    }

    /// Publish a Reel. Requires `REELS` media type on the container, which
    /// the broker sets when `kind == "reel"`.
    func publishReel(
        caption: String,
        videoURL: URL
    ) async throws -> PublishTicket {
        let body = IGSinglePublishRequest(
            platform: "instagram",
            kind: "reel",
            caption: caption,
            mediaURL: videoURL.absoluteString,
            mediaType: .reel
        )
        return try await submitPublishJob(endpoint: "publish/jobs", body: body)
    }
}

// MARK: - Account Type Wire Types

/// Account types returned by the Graph `account_type` field. The broker
/// normalizes any unknown value to `.unknown` so the iOS branch is
/// exhaustive without a catch-all.
enum IGAccountType: String, Codable {
    case business = "BUSINESS"
    case mediaCreator = "MEDIA_CREATOR"
    case personal = "PERSONAL"
    case unknown = "UNKNOWN"
}

private struct IGAccountTypeResponse: Decodable {
    let accountType: IGAccountType
    let username: String?
    let mediaCount: Int?

    enum CodingKeys: String, CodingKey {
        case accountType = "account_type"
        case username
        case mediaCount = "media_count"
    }
}

// MARK: - Publish Request Shapes

private struct IGSinglePublishRequest: Encodable {
    let platform: String
    let kind: String
    let caption: String
    let mediaURL: String
    let mediaType: IGMediaType

    enum CodingKeys: String, CodingKey {
        case platform
        case kind
        case caption
        case mediaURL = "media_url"
        case mediaType = "media_type"
    }
}

private struct IGCarouselPublishRequest: Encodable {
    let platform: String
    let kind: String
    let caption: String
    let items: [IGCarouselItem]
}
