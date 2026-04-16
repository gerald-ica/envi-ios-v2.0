import Foundation

final class PublishingManager {
    static let shared = PublishingManager()

    private init() {}

    // TODO(phase-12): route publishes through the per-platform connector
    // dispatcher instead of the generic `/publish/jobs` endpoint. Today
    // Phase 08's TikTokConnector writes directly to
    // `connectors/tiktok/publish/*` and observes Firestore; Phase 12 will
    // introduce a shared state machine (queued → uploading → awaiting →
    // posted|failed) that unifies the read path with this manager's
    // `waitForFinalStatus` contract.

    enum PublishError: Error {
        case invalidTicket
        case timedOut
    }

    func startPublish(
        caption: String,
        platforms: [SocialPlatform],
        scheduledAt: Date? = nil
    ) async throws -> PublishTicket {
        TelemetryManager.shared.trackPublish(
            .publishStarted,
            jobID: "",
            platforms: platforms.map(\.rawValue)
        )
        let response: PublishStartResponse = try await APIClient.shared.request(
            endpoint: "publish/jobs",
            method: .post,
            body: PublishStartRequest(
                caption: caption,
                platforms: platforms.map(\.rawValue),
                scheduleAt: scheduledAt.map { Self.iso8601Formatter.string(from: $0) }
            ),
            requiresAuth: true
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

            if response.status == .posted || response.status == .failed {
                return response.status
            }

            try await Task.sleep(for: .seconds(2))
        }

        throw PublishError.timedOut
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
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
    case failed
}

private struct PublishStartRequest: Encodable {
    let caption: String
    let platforms: [String]
    let scheduleAt: String?
}

private struct PublishStartResponse: Decodable {
    let jobID: String
    let status: PublishStatus
}

private struct PublishStatusResponse: Decodable {
    let status: PublishStatus
}
