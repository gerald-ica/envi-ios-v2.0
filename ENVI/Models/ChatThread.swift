import Foundation

// MARK: - Metric Trend

enum MetricTrend {
    case up
    case down
    case neutral
}

// MARK: - Thread Metric

struct ThreadMetric: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let change: String
    let trend: MetricTrend
}

// MARK: - Chat Thread

struct ChatThread: Identifiable {
    let id = UUID()
    let question: String
    let paragraphs: [String]
    let metrics: [ThreadMetric]
    let relatedQuestions: [String]
}
