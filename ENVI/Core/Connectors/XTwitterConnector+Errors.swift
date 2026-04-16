//
//  XTwitterConnector+Errors.swift
//  ENVI
//
//  Phase 09 — X (Twitter) Connector.
//
//  Error surface for the X connector. These errors are what the UI branches
//  on; the networking layer (APIClient) surfaces raw HTTP failures, but
//  `XTwitterConnector` translates those into `XConnectorError` cases that
//  map cleanly to user-visible copy and PublishStatus handling.
//
//  Design notes
//  ------------
//  - `rateLimited(retryAfter:)` carries an absolute `Date` (not a duration).
//    The Cloud Function returns the `x-rate-limit-reset` unix timestamp
//    already parsed into ISO-8601; the iOS layer decodes it directly. UI
//    shows "Retry after HH:MM" in the user's local timezone — the Date
//    carries its own instant, the formatter handles TZ conversion.
//  - `mediaProcessingFailed(reason:)` carries the raw reason string from
//    the FINALIZE → STATUS poll loop (e.g. "InvalidMediaType",
//    "FileValidationFailed"). We surface it raw in Debug, map to friendly
//    copy in the UI layer in Release.
//  - Every case conforms to `LocalizedError` so a plain `.localizedDescription`
//    read in UI gets a reasonable string without a custom translation table.
//

import Foundation

enum XConnectorError: Error, LocalizedError, Equatable {

    /// Rate-limit ceiling hit. `retryAfter` is an absolute moment — the
    /// earliest time the next call is expected to succeed.
    case rateLimited(retryAfter: Date)

    /// Chunked media upload's STATUS poll returned `state: "failed"` or the
    /// terminal poll timed out. `reason` is the raw provider string.
    case mediaProcessingFailed(reason: String)

    /// Local file exceeded the v2 MP4 cap (512 MB). Validated iOS-side
    /// before the INIT round-trip so we don't burn a Cloud Function call
    /// on a doomed upload.
    case mediaTooLarge

    /// Video duration outside the allowed range for the chosen
    /// `media_category`. `tweet_video` ≤ 140s, `amplify_video` > 140s (and
    /// up to 10 min on Basic tier, subject to eligibility).
    case mediaDurationOutOfRange(seconds: Double)

    /// File extension / container not supported. v2 accepts mp4 + mov for
    /// video; png/jpg/gif/webp for images.
    case unsupportedMediaType(extension: String)

    /// OAuth connection missing or expired. UI routes this back into the
    /// connect flow (`SocialOAuthManager.connect(platform: .x)`).
    case notConnected

    /// Provider refused the tweet (duplicate, length overrun, policy
    /// violation). `reason` echoes the `detail` field from the Cloud
    /// Function envelope.
    case tweetRejected(reason: String)

    /// Catch-all for anything else the server surfaces (5xx, transient
    /// network). UI should present as "Something went wrong — try again".
    case transport(underlying: String)

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case .rateLimited(let date):
            let fmt = DateFormatter()
            fmt.dateStyle = .none
            fmt.timeStyle = .short
            return "X rate limit reached — retry after \(fmt.string(from: date))."
        case .mediaProcessingFailed(let reason):
            return "X could not process the media: \(reason)."
        case .mediaTooLarge:
            return "Video exceeds the 512 MB limit for X."
        case .mediaDurationOutOfRange(let seconds):
            return "Video duration (\(Int(seconds))s) is outside X's allowed range."
        case .unsupportedMediaType(let ext):
            return "X does not accept .\(ext) — use MP4 or a supported image format."
        case .notConnected:
            return "Connect your X account before posting."
        case .tweetRejected(let reason):
            return "X rejected the tweet: \(reason)."
        case .transport(let underlying):
            return "Network error talking to X: \(underlying)."
        }
    }

    // MARK: - Equatable

    /// Custom equality so tests can assert specific cases without matching
    /// wall-clock timestamps or underlying-error identity.
    static func == (lhs: XConnectorError, rhs: XConnectorError) -> Bool {
        switch (lhs, rhs) {
        case (.rateLimited(let a), .rateLimited(let b)):
            // Equal to the nearest second — avoids flakiness from
            // sub-second clock drift in tests.
            return Int(a.timeIntervalSince1970) == Int(b.timeIntervalSince1970)
        case (.mediaProcessingFailed(let a), .mediaProcessingFailed(let b)):
            return a == b
        case (.mediaTooLarge, .mediaTooLarge):
            return true
        case (.mediaDurationOutOfRange(let a), .mediaDurationOutOfRange(let b)):
            return a == b
        case (.unsupportedMediaType(let a), .unsupportedMediaType(let b)):
            return a == b
        case (.notConnected, .notConnected):
            return true
        case (.tweetRejected(let a), .tweetRejected(let b)):
            return a == b
        case (.transport(let a), .transport(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - Cloud Function Error Envelope

/// Envelope every Cloud Function route in `/connectors/x/*` returns on a
/// non-2xx response. `code` is the machine-readable slug; `retryAfter`
/// and `detail` populate depending on the code.
///
/// Canonical codes surfaced by `functions/src/providers/x.rate-limit.ts`
/// and `x.ts`:
///   - `"rate_limited"`        — also sets `retryAfter` (ISO-8601)
///   - `"media_processing"`    — also sets `detail` (raw provider reason)
///   - `"not_connected"`
///   - `"tweet_rejected"`      — also sets `detail`
///   - `"media_too_large"`, `"media_unsupported"`, `"media_duration"`
///
/// Decoding is permissive: unknown codes collapse to `.transport` in the
/// translator below. Keeps additive server changes forward-compatible.
struct XConnectorErrorEnvelope: Decodable {
    let error: String
    let retryAfter: Date?
    let detail: String?

    private enum CodingKeys: String, CodingKey {
        case error
        case retryAfter
        case detail
    }
}

extension XConnectorError {

    /// Translate a Cloud Function error envelope + decoded body to a typed
    /// error. Falls back to `.transport` for unrecognized codes so the UI
    /// never lands in "Optional<Error>?? nil" territory.
    static func from(envelope: XConnectorErrorEnvelope) -> XConnectorError {
        switch envelope.error {
        case "rate_limited":
            if let date = envelope.retryAfter {
                return .rateLimited(retryAfter: date)
            }
            // Degrade gracefully: if the server omitted retryAfter treat
            // as a generic transport error so the UI retry copy doesn't
            // collapse into "Retry after —".
            return .transport(underlying: "rate_limited (no retryAfter)")
        case "media_processing":
            return .mediaProcessingFailed(reason: envelope.detail ?? "unknown")
        case "media_too_large":
            return .mediaTooLarge
        case "media_unsupported":
            return .unsupportedMediaType(extension: envelope.detail ?? "")
        case "media_duration":
            let seconds = Double(envelope.detail ?? "") ?? 0
            return .mediaDurationOutOfRange(seconds: seconds)
        case "not_connected":
            return .notConnected
        case "tweet_rejected":
            return .tweetRejected(reason: envelope.detail ?? "policy")
        default:
            return .transport(underlying: envelope.error)
        }
    }
}
