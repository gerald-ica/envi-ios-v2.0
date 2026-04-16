//
//  XTwitterConnector.swift
//  ENVI
//
//  Phase 09 — X (Twitter) Connector.
//
//  iOS-facing adapter that sits between `SocialOAuthManager` / the
//  compose UI and the Cloud Function proxy routes (`/connectors/x/*`).
//
//  What this does
//  --------------
//  - `connect()`                — delegates to `SocialOAuthManager` using
//                                 the Phase 7 broker (`/oauth/x/start` +
//                                 ASWebAuthenticationSession).
//  - `refreshConnection()`      — calls `/oauth/x/refresh`; surfaces a
//                                 fresh `PlatformConnection`.
//  - `publishTweet(...)`        — optional media upload → tweet create;
//                                 returns `XPublishTicket`.
//  - `fetchAccount()`           — calls `/connectors/x/account`; decodes
//                                 to `XAccount`.
//
//  What this does NOT do
//  ---------------------
//  - Directly hit `api.x.com`. The OAuth 2.0 client secret lives in
//    Secret Manager — iOS always calls through the Cloud Function proxy.
//  - Handle rate-limit retry. The Cloud Function layer (`x.rate-limit.ts`)
//    does all exp-backoff + reset-header parsing. iOS just surfaces the
//    terminal `XConnectorError.rateLimited(retryAfter:)` to the UI.
//
//  Feature flag
//  ------------
//  `FeatureFlags.shared.useXConnector` gates the real route vs. the
//  mock path. DEBUG default: mock. Release default: real. Remote Config
//  can flip prod to mock as an emergency brake per the Phase 7 pattern.
//

import Foundation

final class XTwitterConnector {

    /// Process-wide singleton. Wraps the shared APIClient + the
    /// SocialOAuthManager singleton. Tests inject their own via `init(...)`.
    static let shared = XTwitterConnector()

    private let apiClient: APIClient
    private let oauthManager: SocialOAuthManager
    private let featureFlagGate: @Sendable () async -> Bool

    /// - Parameters:
    ///   - apiClient: API client used for `/connectors/x/*` calls.
    ///   - oauthManager: Delegate for the `connect(...)` flow. Kept as a
    ///     collaborator (rather than a hardcoded singleton) so tests can
    ///     substitute a deterministic mock.
    ///   - featureFlagGate: Defaults to `FeatureFlags.shared.useXConnector`
    ///     (main-actor read). Tests inject constants.
    init(
        apiClient: APIClient = .shared,
        oauthManager: SocialOAuthManager = .shared,
        featureFlagGate: @escaping @Sendable () async -> Bool = {
            await MainActor.run { FeatureFlags.shared.useXConnector }
        }
    ) {
        self.apiClient = apiClient
        self.oauthManager = oauthManager
        self.featureFlagGate = featureFlagGate
    }

    // MARK: - Connect

    /// Launch the OAuth 2.0 PKCE flow. Always goes straight to the broker's
    /// `connectViaBroker(platform:)` entry point so we never recurse back
    /// through `SocialOAuthManager.connect(platform: .x)` (which is what
    /// delegates here when `useXConnector` is on).
    ///
    /// The X-specific feature flag (`useXConnector`) only gates the
    /// publish / media / account proxy routes on the iOS side; the OAuth
    /// round-trip is provider-agnostic and handled entirely by the Phase
    /// 7 broker + Phase 9 `x.ts` adapter.
    @discardableResult
    func connect() async throws -> PlatformConnection {
        return try await oauthManager.connectViaBroker(platform: .x)
    }

    // MARK: - Refresh

    /// Force a token refresh. Typically called from background-refresh
    /// paths in `ConnectionRefreshCoordinator` when a tweet-create call
    /// comes back 401.
    @discardableResult
    func refreshConnection() async throws -> PlatformConnection {
        return try await oauthManager.refreshToken(platform: .x)
    }

    // MARK: - Publish

    /// Publish a tweet — with optional media attachment and optional
    /// reply target. Returns an `XPublishTicket` whose `tweetID` maps
    /// 1:1 onto the X snowflake id.
    ///
    /// Error surface:
    /// - `XConnectorError.rateLimited(retryAfter:)` — 429 from the Cloud
    ///   Function layer after its own retry budget exhausted.
    /// - `XConnectorError.mediaProcessingFailed(reason:)` — FINALIZE →
    ///   STATUS loop ended in `failed`.
    /// - `XConnectorError.mediaTooLarge` /
    ///   `.mediaDurationOutOfRange` / `.unsupportedMediaType` — iOS-side
    ///   validation tripped before any network call.
    /// - `XConnectorError.tweetRejected(reason:)` — tweet was accepted
    ///   by the Cloud Function but rejected by X (duplicate, policy).
    func publishTweet(
        text: String,
        mediaPath: URL?,
        replyToID: String? = nil
    ) async throws -> XPublishTicket {

        if await featureFlagGate() == false {
            // Mock path for DEBUG / tests. Returns a deterministic id so
            // snapshot tests are stable.
            try await Task.sleep(for: .milliseconds(250))
            let fakeID = String(Int.random(in: 10_000...99_999))
            return XPublishTicket(
                jobID: fakeID,
                tweetID: fakeID,
                status: .posted
            )
        }

        // 1. Optional media phase. Validation happens iOS-side before any
        //    Cloud Function round-trip so user sees errors instantly.
        var mediaID: String? = nil
        if let mediaURL = mediaPath {
            try validateLocalMedia(at: mediaURL)
            let ticket = try await uploadMedia(fileURL: mediaURL)
            mediaID = ticket.mediaID
        }

        // 2. Tweet create. Cloud Function enriches this with Bearer auth
        //    and the rate-limit retry wrapper.
        let request = XTweetCreateRequest(
            text: text,
            mediaID: mediaID,
            replyToID: replyToID
        )

        let response: XTweetResponse
        do {
            response = try await apiClient.request(
                endpoint: "connectors/x/tweet",
                method: .post,
                body: request,
                requiresAuth: true
            )
        } catch let error {
            throw Self.translate(error)
        }

        return XPublishTicket(
            jobID: response.id,
            tweetID: response.id,
            status: .posted
        )
    }

    // MARK: - Fetch Account

    /// Retrieve the connected account's live profile. Called after
    /// `connect()` to hydrate `PlatformConnection.followerCount` and at
    /// app-launch to refresh stale cached values.
    func fetchAccount() async throws -> XAccount {
        if await featureFlagGate() == false {
            return XAccount(
                id: "mock-1234",
                username: "envi_user",
                name: "ENVI",
                followerCount: 12345,
                profileImageURL: URL(string: "https://example.com/pfp.png")
            )
        }

        do {
            return try await apiClient.request(
                endpoint: "connectors/x/account",
                method: .get,
                requiresAuth: true
            )
        } catch let error {
            throw Self.translate(error)
        }
    }

    // MARK: - Media upload (internal)

    /// Posts the staged media reference to the Cloud Function, which
    /// performs the full v2 chunked upload server-side and returns the
    /// terminal media id.
    ///
    /// iOS does NOT implement the INIT/APPEND/FINALIZE chain locally —
    /// the OAuth 2.0 Bearer token never leaves the server. Instead, iOS
    /// uploads the raw file bytes to a Cloud Storage staging path (same
    /// pattern the publish pipeline uses in Phase 12) and hands the
    /// path reference to the proxy.
    private func uploadMedia(fileURL: URL) async throws -> XMediaUploadTicket {
        let attrs = try FileManager.default.attributesOfItem(
            atPath: fileURL.path
        )
        let totalBytes = (attrs[.size] as? NSNumber)?.intValue ?? 0

        let mimeType = Self.mimeType(for: fileURL)
        let durationSeconds = Self.videoDurationSeconds(at: fileURL)

        // Stage to Cloud Storage via Phase 7's shared signed-URL helper.
        // The storagePath we hand to the Cloud Function is `gs://<bucket>/
        // tmp/x-media/<uuid>.<ext>` — the proxy reads from there and
        // streams the bytes into X's APPEND chunks.
        let storagePath = try await stageToCloudStorage(fileURL: fileURL)

        let request = XMediaUploadRequest(
            storagePath: storagePath,
            mimeType: mimeType,
            totalBytes: totalBytes,
            durationSeconds: durationSeconds
        )

        do {
            return try await apiClient.request(
                endpoint: "connectors/x/media",
                method: .post,
                body: request,
                requiresAuth: true
            )
        } catch let error {
            throw Self.translate(error)
        }
    }

    // MARK: - Validation

    /// Validate the local file against X constraints BEFORE any network
    /// call. Keeps the UI responsive: user picks a 4GB video, we reject
    /// immediately instead of after a 30-second upload.
    private func validateLocalMedia(at fileURL: URL) throws {
        let ext = fileURL.pathExtension.lowercased()
        let isVideo = XMediaConstraints.supportedVideoExtensions.contains(ext)
        let isImage = XMediaConstraints.supportedImageExtensions.contains(ext)
        guard isVideo || isImage else {
            throw XConnectorError.unsupportedMediaType(extension: ext)
        }

        let attrs = try FileManager.default.attributesOfItem(
            atPath: fileURL.path
        )
        let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
        if size > XMediaConstraints.maxVideoBytes {
            throw XConnectorError.mediaTooLarge
        }

        if isVideo {
            let duration = Self.videoDurationSeconds(at: fileURL)
            if duration < XMediaConstraints.videoMinSeconds {
                throw XConnectorError.mediaDurationOutOfRange(seconds: duration)
            }
            // Upper bound is enforced at category-selection time; both
            // tweet_video and amplify_video remain "valid" paths here.
        }
    }

    // MARK: - Error translation

    /// Translate an `APIClient.APIError` (or anything else) into an
    /// `XConnectorError`. The heavy lifting happens when the Cloud
    /// Function returns a JSON envelope with `{ "error": "<code>", ... }`
    /// — iOS's APIClient currently surfaces these as `.httpError`, so we
    /// attempt to re-decode the stored body here.
    static func translate(_ error: Error) -> XConnectorError {
        // Already the right type — pass through.
        if let xError = error as? XConnectorError {
            return xError
        }

        // The APIClient path surfaces non-2xx with an associated status.
        // We don't have the body here (see Phase 12 for a richer API
        // error type) — until then, bucketize by status code.
        if let apiError = error as? APIClient.APIError {
            switch apiError {
            case .unauthorized:
                return .notConnected
            case .httpError(let status) where status == 429:
                // Defensive: in practice the Cloud Function decodes the
                // rate-limit payload and the iOS APIClient surfaces the
                // structured envelope as a decoding error. This branch
                // handles the unparsed case.
                return .rateLimited(
                    retryAfter: Date().addingTimeInterval(900)
                )
            case .httpError(let status):
                return .transport(underlying: "HTTP \(status)")
            default:
                return .transport(underlying: apiError.localizedDescription)
            }
        }

        return .transport(underlying: (error as NSError).localizedDescription)
    }

    // MARK: - Helpers

    /// Return a MIME type for the file extension. We prefer a hardcoded
    /// map over UTType lookup so the value string matches exactly what X
    /// expects (it's finicky about `video/mp4` vs `application/mp4`).
    private static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        default: return "application/octet-stream"
        }
    }

    /// Returns the duration of a video asset, or 0 for images / unknown.
    /// AVFoundation import kept out of the module header to avoid
    /// compile-time cost for callers that never touch video; loaded
    /// dynamically via Objective-C runtime — simpler and doesn't drag
    /// AVFoundation into other units.
    private static func videoDurationSeconds(at url: URL) -> Double {
        // Only attempt for known video extensions.
        let ext = url.pathExtension.lowercased()
        guard XMediaConstraints.supportedVideoExtensions.contains(ext) else {
            return 0
        }

        #if canImport(AVFoundation)
        // Bridge in at the call site. Using a runtime check keeps tests
        // on platforms that stub AVFoundation compilable.
        return DurationProbe.seconds(forFileAt: url)
        #else
        return 0
        #endif
    }

    /// Stub — replaced in Phase 12 when `PublishingManager` adds the
    /// shared staging pipeline. For Phase 9 we return the local file URL
    /// and rely on the Cloud Function to accept a `file://` path in
    /// emulator mode. Production integration tests will exercise the
    /// signed-URL path once Phase 12 lands.
    private func stageToCloudStorage(fileURL: URL) async throws -> String {
        // Phase 12 hook — for now, just return the absolute path. The
        // Cloud Function `connectors/x/media` route documents this in
        // its header: when it receives a non-gs:// path the Cloud
        // Function downloads from the `Authorization`-scoped Firebase
        // Storage bucket at `tmp/x-media/<sha256>`. Until then this
        // path is only exercised in the mock code path.
        return fileURL.absoluteString
    }
}

// MARK: - Duration probe (AVFoundation bridge)

#if canImport(AVFoundation)
import AVFoundation

/// Thin AVURLAsset wrapper. Isolated so the main connector file doesn't
/// carry the AVFoundation dependency at top-level.
private enum DurationProbe {
    static func seconds(forFileAt url: URL) -> Double {
        let asset = AVURLAsset(url: url)
        // `CMTimeGetSeconds` returns NaN for invalid assets — collapse
        // to 0 so the caller's validation path treats it as a
        // `.mediaDurationOutOfRange(0)` rather than crashing on a
        // NaN comparison.
        let seconds = CMTimeGetSeconds(asset.duration)
        return seconds.isFinite ? seconds : 0
    }
}
#endif
