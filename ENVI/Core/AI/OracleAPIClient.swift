import Foundation

final class OracleAPIClient {
    static let shared = OracleAPIClient()

    private init() {}

    func fetchThread(query: String) async throws -> ChatThread {
        let response: OracleThreadResponse = try await APIClient.shared.request(
            endpoint: "oracle/chat",
            method: .post,
            body: OracleThreadRequest(query: query),
            requiresAuth: true
        )

        return ChatThread(
            question: query,
            paragraphs: response.paragraphs,
            metrics: response.metrics.map {
                ThreadMetric(
                    label: $0.label,
                    value: $0.value,
                    change: $0.change,
                    trend: mapTrend($0.trend)
                )
            },
            relatedQuestions: response.relatedQuestions
        )
    }

    private func mapTrend(_ trend: String) -> ChatMetricTrend {
        switch trend.lowercased() {
        case "up":
            return .up
        case "down":
            return .down
        default:
            return .neutral
        }
    }
}

private struct OracleThreadRequest: Encodable {
    let query: String
}

private struct OracleThreadResponse: Decodable {
    let paragraphs: [String]
    let metrics: [OracleMetric]
    let relatedQuestions: [String]
}

private struct OracleMetric: Decodable {
    let label: String
    let value: String
    let change: String
    let trend: String
}
