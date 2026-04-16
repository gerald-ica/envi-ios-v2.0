//
//  TikTokConnector.swift
//  ENVI
//
//  Phase 08 — TikTok Sandbox Connector (v1.1 Real Social Connectors).
//
//  First REAL social connector, built on top of the Phase 6/7 OAuth broker.
//
//  Responsibility split
//  --------------------
//  - Broker (Cloud Functions) owns: PKCE, state JWT, token encrypt/persist,
//    refresh rotation detection, status polling, Firestore writes.
//  - This connector owns: OAuth session hop, file validation, chunked upload
//    of video bytes to TikTok's pre-signed URL, and surfacing Firestore-
//    observable `PublishTicket`s to `PublishingManager`.
//
//  Why an `actor` (not `@MainActor`)
//  ---------------------------------
//  Chunk upload is long-running and must NOT stall the main actor. The actor
//  serializes its own mutable state (nothing right now — reserved for future
//  in-flight publish cancellation). UI code hops via `await` when needed.
//
//  Public API surface
//  ------------------
//  - `connect()` → kicks off OAuth via `SocialOAuthManager`'s broker path;
//    surfaces `TikTokConnectorError.sandboxUserNotAllowed` when the broker
//    reports the tester isn't allowlisted.
//  - `refreshConnection()` → delegates to the broker's refresh handler.
//  - `publishVideo(at:caption:privacy:)` → validate, init, PUT chunks,
//    tell broker to begin status polling, return a `PublishTicket`.
//  - `listVideos(cursor:maxCount:)` → Display API read path via broker.
//

import AVFoundation
import Foundation
import UniformTypeIdentifiers

/// Actor owning the iOS end of the TikTok sandbox connector. Process-wide
/// singleton — instantiated once at app launch via `.shared`.
actor TikTokConnector {

    static let shared = TikTokConnector()

    // MARK: - Dependencies

    private let apiClient: APIClient
    private let urlSession: URLSession

    /// Hook into the pre-existing OAuth machinery so we don't duplicate the
    /// `ASWebAuthenticationSession` plumbing. The `connect()` path calls
    /// `SocialOAuthManager.connect(platform: .tiktok)` internally.
    private let oauthManager: SocialOAuthManager

    init(
        apiClient: APIClient = .shared,
        urlSession: URLSession = .shared,
        oauthManager: SocialOAuthManager = .shared
    ) {
        self.apiClient = apiClient
        self.urlSession = urlSession
        self.oauthManager = oauthManager
    }

    // MARK: - Constants

    /// 10 MB — well under TikTok's documented max and inside iOS URLSession's
    /// happy path (ATS chunking can stall above ~25 MB on flaky networks).
    private static let uploadChunkSizeBytes: Int = 10 * 1_048_576

    /// TikTok-mandated min/max video duration, in seconds.
    private static let minDurationSeconds: Double = 15
    private static let maxDurationSeconds: Double = 600

    /// TikTok's published 500 MB per-file ceiling.
    private static let maxVideoSizeBytes: Int = 500 * 1_048_576

    /// Allowed UTTypes — anything else rejects at validation time.
    private static let supportedContentTypes: Set<String> = [
        UTType.mpeg4Movie.identifier,
        UTType.quickTimeMovie.identifier,
        UTType.movie.identifier,
    ]

    // MARK: - Connect

    /// Drive the TikTok OAuth flow via the Phase 7 broker. Returns the
    /// resulting `PlatformConnection` on success.
    ///
    /// Error mapping:
    /// - Broker `TIKTOK_SANDBOX_USER_NOT_ALLOWED` → `.sandboxUserNotAllowed`
    /// - Generic transport failure → `.transportFailure`
    /// - User cancellation rethrows as `SocialOAuthManager.OAuthError.userCancelled`
    ///   so calling views can distinguish cancel-from-error.
    func connect() async throws -> PlatformConnection {
        do {
            // Use the broker-only entry point to avoid re-triggering the
            // TikTok-routing branch inside `SocialOAuthManager.connect`.
            return try await oauthManager.connectViaBroker(platform: .tiktok)
        } catch let error as SocialOAuthManager.OAuthError {
            // Inspect the underlying broker status response surfaced by the
            // manager. The broker encodes sandbox rejection into the `error`
            // query param on the callback URL; `SocialOAuthManager` flattens
            // that into `.connectionFailed`. We fetch the most recent status
            // doc to disambiguate before surfacing.
            if case .connectionFailed = error {
                if try await brokerReportedSandboxRejection() {
                    throw TikTokConnectorError.sandboxUserNotAllowed
                }
            }
            throw error
        } catch {
            throw TikTokConnectorError.transportFailure(
                detail: error.localizedDescription
            )
        }
    }

    /// Refresh-or-no-op. Broker handles rotation + reuse detection; this
    /// just surfaces the latest `PlatformConnection` snapshot.
    func refreshConnection() async throws -> PlatformConnection {
        do {
            return try await oauthManager.refreshToken(platform: .tiktok)
        } catch SocialOAuthManager.OAuthError.tokenExpired {
            throw TikTokConnectorError.tokenRefreshRequired
        } catch {
            throw TikTokConnectorError.transportFailure(
                detail: error.localizedDescription
            )
        }
    }

    // MARK: - Publish

    /// End-to-end inbox publish. Runs:
    ///
    ///   1. Client-side file validation (size, duration, format).
    ///   2. `POST /connectors/tiktok/publish/init` → pre-signed uploadURL.
    ///   3. Chunked `PUT` upload to TikTok directly (no auth header).
    ///   4. `POST /connectors/tiktok/publish/complete` to kick off the
    ///      broker's status poll loop.
    ///   5. Immediate return of `PublishTicket`. Caller observes Firestore
    ///      or polls `PublishingManager.waitForFinalStatus`.
    ///
    /// We intentionally do NOT await the final TikTok status here — the
    /// broker poll can take 5s-10min and the UI should show progress.
    func publishVideo(
        at fileURL: URL,
        caption: String,
        privacy: TikTokPrivacyLevel
    ) async throws -> PublishTicket {
        try validateVideoFile(at: fileURL)
        try await validateVideoDuration(at: fileURL)
        let fileSize = try fileSizeBytes(at: fileURL)

        let initResponse: PublishInitResponse
        do {
            initResponse = try await apiClient.request(
                endpoint: "connectors/tiktok/publish/init",
                method: .post,
                body: PublishInitRequest(
                    videoSize: fileSize,
                    caption: caption,
                    privacyLevel: privacy.rawValue
                ),
                requiresAuth: true
            )
        } catch {
            throw TikTokConnectorError.transportFailure(
                detail: "publish init failed: \(error.localizedDescription)"
            )
        }

        guard let uploadURL = URL(string: initResponse.uploadURL) else {
            throw TikTokConnectorError.transportFailure(detail: "bad upload url")
        }

        try await uploadChunks(
            fileURL: fileURL,
            uploadURL: uploadURL,
            totalBytes: fileSize,
            chunkSize: initResponse.chunkSize ?? Self.uploadChunkSizeBytes
        )

        // Tell the broker we're done uploading — this triggers
        // `pollUntilComplete` which polls TikTok and writes final status to
        // Firestore on our behalf.
        do {
            try await apiClient.requestVoid(
                endpoint: "connectors/tiktok/publish/complete",
                method: .post,
                body: PublishCompleteRequest(publishID: initResponse.publishID),
                requiresAuth: true
            )
        } catch {
            throw TikTokConnectorError.transportFailure(
                detail: "publish complete failed: \(error.localizedDescription)"
            )
        }

        return PublishTicket(jobID: initResponse.publishID, status: .queued)
    }

    // MARK: - List Videos

    /// Cursor-paginated video read via the Display API.
    ///
    /// - Parameters:
    ///   - cursor: Opaque cursor returned by TikTok. `nil` for first page.
    ///   - maxCount: 1...20 per TikTok docs; we clamp at 20.
    func listVideos(
        cursor: Int64? = nil,
        maxCount: Int = 20
    ) async throws -> (videos: [TikTokVideo], hasMore: Bool, nextCursor: Int64?) {
        let clampedCount = min(max(maxCount, 1), 20)
        var endpoint = "connectors/tiktok/videos?max_count=\(clampedCount)"
        if let cursor { endpoint += "&cursor=\(cursor)" }

        do {
            let response: VideoListResponse = try await apiClient.request(
                endpoint: endpoint,
                method: .get,
                requiresAuth: true
            )
            return (response.videos, response.hasMore ?? false, response.cursor)
        } catch {
            throw TikTokConnectorError.transportFailure(
                detail: "list videos failed: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Internal helpers

    /// Validate the file against TikTok's constraints. Throws a precise
    /// `TikTokConnectorError` the caller can map to UI copy.
    private func validateVideoFile(at url: URL) throws {
        // Extension check — cheapest filter, fails fast.
        let ext = url.pathExtension.lowercased()
        guard ext == "mp4" || ext == "mov" else {
            throw TikTokConnectorError.unsupportedVideoFormat
        }

        // UTType check — belt-and-braces against spoofed extensions.
        if let uttype = UTType(filenameExtension: ext) {
            let matches = Self.supportedContentTypes.contains(uttype.identifier)
                || uttype.conforms(to: .movie)
            guard matches else {
                throw TikTokConnectorError.unsupportedVideoFormat
            }
        }

        // File size.
        let size: Int
        do {
            size = try fileSizeBytes(at: url)
        } catch {
            throw TikTokConnectorError.videoFileUnreadable
        }
        guard size <= Self.maxVideoSizeBytes else {
            throw TikTokConnectorError.videoTooLarge(bytes: size)
        }

    }

    /// Split duration validation out from the synchronous path so the
    /// caller can `await` the async `AVURLAsset.load(.duration)` accessor
    /// without blocking the actor executor.
    private func validateVideoDuration(at url: URL) async throws {
        let asset = AVURLAsset(url: url)
        let duration: CMTime
        do {
            duration = try await asset.load(.duration)
        } catch {
            throw TikTokConnectorError.videoFileUnreadable
        }
        let seconds = CMTimeGetSeconds(duration)
        guard seconds.isFinite else {
            throw TikTokConnectorError.videoFileUnreadable
        }
        guard seconds >= Self.minDurationSeconds,
              seconds <= Self.maxDurationSeconds
        else {
            throw TikTokConnectorError.videoDurationOutOfRange
        }
    }

    private func fileSizeBytes(at url: URL) throws -> Int {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs[.size] as? NSNumber)?.intValue ?? 0
    }

    /// Upload the file in `chunkSize`-byte slices using raw `URLSession.upload`.
    /// TikTok's pre-signed URL rejects an `Authorization` header — we must
    /// NOT forward the Firebase ID token here.
    private func uploadChunks(
        fileURL: URL,
        uploadURL: URL,
        totalBytes: Int,
        chunkSize: Int
    ) async throws {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else {
            throw TikTokConnectorError.videoFileUnreadable
        }
        defer { try? handle.close() }

        var offset = 0
        while offset < totalBytes {
            let remaining = totalBytes - offset
            let thisChunk = min(chunkSize, remaining)
            let first = offset
            let last = offset + thisChunk - 1

            let data: Data
            do {
                if #available(iOS 13.4, *) {
                    try handle.seek(toOffset: UInt64(offset))
                    data = handle.readData(ofLength: thisChunk)
                } else {
                    handle.seek(toFileOffset: UInt64(offset))
                    data = handle.readData(ofLength: thisChunk)
                }
            } catch {
                throw TikTokConnectorError.videoFileUnreadable
            }

            var request = URLRequest(url: uploadURL)
            request.httpMethod = "PUT"
            request.setValue("video/mp4", forHTTPHeaderField: "Content-Type")
            request.setValue("\(thisChunk)", forHTTPHeaderField: "Content-Length")
            request.setValue(
                "bytes \(first)-\(last)/\(totalBytes)",
                forHTTPHeaderField: "Content-Range"
            )

            let (_, response) = try await urlSession.upload(for: request, from: data)
            guard let http = response as? HTTPURLResponse else {
                throw TikTokConnectorError.transportFailure(detail: "no http response")
            }

            // TikTok returns 206 while accepting chunks, 201 on final byte.
            if http.statusCode == 403 || http.statusCode == 410 {
                throw TikTokConnectorError.uploadURLExpired
            }
            guard (200...299).contains(http.statusCode) else {
                throw TikTokConnectorError.transportFailure(
                    detail: "upload chunk status \(http.statusCode)"
                )
            }

            offset += thisChunk
        }
    }

    /// Ask the broker for the latest status doc and check whether the most
    /// recent callback reported sandbox rejection. Used to disambiguate a
    /// generic `connectionFailed` surfaced by `SocialOAuthManager` into our
    /// `.sandboxUserNotAllowed` structured error.
    private func brokerReportedSandboxRejection() async throws -> Bool {
        struct StatusResponse: Decodable {
            let lastError: String?
            let lastErrorCode: String?
        }
        do {
            let status: StatusResponse = try await apiClient.request(
                endpoint: "oauth/tiktok/status",
                method: .get,
                requiresAuth: true
            )
            return status.lastErrorCode == "TIKTOK_SANDBOX_USER_NOT_ALLOWED"
                || status.lastError == "TIKTOK_SANDBOX_USER_NOT_ALLOWED"
        } catch {
            // Status probe is best-effort; a failure here means we fall back
            // to the generic OAuthError the caller already has.
            return false
        }
    }
}

// MARK: - API request/response DTOs

/// `POST /connectors/tiktok/publish/init` body.
private struct PublishInitRequest: Encodable {
    let videoSize: Int
    let caption: String
    let privacyLevel: String

    enum CodingKeys: String, CodingKey {
        case videoSize = "video_size"
        case caption
        case privacyLevel = "privacy_level"
    }
}

/// `POST /connectors/tiktok/publish/init` response.
private struct PublishInitResponse: Decodable {
    let publishID: String
    let uploadURL: String
    /// Optional override; when absent we fall back to `uploadChunkSizeBytes`.
    let chunkSize: Int?

    enum CodingKeys: String, CodingKey {
        case publishID = "publish_id"
        case uploadURL = "upload_url"
        case chunkSize = "chunk_size"
    }
}

/// `POST /connectors/tiktok/publish/complete` body.
private struct PublishCompleteRequest: Encodable {
    let publishID: String

    enum CodingKeys: String, CodingKey {
        case publishID = "publish_id"
    }
}

/// `GET /connectors/tiktok/videos` response.
private struct VideoListResponse: Decodable {
    let videos: [TikTokVideo]
    let cursor: Int64?
    let hasMore: Bool?

    enum CodingKeys: String, CodingKey {
        case videos
        case cursor
        case hasMore = "has_more"
    }
}
