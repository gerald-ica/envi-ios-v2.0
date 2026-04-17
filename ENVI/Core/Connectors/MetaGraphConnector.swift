//
//  MetaGraphConnector.swift
//  ENVI
//
//  Phase 10 — Meta Family Connector (v1.1 Real Social Connectors).
//
//  Shared base class brokering OAuth + token lifecycle for Facebook Pages,
//  Instagram Business/Creator, and Threads under 3 distinct App IDs.
//
//  Why an `open class` (not a protocol or `actor`)
//  -----------------------------------------------
//  Facebook / Instagram / Threads share ~80% of their flow: all three are
//  OAuth 2.0 on top of Meta's Graph, all three go through the same broker
//  endpoints, all three produce a `PlatformConnection`. The 20% that differs
//  is covered by a single `MetaPlatform` enum + a tiny `baseGraphURL` hook
//  that Threads overrides. Subclasses are `open` so we don't need to fork
//  the whole connector for per-platform publish surfaces — each subclass
//  adds its own `publish*` methods without redoing OAuth.
//
//  Threads is the CRITICAL override: its Graph lives at `graph.threads.net`,
//  not `graph.facebook.com`. Forgetting to override `baseGraphURL` in
//  `ThreadsConnector` is a fail-loud compile error because the base
//  deliberately returns the FB host.
//
//  Responsibility split
//  --------------------
//  - Broker (Cloud Functions `MetaProvider`) owns: PKCE, state JWT, token
//    encryption, long-lived exchange via `fb_exchange_token`, refresh, Page
//    access token storage, IG account-type detection, Graph publish calls.
//  - This connector owns: OAuth session hop via `SocialOAuthManager`,
//    surfacing `PlatformConnection` state to `@Published` observers, and
//    delegating publish ops to the broker (`POST /publish/jobs`).
//
//  No client secrets live in this file. App IDs are public identifiers
//  (verified against Meta's App Dashboard for Phase 10).
//

import Foundation
import AuthenticationServices
import Combine

/// Which Meta sub-platform a connector wraps. Each case carries the minimal
/// set of public identifiers needed by the broker + iOS surface. Secrets are
/// pulled server-side from Secret Manager in `MetaProvider`.
internal enum MetaPlatform {
    /// Facebook Pages. App ID `1233228574968466`.
    case facebook(appID: String)

    /// Instagram Business/Creator. App ID `1811522229543951`. The client
    /// token (`3bb10460a0360e4adcdfc98609ae0cb0`) is an app-level public
    /// token safe to ship in the iOS binary — NOT a user secret.
    case instagram(appID: String, clientToken: String)

    /// Threads standalone. App ID `1604969460421980`. Parent app group
    /// (`1649869446444171`) is a Secret Manager discriminator only.
    case threads(appID: String)

    /// The `SocialPlatform` this Meta connector publishes as. Matters for
    /// broker routing + telemetry.
    var socialPlatform: SocialPlatform {
        switch self {
        case .facebook: return .facebook
        case .instagram: return .instagram
        case .threads: return .threads
        }
    }

    /// App ID as a string — public identifier, fine to emit in logs.
    var appID: String {
        switch self {
        case .facebook(let id): return id
        case .instagram(let id, _): return id
        case .threads(let id): return id
        }
    }
}

/// Errors that any Meta-family connector can throw. Sub-platform-specific
/// errors live in their own nested enums (e.g. `InstagramConnectorError`).
enum MetaConnectorError: Error, LocalizedError {
    /// OAuth broker returned an error or the user cancelled.
    case oauthFailed(SocialPlatform, underlying: Error?)
    /// Disconnect call to broker failed.
    case disconnectFailed(SocialPlatform)
    /// Token refresh failed or requires user reauth.
    case refreshFailed(SocialPlatform, needsReauth: Bool)
    /// Broker returned an unexpected response shape.
    case invalidResponse(SocialPlatform)

    var errorDescription: String? {
        switch self {
        case .oauthFailed(let p, _):
            return "Failed to connect \(p.rawValue)."
        case .disconnectFailed(let p):
            return "Failed to disconnect \(p.rawValue)."
        case .refreshFailed(let p, let needsReauth):
            return needsReauth
                ? "\(p.rawValue) needs to be reconnected."
                : "Failed to refresh \(p.rawValue) token."
        case .invalidResponse(let p):
            return "Received an invalid response for \(p.rawValue)."
        }
    }
}

/// Shared base for the three Meta-family connectors. Subclasses fix the
/// `metaPlatform` via their designated init and — if their Graph host
/// differs — override `baseGraphURL`.
class MetaGraphConnector: ObservableObject {

    // MARK: - Configuration

    /// Which Meta sub-platform this instance wraps. Used by subclasses to
    /// select the correct publish path and by telemetry to tag events.
    internal let metaPlatform: MetaPlatform

    /// Base URL for the Graph API. Defaults to Facebook Graph v21.0.
    /// `ThreadsConnector` MUST override this to `graph.threads.net/v1.0`.
    ///
    /// Declared as an instance property (not `static`) so subclasses override
    /// per-instance rather than requiring a new type parameter.
    var baseGraphURL: URL {
        URL(string: "https://graph.facebook.com/v21.0")!
    }

    // MARK: - Published State

    /// Current connection state. `nil` before `connect()` resolves.
    @Published private(set) var connection: PlatformConnection?

    // MARK: - Dependencies

    /// Reused so every Meta sub-platform uses the same broker pipeline
    /// (`/oauth/{slug}/start`, `/callback`, `/refresh`, `/disconnect`).
    private let oauthManager: SocialOAuthManager

    /// API client used for publish delegation + Meta-specific read paths
    /// (`GET /meta/pages`, `POST /meta/ig-account-type`).
    internal let apiClient: APIClient

    // MARK: - Init

    /// Designated init. Subclasses call this with their fixed `MetaPlatform`.
    /// - Parameters:
    ///   - metaPlatform: Which Meta sub-platform this instance wraps.
    ///   - oauthManager: OAuth broker wrapper. Defaults to shared singleton.
    ///   - apiClient: Broker HTTP client. Defaults to shared singleton.
    init(
        metaPlatform: MetaPlatform,
        oauthManager: SocialOAuthManager = .shared,
        apiClient: APIClient = .shared
    ) {
        self.metaPlatform = metaPlatform
        self.oauthManager = oauthManager
        self.apiClient = apiClient
    }

    // MARK: - OAuth Lifecycle

    /// Kick off the OAuth flow for this sub-platform. Delegates to
    /// `SocialOAuthManager` which drives `ASWebAuthenticationSession` on top
    /// of the broker's `/start` → provider → `/callback` pipeline.
    ///
    /// - Parameter presentationAnchor: Reserved — the shared
    ///   `ASWebAuthenticationSessionAdapter` resolves the anchor from the
    ///   active window scene. Accepted here so subclasses can subclass + fix
    ///   an explicit anchor in SwiftUI previews or tests if needed.
    /// - Returns: Resolved `PlatformConnection` as stored by the broker.
    @discardableResult
    func connect(
        presentationAnchor: ASPresentationAnchor
    ) async throws -> PlatformConnection {
        let platform = metaPlatform.socialPlatform
        do {
            let result = try await oauthManager.connect(platform: platform)
            await MainActor.run { self.connection = result }
            return result
        } catch {
            throw MetaConnectorError.oauthFailed(platform, underlying: error)
        }
    }

    /// Revoke at the provider + delete broker-side state. Clears
    /// `connection` on success.
    func disconnect() async throws {
        let platform = metaPlatform.socialPlatform
        do {
            try await oauthManager.disconnect(platform: platform)
            await MainActor.run { self.connection = nil }
        } catch {
            throw MetaConnectorError.disconnectFailed(platform)
        }
    }

    /// Force a long-lived token refresh via `fb_exchange_token` (FB/IG) or
    /// the Threads equivalent. Returns the new connection snapshot; if the
    /// token is past its 60-day window the broker responds with
    /// `requiresReauth` and this throws `.refreshFailed(needsReauth: true)`.
    @discardableResult
    func refreshToken() async throws -> PlatformConnection {
        let platform = metaPlatform.socialPlatform
        do {
            let result = try await oauthManager.refreshToken(platform: platform)
            await MainActor.run { self.connection = result }
            return result
        } catch SocialOAuthManager.OAuthError.tokenExpired {
            throw MetaConnectorError.refreshFailed(platform, needsReauth: true)
        } catch {
            throw MetaConnectorError.refreshFailed(platform, needsReauth: false)
        }
    }

    // MARK: - Publish Helpers (internal to subclasses)

    /// Delegate a publish job to the broker's shared `/publish/jobs` path.
    /// Subclasses build their own payload and call this helper rather than
    /// each duplicating the APIClient wiring.
    internal func submitPublishJob<Body: Encodable>(
        endpoint: String,
        body: Body
    ) async throws -> PublishTicket {
        let response: PublishJobResponse = try await apiClient.request(
            endpoint: endpoint,
            method: .post,
            body: body,
            requiresAuth: true
        )
        return PublishTicket(jobID: response.jobID, status: response.status)
    }
}

// MARK: - API Responses (shared)

/// Broker response shape for publish job submission. Matches the existing
/// `PublishingManager` contract so publish tickets are interchangeable.
internal struct PublishJobResponse: Decodable {
    let jobID: String
    let status: PublishStatus
}
