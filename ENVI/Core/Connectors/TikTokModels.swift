//
//  TikTokModels.swift
//  ENVI
//
//  Phase 08 — TikTok Sandbox Connector (v1.1 Real Social Connectors).
//
//  Shared models + error surface used by `TikTokConnector`.
//
//  Naming conventions
//  ------------------
//  - Field names on `TikTokVideo` / `TikTokUserInfo` match the snake_case
//    shape returned by the broker's `/connectors/tiktok/*` routes. The
//    broker performs the 1:1 mapping from TikTok's raw Display API payload
//    onto these structs, so `CodingKeys` carries the translation.
//  - Durations are expressed in seconds (`Int`); timestamps as `Date`
//    decoded from TikTok's `create_time` (unix seconds).
//  - All structs are `Sendable` so they cross the `TikTokConnector` actor
//    boundary freely.
//

import Foundation

// MARK: - User Info

/// Normalized subset of TikTok's `/v2/user/info/` Display API payload.
///
/// Only the fields ENVI surfaces in app UI are modeled — extra fields in the
/// raw response are tolerated by `Decodable` and dropped.
struct TikTokUserInfo: Codable, Sendable, Equatable {
    /// Stable provider user id. Primary key for account-switch detection.
    let openId: String

    /// Cross-app stable id (present when TikTok assigns one). Nullable per
    /// TikTok docs — some sandbox accounts don't populate it.
    let unionId: String?

    /// Public display name. Nullable only when TikTok temporarily suppresses
    /// it during profile moderation — we treat `nil` as "show open_id".
    let displayName: String?

    /// HTTPS URL to the user's avatar. Nullable for freshly-created accounts.
    let avatarUrl: URL?

    /// Follower count. Nullable — Display API gates this behind a scope
    /// tier and returns `null` in sandbox for unapproved testers.
    let followerCount: Int?

    /// Lifetime uploaded video count. Same nullability rationale as above.
    let videoCount: Int?

    enum CodingKeys: String, CodingKey {
        case openId = "open_id"
        case unionId = "union_id"
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case followerCount = "follower_count"
        case videoCount = "video_count"
    }
}

// MARK: - Video

/// Normalized TikTok video record surfaced by the Display API.
///
/// The broker projects TikTok's `video.list` payload onto this struct before
/// returning it to the client. `id`, `duration` are always present; the rest
/// may be `nil` when the tester account is still in sandbox propagation.
struct TikTokVideo: Codable, Sendable, Equatable, Identifiable {
    /// TikTok-issued video id. Stable across sessions.
    let id: String

    /// Optional caption/title text.
    let title: String?

    /// URL of the cover/thumbnail image. TikTok pre-signs these with a short
    /// TTL — callers should not persist.
    let coverImageUrl: URL?

    /// Upload timestamp. Derived from the raw `create_time` unix seconds.
    let createTime: Date?

    /// Video duration in seconds. Always present.
    let duration: Int

    let viewCount: Int?
    let likeCount: Int?
    let commentCount: Int?
    let shareCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case coverImageUrl = "cover_image_url"
        case createTime = "create_time"
        case duration
        case viewCount = "view_count"
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case shareCount = "share_count"
    }

    init(
        id: String,
        title: String? = nil,
        coverImageUrl: URL? = nil,
        createTime: Date? = nil,
        duration: Int,
        viewCount: Int? = nil,
        likeCount: Int? = nil,
        commentCount: Int? = nil,
        shareCount: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.coverImageUrl = coverImageUrl
        self.createTime = createTime
        self.duration = duration
        self.viewCount = viewCount
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.shareCount = shareCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.title = try c.decodeIfPresent(String.self, forKey: .title)
        self.coverImageUrl = try c.decodeIfPresent(URL.self, forKey: .coverImageUrl)
        self.duration = try c.decodeIfPresent(Int.self, forKey: .duration) ?? 0
        self.viewCount = try c.decodeIfPresent(Int.self, forKey: .viewCount)
        self.likeCount = try c.decodeIfPresent(Int.self, forKey: .likeCount)
        self.commentCount = try c.decodeIfPresent(Int.self, forKey: .commentCount)
        self.shareCount = try c.decodeIfPresent(Int.self, forKey: .shareCount)
        if let unix = try c.decodeIfPresent(Int64.self, forKey: .createTime) {
            self.createTime = Date(timeIntervalSince1970: TimeInterval(unix))
        } else {
            self.createTime = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(title, forKey: .title)
        try c.encodeIfPresent(coverImageUrl, forKey: .coverImageUrl)
        try c.encode(duration, forKey: .duration)
        try c.encodeIfPresent(viewCount, forKey: .viewCount)
        try c.encodeIfPresent(likeCount, forKey: .likeCount)
        try c.encodeIfPresent(commentCount, forKey: .commentCount)
        try c.encodeIfPresent(shareCount, forKey: .shareCount)
        if let t = createTime {
            try c.encode(Int64(t.timeIntervalSince1970), forKey: .createTime)
        }
    }
}

// MARK: - Publish Status

/// Lifecycle state of a TikTok inbox-upload publish job.
///
/// Maps 1:1 onto TikTok's `/v2/post/publish/status/fetch/` states and is
/// persisted in the `users/{uid}/connections/tiktok/publishes/{publishID}`
/// Firestore doc by the broker's poll loop.
enum TikTokPublishStatus: String, Codable, Sendable {
    /// Uploading video bytes — chunks still being PUT to `upload_url`.
    case processingUpload = "PROCESSING_UPLOAD"

    /// Bytes received; inbox waiting on tester review (sandbox terminal state).
    case sendToUserInbox = "SEND_TO_USER_INBOX"

    /// Tester approved + TikTok published publicly (prod terminal state).
    case publishComplete = "PUBLISH_COMPLETE"

    /// Terminal failure. Check `TikTokConnectorError.publishFailed`'s reason.
    case failed = "FAILED"

    /// True once the job has reached a state the caller can stop polling on.
    var isTerminal: Bool {
        switch self {
        case .sendToUserInbox, .publishComplete, .failed: return true
        case .processingUpload: return false
        }
    }
}

// MARK: - Privacy Level

/// TikTok's supported privacy levels for the Content Posting API.
///
/// Sandbox testers can ONLY publish as `.onlyMe` until TikTok approves the
/// app for `PUBLIC_TO_EVERYONE`. The connector enforces this client-side to
/// avoid a confusing 400 from the broker.
enum TikTokPrivacyLevel: String, Codable, Sendable {
    case publicToEveryone = "PUBLIC_TO_EVERYONE"
    case mutualFollowFriends = "MUTUAL_FOLLOW_FRIENDS"
    case followerOfCreator = "FOLLOWER_OF_CREATOR"
    case selfOnly = "SELF_ONLY"

    /// Convenience alias used by callers that don't want to spell out the
    /// TikTok constant. Always resolves to `.selfOnly`.
    static let onlyMe: TikTokPrivacyLevel = .selfOnly
}

// MARK: - Error Surface

/// Errors thrown by `TikTokConnector`. Adopts `LocalizedError` so SwiftUI
/// `alert(error:)` surfaces user-readable text directly.
///
/// The sandbox UX (see `TikTokSandboxErrorView`) keys off
/// `sandboxUserNotAllowed` specifically; generic publish failures fall back
/// to the standard error sheet.
enum TikTokConnectorError: LocalizedError, Equatable {
    /// Broker surfaced the structured `TIKTOK_SANDBOX_USER_NOT_ALLOWED` code
    /// during the OAuth callback hop. Only meaningful in staging — in prod
    /// the sandbox allowlist no longer applies.
    case sandboxUserNotAllowed

    /// The pre-signed `upload_url` handed back by `/publish/init` expired
    /// before we finished chunk-PUTting bytes. TikTok gives us ~1h; if we
    /// hit this, retry the whole init.
    case uploadURLExpired

    /// Video file exceeds TikTok's 500 MB per-file ceiling.
    case videoTooLarge(bytes: Int)

    /// Video duration outside TikTok's 15s–10min valid window.
    case videoDurationOutOfRange

    /// Video file is not an MP4/MOV — TikTok rejects everything else.
    case unsupportedVideoFormat

    /// Video file is unreadable (not found, permission denied, corrupt
    /// `AVURLAsset`). Maps to a generic "couldn't read video" message.
    case videoFileUnreadable

    /// TikTok returned a `FAILED` publish status. `reason` is the raw
    /// error message from TikTok; surface as-is for support diagnostics.
    case publishFailed(reason: String)

    /// Access token expired AND refresh was unavailable (e.g. refresh
    /// token revoked). Caller should route the user through `connect()`.
    case tokenRefreshRequired

    /// Any other broker error — HTTP 5xx, unexpected JSON shape, etc.
    /// `detail` is safe to log.
    case transportFailure(detail: String)

    var errorDescription: String? {
        switch self {
        case .sandboxUserNotAllowed:
            return "Your TikTok account isn't approved for our sandbox. Contact support to request access."
        case .uploadURLExpired:
            return "The upload URL expired. Please try publishing again."
        case .videoTooLarge(let bytes):
            let mb = Double(bytes) / 1_048_576
            return String(format: "Video is %.0f MB — TikTok's limit is 500 MB.", mb)
        case .videoDurationOutOfRange:
            return "TikTok videos must be between 15 seconds and 10 minutes."
        case .unsupportedVideoFormat:
            return "TikTok only accepts MP4 or MOV files."
        case .videoFileUnreadable:
            return "Couldn't read the video file. Make sure it hasn't been moved or deleted."
        case .publishFailed(let reason):
            return "TikTok couldn't publish this video: \(reason)"
        case .tokenRefreshRequired:
            return "Your TikTok connection needs to be refreshed. Please reconnect."
        case .transportFailure(let detail):
            return "TikTok request failed: \(detail)"
        }
    }
}
