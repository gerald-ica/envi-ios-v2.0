import Foundation

// MARK: - Metric Trend

enum MetricTrend: String, Codable {
    case up
    case down
    case neutral
}

// MARK: - Thread Metric

struct ThreadMetric: Identifiable, Codable {
    let id: UUID
    let label: String
    let value: String
    let change: String
    let trend: MetricTrend

    init(id: UUID = UUID(), label: String, value: String, change: String, trend: MetricTrend) {
        self.id = id
        self.label = label
        self.value = value
        self.change = change
        self.trend = trend
    }
}

// MARK: - Chat Thread

struct ChatThread: Identifiable, Codable {
    let id: UUID
    let question: String
    let paragraphs: [String]
    let metrics: [ThreadMetric]
    let relatedQuestions: [String]

    init(id: UUID = UUID(), question: String, paragraphs: [String], metrics: [ThreadMetric], relatedQuestions: [String]) {
        self.id = id
        self.question = question
        self.paragraphs = paragraphs
        self.metrics = metrics
        self.relatedQuestions = relatedQuestions
    }
}
