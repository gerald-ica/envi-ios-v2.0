//
//  XTwitterConnector+Models.swift
//  ENVI
//
//  Phase 09 — X (Twitter) Connector.
//
//  Value types shuttled between the iOS adapter and the Cloud Function
//  routes at `/connectors/x/*`. Kept Codable + Equatable for easy test
//  fixtures and snapshot-style assertions.
//
//  Wire-format notes
//  -----------------
//  Cloud Function routes emit camelCase JSON (translated from X's
//  mixed case at the server boundary — see
//  `functions/src/providers/x.ts#toAccountResponse`). No custom coding
//  keys needed here.
//

import Foundation

// MARK: - Account

/// The X account metadata ENVI surfaces in `PlatformConnection` and in
/// account-picker UI. Derived from `GET https://api.x.com/2/users/me`
/// with `user.fields=username,name,public_metrics,profile_image_url` —
/// `public_metrics.followers_count` is unwrapped server-side into a flat
/// `followerCount`.
struct XAccount: Codable, Equatable {
    /// Stable provider user id (snowflake id string form). Used as
    /// `providerUserId` in the Firestore connection doc.
    let id: String

    /// `@handle` without the leading `@`.
    let username: String

    /// Display name (may contain unicode, emoji).
    let name: String

    /// Follower count at the time of last refresh. The value can lag the
    /// live count by up to 5 minutes depending on X's caching.
    let followerCount: Int

    /// Profile picture URL. Nullable because X accounts can omit one.
    let profileImageURL: URL?
}

// MARK: - Tweet create

/// Cloud Function response for `POST /connectors/x/tweet`. Mirrors the
/// `data` sub-object X returns from `POST /2/tweets`.
struct XTweetResponse: Codable, Equatable {
    /// Tweet id — monotonic snowflake id as a string. Stringified because
    /// JS-client parity with X's docs matters, and we never do arithmetic
    /// on it.
    let id: String

    /// The text as X stored it (X sometimes normalises whitespace and
    /// adds t.co link wrapping — we echo back exactly what the API said).
    let text: String
}

/// Client-side request body for `POST /connectors/x/tweet`. The server
/// translates this to X's native shape (`{ text, media: { media_ids: [] },
/// reply: { in_reply_to_tweet_id } }`) inside `x.ts`.
struct XTweetCreateRequest: Codable, Equatable {
    /// Raw tweet text. Caller is responsible for length validation
    /// (Basic tier = 280 chars; iOS editor caps at 280 already).
    let text: String

    /// Optional media id returned from a prior `/connectors/x/media` call.
    /// One media attachment per tweet in Phase 9; multi-media is Phase 12
    /// material.
    let mediaID: String?

    /// When present, posts the tweet as a reply. iOS only populates this
    /// for quote/reply flows (not in Phase 9 scope, but wired for Phase
    /// 11's conversation connector).
    let replyToID: String?
}

// MARK: - Media upload

/// Ticket issued by `POST /connectors/x/media` after the Cloud Function
/// completes the full INIT/APPEND/FINALIZE/STATUS chain. Used as input to
/// `XTweetCreateRequest.mediaID`.
///
/// Named "Ticket" (vs. bare `String`) because we carry extra diagnostic
/// state — `mediaKey`, `expiresAfterSecs` — the retry/cleanup layer
/// needs if a tweet-create call subsequently fails and we want to
/// re-attach the same media without re-uploading.
struct XMediaUploadTicket: Codable, Equatable {
    /// X media id — what we send in `media_ids`.
    let mediaID: String

    /// Opaque, stable key X issues alongside the numeric id. Unused in
    /// Phase 9 but preserved in the Firestore `publish_jobs` record for
    /// future multi-attachment workflows.
    let mediaKey: String?

    /// Seconds from issue time until X considers the media id stale and
    /// rejects tweet-create calls with it. Currently 24 h; cache-aware
    /// caller uses this to decide whether to re-upload.
    let expiresAfterSecs: Int?
}

/// iOS-side request body for `POST /connectors/x/media`. iOS stages the
/// file via signed URL (Phase 7 pattern) and hands the reference back to
/// the Cloud Function, which performs the chunked upload server-side.
struct XMediaUploadRequest: Codable, Equatable {
    /// Storage path to the staged media (Cloud Storage bucket + object
    /// name), OR a Firebase download URL. The Cloud Function streams from
    /// this source into X's APPEND chunks.
    let storagePath: String

    /// MIME type. Used to pick `media_category` and to validate against
    /// the extension-allowlist.
    let mimeType: String

    /// Total size in bytes. Used for X INIT + iOS-side validation.
    let totalBytes: Int

    /// Video duration in seconds (0 for images). Used iOS-side to choose
    /// `tweet_video` vs `amplify_video`.
    let durationSeconds: Double
}

// MARK: - Publish ticket

/// Phase 9 mirrors `PublishingManager.PublishTicket` but directly for
/// the X direct-path flow (pre-Phase-12 fan-out). Kept separate so we can
/// evolve independently until Phase 12 merges both ticket types.
///
/// Maps:
///   - `XTweetResponse.id` → `jobID`
///   - `PublishStatus.posted` on success
struct XPublishTicket: Equatable {
    let jobID: String
    let tweetID: String
    let status: PublishStatus
    let issuedAt: Date

    init(
        jobID: String,
        tweetID: String,
        status: PublishStatus,
        issuedAt: Date = Date()
    ) {
        self.jobID = jobID
        self.tweetID = tweetID
        self.status = status
        self.issuedAt = issuedAt
    }
}

// MARK: - Constraints

/// Media constraints enforced iOS-side BEFORE any Cloud Function
/// round-trip. Kept here (rather than inside `XTwitterConnector`) so the
/// ComposeView can surface validation errors in-line while the user is
/// still picking media — no "try again" round-trip.
enum XMediaConstraints {
    /// Hard ceiling from X docs for v2 chunked upload.
    static let maxVideoBytes: Int = 512 * 1024 * 1024

    /// `tweet_video` upper bound. Above this the category switches to
    /// `amplify_video`, which requires eligibility (see PLAN decision 4).
    static let tweetVideoMaxSeconds: Double = 140.0

    /// Lower bound for any video tweet — shorter videos are rejected
    /// outright by X's ingestion pipeline.
    static let videoMinSeconds: Double = 0.5

    /// Extensions accepted by v2 chunked upload as of 2026-04. Anything
    /// else returns `.unsupportedMediaType` without hitting the network.
    static let supportedVideoExtensions: Set<String> = ["mp4", "mov"]
    static let supportedImageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp",
    ]

    /// Decide the `media_category` based on duration. Images skip INIT
    /// entirely and hit the single-shot image endpoint — caller detects
    /// this via `mimeType` before calling.
    static func videoCategory(for durationSeconds: Double) -> String {
        return durationSeconds > tweetVideoMaxSeconds
            ? "amplify_video" : "tweet_video"
    }
}
