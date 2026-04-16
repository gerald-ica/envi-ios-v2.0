//
//  FacebookConnector.swift
//  ENVI
//
//  Phase 10 — Meta Family Connector, Facebook Pages subclass.
//
//  Subclasses `MetaGraphConnector` with the Facebook OAuth identity +
//  Page-centric publish surface. Uses Meta's Graph v21.0 at
//  `graph.facebook.com` (inherited default).
//
//  Post-OAuth flow
//  ---------------
//  FB Pages OAuth returns a user access token. The broker immediately calls
//  `GET /me/accounts` to list Pages the user administers, encrypts each
//  Page access token, and stores them per-Page. The iOS side presents
//  `PageSelectorView` so the user picks which Page to publish as.
//
//  Publishing
//  ----------
//  All publish paths delegate to the broker's `/publish/jobs` endpoint with
//  a `platform: "facebook"` payload. The broker resolves the Page access
//  token by `selectedPageId` + calls `POST /{pageId}/feed` (text/image) or
//  `POST /{pageId}/videos` (video) against the Graph.
//
//  Feature flag gate
//  -----------------
//  `FeatureFlags.shared.canConnectFacebook` MUST be `true` for the UI to
//  expose this connector. `pages_manage_posts` requires Meta App Review —
//  until approval lands, `.facebook` stays hidden in the Connect sheet.
//

import Foundation

/// Publish kinds supported by the Facebook Pages Graph surface. Each maps
/// to a different broker path (`/feed` vs. `/videos`).
enum FacebookMediaType: String, Codable {
    case text
    case photo
    case video
}

/// Errors specific to the Facebook Pages connector.
enum FacebookConnectorError: Error, LocalizedError {
    /// User has no Facebook Pages under their account. Show the "Create a
    /// Page" help URL in `PageSelectorView`.
    case noPagesAvailable
    /// Broker rejected the publish payload.
    case publishRejected(String)

    var errorDescription: String? {
        switch self {
        case .noPagesAvailable:
            return "You don't have any Facebook Pages to publish to."
        case .publishRejected(let reason):
            return "Facebook rejected this post: \(reason)"
        }
    }
}

/// Facebook Pages connector. Inherits the shared Meta OAuth + refresh
/// machinery and adds the Page-centric publish surface.
final class FacebookConnector: MetaGraphConnector {

    // MARK: - App ID

    /// Meta dev-app id for ENVI's Facebook Pages integration. Public
    /// identifier — safe to ship in binary. Secret lives server-side in
    /// Secret Manager as `staging-meta-app-secret`.
    static let facebookAppID = "1233228574968466"

    // MARK: - Singleton

    /// Shared instance wired to the default OAuth manager + API client.
    /// Tests instantiate directly with mock collaborators.
    static let shared = FacebookConnector()

    // MARK: - Init

    convenience init() {
        self.init(oauthManager: .shared, apiClient: .shared)
    }

    init(
        oauthManager: SocialOAuthManager,
        apiClient: APIClient
    ) {
        super.init(
            metaPlatform: .facebook(appID: Self.facebookAppID),
            oauthManager: oauthManager,
            apiClient: apiClient
        )
    }

    // MARK: - Publish

    /// Publish a post to a selected Facebook Page.
    ///
    /// The Page id is resolved server-side from the authenticated user's
    /// `selectedPageId` — this call doesn't need the Page id because the
    /// broker looks it up + fetches the Page access token from encrypted
    /// storage. If the user hasn't run through `PageSelectorView` yet, the
    /// broker returns `no_selected_page` and this throws
    /// `FacebookConnectorError.noPagesAvailable`.
    ///
    /// - Parameters:
    ///   - caption: Post copy. FB is lenient on length (63k char cap).
    ///   - mediaURL: Optional media URL. Must already be a URL the broker
    ///     can reach (e.g. an ENVI-uploaded file in Cloud Storage). `nil`
    ///     for `.text` posts.
    ///   - mediaType: Which Graph endpoint the broker calls (`/feed` for
    ///     text + photo, `/videos` for video).
    /// - Returns: `PublishTicket` observable via `PublishingManager`.
    func publishPost(
        caption: String,
        mediaURL: URL?,
        mediaType: FacebookMediaType
    ) async throws -> PublishTicket {
        let body = FacebookPublishRequest(
            platform: "facebook",
            caption: caption,
            mediaURL: mediaURL?.absoluteString,
            mediaType: mediaType
        )
        return try await submitPublishJob(endpoint: "publish/jobs", body: body)
    }
}

// MARK: - Request Shapes

/// Wire shape for the broker's `/publish/jobs` endpoint when `platform` is
/// Facebook. The broker dispatches to `MetaProvider.publishFacebookPost`.
private struct FacebookPublishRequest: Encodable {
    let platform: String
    let caption: String
    let mediaURL: String?
    let mediaType: FacebookMediaType

    enum CodingKeys: String, CodingKey {
        case platform
        case caption
        case mediaURL = "media_url"
        case mediaType = "media_type"
    }
}
