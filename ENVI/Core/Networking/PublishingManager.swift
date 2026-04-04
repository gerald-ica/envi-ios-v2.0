import Foundation

final class PublishingManager {
    static let shared = PublishingManager()

    private init() {}

    enum PublishError: Error {
        case invalidTicket
        case timedOut
    }

    func startPublish(
        caption: String,
        platforms: [SocialPlatform]
    ) async throws -> PublishTicket {
        let response: PublishStartResponse = try await APIClient.shared.request(
            endpoint: "publish/jobs",
            method: .post,
            body: PublishStartRequest(
                caption: caption,
                platforms: platforms.map(\.rawValue)
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
}

private struct PublishStartResponse: Decodable {
    let jobID: String
    let status: PublishStatus
}

private struct PublishStatusResponse: Decodable {
    let status: PublishStatus
}
