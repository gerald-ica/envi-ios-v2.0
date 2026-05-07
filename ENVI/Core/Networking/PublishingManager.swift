import Foundation

@MainActor
final class PublishingManager {
    static let shared = PublishingManager()

    private init() {}

    // Phase 12 — `publish/jobs` is now the real Firebase Callable dispatcher
    // (`functions/src/publish/dispatch.ts`). It creates a `publish_jobs/{jobId}`
    // Firestore doc and fans out one Pub/Sub message per selected platform
    // (topic `envi-publish-{platform}`). Per-platform workers drive the
    // state machine (queued → processing → posted|failed|dlq) and derive
    // the top-level job status. `.partial` is a new terminal state meaning
    // "some platforms posted, some failed" — `waitForFinalStatus` treats it
    // as terminal alongside `.posted` and `.failed`.

    enum PublishError: Error {
        case invalidTicket
        case timedOut
    }

    /// Starts a publish job across `platforms`.
    ///
    /// - Parameters:
    ///   - caption: User-authored caption. Never logged in telemetry.
    ///   - platforms: Platforms to fan out to. Each produces one Pub/Sub
    ///     message to `envi-publish-{apiSlug}`.
    ///   - mediaRefs: Cloud Storage object paths (e.g. `users/{uid}/media/clip.mp4`).
    ///     Workers download from these refs server-side — iOS never uploads
    ///     through this call. Empty array is legal for text-only posts
    ///     (threads/x/linkedin).
    ///   - scheduledAt: Optional future date. Absent or ≤30s away → immediate
    ///     fan-out; further future → `queued` in Firestore, cron fans out.
    func startPublish(
        caption: String,
        platforms: [SocialPlatform],
        mediaRefs: [String],
        scheduledAt: Date? = nil
    ) async throws -> PublishTicket {
        let response: PublishStartResponse = try await APIClient.shared.request(
            endpoint: "publish/jobs",
            method: .post,
            body: PublishStartRequest(
                caption: caption,
                platforms: platforms.map(\.apiSlug),
                mediaRefs: mediaRefs,
                scheduleAt: scheduledAt.map { Self.iso8601Formatter.string(from: $0) }
            ),
            requiresAuth: true
        )

        // Phase 12 telemetry — fire `publish_dispatch` once per job. Per-platform
        // success/failure events are emitted server-side by the workers.
        TelemetryManager.shared.track(.publishDispatch, parameters: [
            "job_id": response.jobID,
            "platforms": platforms.map(\.apiSlug).joined(separator: ","),
            "platform_count": platforms.count,
            "scheduled": scheduledAt != nil
        ])
        // Preserve Phase <=11 emit for downstream consumers (analytics dashboards).
        TelemetryManager.shared.trackPublish(
            .publishStarted,
            jobID: response.jobID,
            platforms: platforms.map(\.rawValue)
        )

        return PublishTicket(jobID: response.jobID, status: response.status)
    }

    func waitForFinalStatus(jobID: String, maxAttempts: Int = 6) async throws -> PublishStatus {
        for _ in 0..<maxAttempts {
            let response: PublishStatusResponse = try await APIClient.shared.request(
                endpoint: "publish/jobs/\(jobID)",
                method: .get,
                requiresAuth: true
            )

            // `.partial` is terminal — some platforms posted, others DLQ'd.
            // UI surfaces per-platform rows in ExportSheet follow-up.
            if response.status == .posted
                || response.status == .failed
                || response.status == .partial {
                return response.status
            }

            try await Task.sleep(for: .seconds(2))
        }

        throw PublishError.timedOut
    }

    /// Read the per-platform breakdown without polling. Used by
    /// ConnectedAccountsView / ExportSheet retry affordances.
    func fetchStatus(jobID: String) async throws -> PublishStatusResponse {
        return try await APIClient.shared.request(
            endpoint: "publish/jobs/\(jobID)",
            method: .get,
            requiresAuth: true
        )
    }

    nonisolated(unsafe) private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

struct PublishTicket {
    let jobID: String
    let status: PublishStatus
}

enum PublishStatus: String, Decodable {
    case queued
    case processing
    case posted
    /// Phase 12: some platforms posted, at least one DLQ'd or failed.
    /// Terminal — `waitForFinalStatus` returns it and the UI shows a
    /// per-platform breakdown.
    case partial
    case failed
}

/// Per-platform status within a publish job. Mirrors the Firestore
/// `publish_jobs/{jobId}.platforms[platform]` schema 1:1 (sans timestamps).
struct ProviderPublishStatus: Decodable {
    let status: String          // queued|processing|posted|failed|dlq
    let providerPostId: String?
    /// Sanitized error code: `rate_limited`, `media_rejected`, `auth_expired`,
    /// `unknown`. Raw provider bodies never cross the client boundary.
    let error: String?
    let attempts: Int
}

struct PublishStartRequest: Encodable {
    let caption: String
    let platforms: [String]
    let mediaRefs: [String]
    let scheduleAt: String?
}

struct PublishStartResponse: Decodable {
    let jobID: String
    let status: PublishStatus
}

struct PublishStatusResponse: Decodable {
    let status: PublishStatus
    /// Phase 12: per-platform breakdown keyed by apiSlug. Optional so
    /// decoding stays lenient against older broker deployments.
    let platformStatuses: [String: ProviderPublishStatus]?
}
