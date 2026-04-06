import Foundation

// MARK: - Event Schema

/// Schema definition for analytics events (ENVI-0961..0965).
struct EventSchema: Identifiable {
    let id: UUID
    let name: String
    let version: Int
    let fields: [String]

    init(
        id: UUID = UUID(),
        name: String,
        version: Int,
        fields: [String]
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.fields = fields
    }
}

// MARK: - ML Model Status

/// Lifecycle status for ML models.
enum MLModelStatus: String, CaseIterable, Codable, Identifiable {
    case training
    case deployed
    case deprecated
    case failed

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    var iconName: String {
        switch self {
        case .training:   return "arrow.triangle.2.circlepath"
        case .deployed:   return "checkmark.seal.fill"
        case .deprecated: return "archivebox"
        case .failed:     return "xmark.octagon"
        }
    }
}

// MARK: - ML Model

/// A machine-learning model tracked in the platform (ENVI-0966..0970).
struct MLModel: Identifiable {
    let id: UUID
    let name: String
    let version: String
    let accuracy: Double
    let lastTrained: Date
    let status: MLModelStatus

    init(
        id: UUID = UUID(),
        name: String,
        version: String,
        accuracy: Double,
        lastTrained: Date = Date(),
        status: MLModelStatus
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.accuracy = accuracy
        self.lastTrained = lastTrained
        self.status = status
    }

    /// Formatted accuracy percentage string.
    var formattedAccuracy: String {
        String(format: "%.1f%%", accuracy * 100)
    }
}

// MARK: - Evaluation Result

/// Result of an ML model evaluation run (ENVI-0971..0973).
struct EvaluationResult: Identifiable {
    let id: UUID
    let modelID: String
    let metric: String
    let score: Double
    let threshold: Double
    let passed: Bool

    init(
        id: UUID = UUID(),
        modelID: String,
        metric: String,
        score: Double,
        threshold: Double,
        passed: Bool
    ) {
        self.id = id
        self.modelID = modelID
        self.metric = metric
        self.score = score
        self.threshold = threshold
        self.passed = passed
    }

    /// Formatted score string.
    var formattedScore: String {
        String(format: "%.3f", score)
    }
}

// MARK: - Prompt Template

/// A versioned prompt template with evaluation scoring (ENVI-0974).
struct PromptTemplate: Identifiable {
    let id: UUID
    let name: String
    let template: String
    let version: Int
    let evaluationScore: Double

    init(
        id: UUID = UUID(),
        name: String,
        template: String,
        version: Int,
        evaluationScore: Double
    ) {
        self.id = id
        self.name = name
        self.template = template
        self.version = version
        self.evaluationScore = evaluationScore
    }

    /// Formatted evaluation score string.
    var formattedScore: String {
        String(format: "%.1f%%", evaluationScore * 100)
    }
}

// MARK: - Data Quality Check Status

/// Status of a data quality check run.
enum DataQualityStatus: String, CaseIterable, Codable, Identifiable {
    case passed
    case warning
    case failed
    case pending

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    var iconName: String {
        switch self {
        case .passed:  return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .failed:  return "xmark.circle.fill"
        case .pending: return "clock.fill"
        }
    }
}

// MARK: - Data Quality Check

/// A data quality validation rule and its last run result (ENVI-0975).
struct DataQualityCheck: Identifiable {
    let id: UUID
    let table: String
    let checkType: String
    let status: DataQualityStatus
    let lastRun: Date

    init(
        id: UUID = UUID(),
        table: String,
        checkType: String,
        status: DataQualityStatus,
        lastRun: Date = Date()
    ) {
        self.id = id
        self.table = table
        self.checkType = checkType
        self.status = status
        self.lastRun = lastRun
    }
}

// MARK: - Mock Data

extension EventSchema {
    static let mock: [EventSchema] = [
        EventSchema(name: "post_created", version: 3, fields: ["user_id", "content_type", "platform", "timestamp"]),
        EventSchema(name: "engagement_received", version: 2, fields: ["post_id", "type", "source_user_id", "timestamp"]),
        EventSchema(name: "session_started", version: 1, fields: ["user_id", "device", "app_version", "timestamp"]),
        EventSchema(name: "payment_completed", version: 2, fields: ["user_id", "amount", "product_id", "currency"]),
    ]
}

extension MLModel {
    static let mock: [MLModel] = [
        MLModel(name: "Caption Generator", version: "2.4.1", accuracy: 0.924, lastTrained: Date().addingTimeInterval(-86400), status: .deployed),
        MLModel(name: "Content Classifier", version: "1.8.0", accuracy: 0.891, lastTrained: Date().addingTimeInterval(-172800), status: .deployed),
        MLModel(name: "Engagement Predictor", version: "3.1.0", accuracy: 0.856, lastTrained: Date().addingTimeInterval(-3600), status: .training),
        MLModel(name: "Spam Detector", version: "1.2.0", accuracy: 0.978, lastTrained: Date().addingTimeInterval(-604800), status: .deployed),
        MLModel(name: "Trend Analyzer", version: "0.9.0", accuracy: 0.743, lastTrained: Date().addingTimeInterval(-259200), status: .deprecated),
    ]
}

extension EvaluationResult {
    static let mock: [EvaluationResult] = [
        EvaluationResult(modelID: "caption_gen", metric: "BLEU", score: 0.847, threshold: 0.80, passed: true),
        EvaluationResult(modelID: "caption_gen", metric: "ROUGE-L", score: 0.912, threshold: 0.85, passed: true),
        EvaluationResult(modelID: "content_cls", metric: "F1", score: 0.891, threshold: 0.90, passed: false),
        EvaluationResult(modelID: "spam_det", metric: "Precision", score: 0.982, threshold: 0.95, passed: true),
        EvaluationResult(modelID: "spam_det", metric: "Recall", score: 0.964, threshold: 0.95, passed: true),
    ]
}

extension PromptTemplate {
    static let mock: [PromptTemplate] = [
        PromptTemplate(name: "Caption - Casual", template: "Write a casual social media caption for: {topic}", version: 5, evaluationScore: 0.88),
        PromptTemplate(name: "Caption - Professional", template: "Write a professional caption about: {topic}", version: 3, evaluationScore: 0.92),
        PromptTemplate(name: "Hashtag Suggestion", template: "Suggest 10 relevant hashtags for: {content}", version: 2, evaluationScore: 0.79),
        PromptTemplate(name: "Content Summary", template: "Summarize this content in 2 sentences: {content}", version: 4, evaluationScore: 0.85),
    ]
}

extension DataQualityCheck {
    static let mock: [DataQualityCheck] = [
        DataQualityCheck(table: "events.post_created", checkType: "Not Null", status: .passed, lastRun: Date().addingTimeInterval(-1800)),
        DataQualityCheck(table: "events.post_created", checkType: "Unique", status: .passed, lastRun: Date().addingTimeInterval(-1800)),
        DataQualityCheck(table: "users.profiles", checkType: "Referential Integrity", status: .warning, lastRun: Date().addingTimeInterval(-3600)),
        DataQualityCheck(table: "analytics.sessions", checkType: "Freshness", status: .failed, lastRun: Date().addingTimeInterval(-7200)),
        DataQualityCheck(table: "payments.transactions", checkType: "Row Count", status: .passed, lastRun: Date().addingTimeInterval(-900)),
    ]
}
