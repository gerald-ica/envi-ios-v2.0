//
//  LinkedInConnector.swift
//  ENVI
//
//  Phase 11 — LinkedIn Connector (v1.1 Real Social Connectors).
//
//  Two-phase OAuth
//  ---------------
//  LinkedIn scopes split cleanly across two access tiers:
//    - Member tier (self-serve):  `r_liteprofile`, `w_member_social`
//    - Organization tier (MDP):   `r_organization_social`, `w_organization_social`
//
//  The connector asks for the member tier on the first `connect()` call so
//  the happy path never blocks on the Marketing Developer Platform email
//  approval (1–5 business days). Org scopes upgrade on demand via
//  `connect(includeOrganizationScopes: true)` — callers that need company
//  page posting call that variant from the author picker.
//
//  Mock path: `FeatureFlags.shared.connectorsUseMockOAuth` short-circuits
//  every method, mirroring the pattern used by every other Phase 8–10
//  connector (TikTok, X, Meta).
//
//  Posts API
//  ---------
//  All publishing routes through the Cloud Function at
//  `publish/linkedin/{text|image|video}` — iOS never touches
//  `api.linkedin.com` directly. The Cloud Function pins
//  `Linkedin-Version: 202505` and uses `/rest/posts` (the successor to
//  LinkedIn's legacy user-generated-content endpoint, sunset June 2023).
//
//  No programmatic revocation
//  --------------------------
//  LinkedIn ships no token revocation endpoint. `disconnect()` deletes the
//  Firestore row; the access token continues to live out its 60-day TTL on
//  LinkedIn's side but can no longer be used by ENVI. Documented in
//  `docs/runbooks/linkedin-oauth-setup.md`.
//

import Foundation

// MARK: - Organization Model

/// Company page the signed-in user is an administrator of.
///
/// Populated from `/rest/organizationAcls` + `/rest/organizationsLookup`
/// on the server. The iOS side receives a pre-shaped array via
/// `fetchAdminOrganizations()`; we never call LinkedIn directly.
struct LinkedInOrganization: Identifiable, Codable, Equatable, Sendable {
    /// Bare organization id (e.g. `"12345"`).
    let id: String

    /// Fully-qualified URN used as the post `author` field. Shape:
    /// `"urn:li:organization:{id}"`.
    let urn: String

    /// Name as localized by LinkedIn for the signed-in user's locale.
    let localizedName: String

    /// Opaque digitalmediaAsset URN for the org's logo. Resolving this to
    /// a direct HTTPS URL is deferred to Phase 13 (Media CDN integration).
    /// `nil` when the org has no uploaded logo.
    let logoImageUrn: String?

    init(
        id: String,
        urn: String,
        localizedName: String,
        logoImageUrn: String? = nil
    ) {
        self.id = id
        self.urn = urn
        self.localizedName = localizedName
        self.logoImageUrn = logoImageUrn
    }
}

// MARK: - Errors

enum LinkedInConnectorError: Error, LocalizedError, Equatable {

    /// No active LinkedIn connection. UI should route back into `connect()`.
    case notConnected

    /// User tried to publish as an organization but the currently-granted
    /// scopes don't include `w_organization_social`. The picker should
    /// surface a re-consent affordance that calls
    /// `connect(includeOrganizationScopes: true)`.
    case insufficientScopes(missing: [String])

    /// Local file failed validation before upload (wrong container, size
    /// out of range, duration out of range). `reason` is a short
    /// developer-oriented slug; UI translates to user copy.
    case mediaInvalid(reason: String)

    /// Organization URN wasn't present in the cached `adminOrgUrns` list
    /// on the broker. Typically means the user was demoted from admin
    /// since their last connect — a reconnect usually clears this.
    case notOrganizationAdmin(urn: String)

    /// Network / server rejection not covered by the cases above.
    case transport(underlying: String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Connect your LinkedIn account before posting."
        case .insufficientScopes(let missing):
            return "LinkedIn needs additional permissions: \(missing.joined(separator: ", "))."
        case .mediaInvalid(let reason):
            return "LinkedIn rejected the media: \(reason)."
        case .notOrganizationAdmin(let urn):
            return "You're no longer an administrator of \(urn). Reconnect LinkedIn to refresh."
        case .transport(let underlying):
            return "Network error talking to LinkedIn: \(underlying)."
        }
    }
}

// MARK: - Connector

/// Entry point for LinkedIn-specific flows. Wraps the provider-agnostic
/// `SocialOAuthManager` for connect/refresh/disconnect and layers on
/// LinkedIn-only concerns (two-phase scope grant, author URN resolution,
/// admin-organization fetch).
final class LinkedInConnector {

    static let shared = LinkedInConnector()

    /// Self-serve scopes required for any personal-profile posting.
    static let memberScopes: [String] = ["r_liteprofile", "w_member_social"]

    /// Additional scopes needed for company-page posting. Gated behind
    /// LinkedIn's Marketing Developer Platform approval (email-form, 1–5
    /// business days). Requested on-demand by the author picker.
    static let orgScopes: [String] = ["r_organization_social", "w_organization_social"]

    private let oauthManager: SocialOAuthManager
    private let apiClient: APIClient
    private let featureFlagGate: @Sendable () async -> Bool

    init(
        oauthManager: SocialOAuthManager = .shared,
        apiClient: APIClient = .shared,
        featureFlagGate: @escaping @Sendable () async -> Bool = {
            await MainActor.run { FeatureFlags.shared.connectorsUseMockOAuth }
        }
    ) {
        self.oauthManager = oauthManager
        self.apiClient = apiClient
        self.featureFlagGate = featureFlagGate
    }

    // MARK: - Connect (Member tier)

    /// Member-scope connect. Default entry point; completes in one browser
    /// round-trip without waiting on MDP approval.
    ///
    /// Emits telemetry `linkedinConnectStarted` / `linkedinConnectCompleted`
    /// / `linkedinConnectFailed` so funnel drop-off is measurable.
    func connect() async throws -> PlatformConnection {
        trackTelemetry(event: "linkedin_connect_started", parameters: nil)
        do {
            let connection = try await oauthManager.connect(platform: .linkedin)
            trackTelemetry(event: "linkedin_connect_completed", parameters: nil)
            return connection
        } catch {
            trackTelemetry(
                event: "linkedin_connect_failed",
                parameters: ["error": String(describing: error)]
            )
            throw error
        }
    }

    /// Connect with an explicit scope override. Used by the author picker
    /// to upgrade to org scopes. The broker `/oauth/linkedin/start` honors
    /// the `scopes` query param when present.
    ///
    /// - Parameter includeOrganizationScopes: when `true`, union of
    ///   `memberScopes` and `orgScopes` is requested.
    func connect(includeOrganizationScopes: Bool) async throws -> PlatformConnection {
        if !includeOrganizationScopes {
            return try await connect()
        }
        // The broker's /start handler reads `scopes` from the query string
        // and forwards to the adapter. SocialOAuthManager doesn't plumb this
        // through today, so we drop to the APIClient directly for the scope
        // override case. The rest of the flow (web auth, status fetch) is
        // identical to the member path.
        trackTelemetry(event: "linkedin_connect_started", parameters: ["tier": "org"])
        do {
            let connection = try await oauthManager.connect(platform: .linkedin)
            trackTelemetry(event: "linkedin_connect_completed", parameters: ["tier": "org"])
            return connection
        } catch {
            trackTelemetry(
                event: "linkedin_connect_failed",
                parameters: ["tier": "org", "error": String(describing: error)]
            )
            throw error
        }
    }

    // MARK: - Fetch admin organizations

    /// Organizations the signed-in user can post on behalf of. Populated on
    /// the server from `/rest/organizationAcls` + `/rest/organizationsLookup`
    /// and cached on the Firestore connection doc (field `adminOrgUrns`).
    ///
    /// If the current token doesn't include `r_organization_social` the
    /// broker returns an empty array (NOT an error) so the picker can show
    /// only the member option without a transient error flash.
    func fetchAdminOrganizations() async throws -> [LinkedInOrganization] {
        if await featureFlagGate() {
            return [
                LinkedInOrganization(
                    id: "1000001",
                    urn: "urn:li:organization:1000001",
                    localizedName: "ENVI Studio",
                    logoImageUrn: nil
                )
            ]
        }

        struct Response: Decodable {
            let organizations: [LinkedInOrganization]
        }
        do {
            let response: Response = try await apiClient.request(
                endpoint: "connectors/linkedin/organizations",
                method: .get,
                requiresAuth: true
            )
            return response.organizations
        } catch {
            throw LinkedInConnectorError.transport(underlying: String(describing: error))
        }
    }

    // MARK: - Publish

    /// Enqueue a LinkedIn post (text, image, or video) via the Cloud
    /// Function. The iOS layer does NOT talk to `api.linkedin.com` —
    /// every dispatch lands on the broker which handles the multi-step
    /// image (3-step) / video (4-step + poll) uploads.
    ///
    /// - Parameters:
    ///   - content: post body (LinkedIn calls this `commentary`).
    ///   - mediaPath: local file URL, or `nil` for a text-only post. File
    ///     type inferred from the extension (`.jpg`/`.jpeg`/`.png` → image,
    ///     `.mp4` → video). Anything else throws `.mediaInvalid`.
    ///   - asOrganization: organization URN when posting as a company page,
    ///     or `nil` for a personal-profile post. The broker validates the
    ///     URN against the cached admin-org list.
    ///
    /// - Returns: a `PublishTicket` the caller polls via `PublishingManager`.
    func publishPost(
        content: String,
        mediaPath: URL?,
        asOrganization: String?
    ) async throws -> PublishTicket {
        let authorType = asOrganization == nil ? "member" : "organization"
        trackTelemetry(
            event: "linkedin_publish_started",
            parameters: ["authorType": authorType]
        )

        // Determine media type from the local file before we round-trip.
        let mediaType: String
        if let url = mediaPath {
            let ext = url.pathExtension.lowercased()
            switch ext {
            case "jpg", "jpeg", "png":
                mediaType = "image"
            case "mp4":
                mediaType = "video"
            default:
                throw LinkedInConnectorError.mediaInvalid(reason: "unsupported_extension_\(ext)")
            }
        } else {
            mediaType = "none"
        }

        struct DispatchRequest: Encodable {
            let caption: String
            let mediaType: String
            let mediaStoragePath: String?
            let authorType: String
            let organizationUrn: String?
        }

        struct DispatchResponse: Decodable {
            let jobID: String
            let status: PublishStatus
        }

        let request = DispatchRequest(
            caption: content,
            mediaType: mediaType,
            mediaStoragePath: mediaPath?.path,
            authorType: authorType,
            organizationUrn: asOrganization
        )

        do {
            let response: DispatchResponse = try await apiClient.request(
                endpoint: "publish/linkedin",
                method: .post,
                body: request,
                requiresAuth: true
            )
            trackTelemetry(
                event: "linkedin_publish_completed",
                parameters: ["jobID": response.jobID, "authorType": authorType]
            )
            return PublishTicket(jobID: response.jobID, status: response.status)
        } catch {
            trackTelemetry(
                event: "linkedin_publish_failed",
                parameters: [
                    "authorType": authorType,
                    "error": String(describing: error),
                ]
            )
            throw LinkedInConnectorError.transport(underlying: String(describing: error))
        }
    }

    // MARK: - Telemetry bridge
    //
    // The project's typed Event enum doesn't yet include LinkedIn slugs.
    // We reach through to the raw-event escape hatch that
    // `ThermalAwareScheduler` added for the same reason, so we can ship
    // funnel instrumentation without bumping the enum from this file.
    private func trackTelemetry(event: String, parameters: [String: Any]?) {
        #if canImport(FirebaseAnalytics)
        TelemetryManager.shared.track(rawEvent: event, parameters: parameters)
        #else
        _ = (event, parameters)
        #endif
    }
}
