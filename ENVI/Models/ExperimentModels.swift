import Foundation

// MARK: - Experiment Status

enum ExperimentStatus: String, Codable, CaseIterable, Identifiable {
    case draft
    case running
    case completed
    case cancelled

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    var iconName: String {
        switch self {
        case .draft:     return "doc"
        case .running:   return "play.fill"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle"
        }
    }
}

// MARK: - Variant Metrics

struct VariantMetrics: Codable {
    var impressions: Int
    var engagement: Int
    var clickRate: Double
    var conversionRate: Double

    init(
        impressions: Int = 0,
        engagement: Int = 0,
        clickRate: Double = 0,
        conversionRate: Double = 0
    ) {
        self.impressions = impressions
        self.engagement = engagement
        self.clickRate = clickRate
        self.conversionRate = conversionRate
    }

    /// Formatted click rate as percentage string.
    var formattedClickRate: String {
        String(format: "%.1f%%", clickRate * 100)
    }

    /// Formatted conversion rate as percentage string.
    var formattedConversionRate: String {
        String(format: "%.1f%%", conversionRate * 100)
    }

    static let empty = VariantMetrics()
}

// MARK: - Experiment Variant

struct ExperimentVariant: Identifiable, Codable {
    let id: UUID
    var name: String
    var caption: String
    var mediaAssetID: String?
    var platform: SocialPlatform
    var metrics: VariantMetrics

    init(
        id: UUID = UUID(),
        name: String,
        caption: String = "",
        mediaAssetID: String? = nil,
        platform: SocialPlatform = .instagram,
        metrics: VariantMetrics = .empty
    ) {
        self.id = id
        self.name = name
        self.caption = caption
        self.mediaAssetID = mediaAssetID
        self.platform = platform
        self.metrics = metrics
    }
}

// MARK: - Experiment

struct Experiment: Identifiable, Codable {
    let id: UUID
    var name: String
    var hypothesis: String
    var variants: [ExperimentVariant]
    var status: ExperimentStatus
    var startDate: Date
    var endDate: Date
    var winningVariant: UUID?

    init(
        id: UUID = UUID(),
        name: String,
        hypothesis: String = "",
        variants: [ExperimentVariant] = [],
        status: ExperimentStatus = .draft,
        startDate: Date = Date(),
        endDate: Date = Date().addingTimeInterval(14 * 86400),
        winningVariant: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.hypothesis = hypothesis
        self.variants = variants
        self.status = status
        self.startDate = startDate
        self.endDate = endDate
        self.winningVariant = winningVariant
    }

    /// Days remaining until end date.
    var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0
    }

    /// Duration in days from start to end.
    var durationDays: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }

    /// Date range formatted as a compact string.
    var dateRangeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }

    // MARK: - Mock Data

    static let variantA = ExperimentVariant(
        name: "Variant A",
        caption: "Unlock your creative potential with ENVI",
        platform: .instagram,
        metrics: VariantMetrics(impressions: 12400, engagement: 980, clickRate: 0.034, conversionRate: 0.021)
    )

    static let variantB = ExperimentVariant(
        name: "Variant B",
        caption: "Create content that stands out",
        platform: .instagram,
        metrics: VariantMetrics(impressions: 12600, engagement: 1240, clickRate: 0.042, conversionRate: 0.029)
    )

    static let mock = Experiment(
        name: "CTA Copy Test",
        hypothesis: "A more aspirational caption will increase engagement rate by 15%",
        variants: [variantA, variantB],
        status: .completed,
        startDate: Date().addingTimeInterval(-14 * 86400),
        endDate: Date().addingTimeInterval(-1 * 86400),
        winningVariant: variantB.id
    )

    static let mockList: [Experiment] = [
        .mock,
        Experiment(
            name: "Thumbnail Style Test",
            hypothesis: "Bold text overlays will outperform clean visuals on TikTok",
            variants: [
                ExperimentVariant(name: "Variant A", caption: "Clean visual", platform: .tiktok,
                                  metrics: VariantMetrics(impressions: 8200, engagement: 640, clickRate: 0.028, conversionRate: 0.015)),
                ExperimentVariant(name: "Variant B", caption: "Bold text overlay", platform: .tiktok,
                                  metrics: VariantMetrics(impressions: 8400, engagement: 890, clickRate: 0.039, conversionRate: 0.022)),
            ],
            status: .running,
            startDate: Date().addingTimeInterval(-5 * 86400),
            endDate: Date().addingTimeInterval(9 * 86400)
        ),
        Experiment(
            name: "Posting Time Test",
            hypothesis: "Evening posts (7-9 PM) will generate 20% more impressions than morning posts",
            variants: [
                ExperimentVariant(name: "Morning", caption: "Posted at 8 AM", platform: .instagram),
                ExperimentVariant(name: "Evening", caption: "Posted at 8 PM", platform: .instagram),
            ],
            status: .draft,
            startDate: Date().addingTimeInterval(3 * 86400),
            endDate: Date().addingTimeInterval(17 * 86400)
        ),
    ]
}

// MARK: - A/B Test Result

struct ABTestResult: Codable {
    let experimentID: UUID
    let winner: UUID
    let confidence: Double
    let improvement: Double
    let recommendation: String

    /// Formatted confidence as percentage string.
    var formattedConfidence: String {
        String(format: "%.0f%%", confidence * 100)
    }

    /// Formatted improvement as percentage string.
    var formattedImprovement: String {
        let sign = improvement >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f%%", improvement * 100))"
    }

    static let mock = ABTestResult(
        experimentID: Experiment.mock.id,
        winner: Experiment.variantB.id,
        confidence: 0.94,
        improvement: 0.38,
        recommendation: "Variant B significantly outperformed Variant A in engagement and conversion. Consider adopting the aspirational copy style across future campaigns."
    )
}
