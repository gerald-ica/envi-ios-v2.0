import Foundation

// MARK: - Tag Category

/// Categories for content tags spanning the full ENVI taxonomy (ENVI-0151 .. ENVI-0175).
enum TagCategory: String, Codable, CaseIterable, Identifiable {
    case custom
    case campaign
    case persona
    case funnel
    case product
    case pillar
    case hook
    case cta
    case tone
    case visual
    case brand
    case licensing
    case collaborator
    case location
    case season
    case trend
    case performance

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    /// Hex color used for color-coded tag chips.
    var chipColorHex: String {
        switch self {
        case .custom:       return "#6B7280"
        case .campaign:     return "#3B82F6"
        case .persona:      return "#8B5CF6"
        case .funnel:       return "#EC4899"
        case .product:      return "#F59E0B"
        case .pillar:       return "#10B981"
        case .hook:         return "#EF4444"
        case .cta:          return "#F97316"
        case .tone:         return "#14B8A6"
        case .visual:       return "#6366F1"
        case .brand:        return "#000000"
        case .licensing:    return "#78716C"
        case .collaborator: return "#0EA5E9"
        case .location:     return "#22C55E"
        case .season:       return "#A855F7"
        case .trend:        return "#E11D48"
        case .performance:  return "#2563EB"
        }
    }
}

// MARK: - Tag

struct Tag: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var category: TagCategory
    var color: String
    var usageCount: Int

    init(
        id: UUID = UUID(),
        name: String,
        category: TagCategory = .custom,
        color: String? = nil,
        usageCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.color = color ?? category.chipColorHex
        self.usageCount = usageCount
    }

    static let mockList: [Tag] = [
        Tag(name: "Summer Launch", category: .campaign, usageCount: 34),
        Tag(name: "Gen Z", category: .persona, usageCount: 21),
        Tag(name: "Awareness", category: .funnel, usageCount: 18),
        Tag(name: "Pro Plan", category: .product, usageCount: 12),
        Tag(name: "Education", category: .pillar, usageCount: 45),
        Tag(name: "Question Hook", category: .hook, usageCount: 27),
        Tag(name: "Link in Bio", category: .cta, usageCount: 39),
        Tag(name: "Conversational", category: .tone, usageCount: 15),
        Tag(name: "Flat Lay", category: .visual, usageCount: 9),
        Tag(name: "ENVI", category: .brand, usageCount: 60),
        Tag(name: "Royalty Free", category: .licensing, usageCount: 5),
        Tag(name: "@designstudio", category: .collaborator, usageCount: 7),
        Tag(name: "NYC", category: .location, usageCount: 22),
        Tag(name: "Winter", category: .season, usageCount: 14),
        Tag(name: "AI Content", category: .trend, usageCount: 31),
        Tag(name: "High CTR", category: .performance, usageCount: 19),
        Tag(name: "Behind the Scenes", category: .custom, usageCount: 42),
    ]
}

// MARK: - Tag Suggestion

/// Represents an AI-generated tag suggestion with confidence scoring.
struct TagSuggestion: Identifiable, Codable {
    let id: UUID
    let tag: Tag
    let confidence: Double // 0.0 ... 1.0
    let source: SuggestionSource

    init(
        id: UUID = UUID(),
        tag: Tag,
        confidence: Double,
        source: SuggestionSource = .ai
    ) {
        self.id = id
        self.tag = tag
        self.confidence = min(max(confidence, 0), 1)
        self.source = source
    }

    enum SuggestionSource: String, Codable {
        case ai
        case trending
        case history
        case similar
    }

    var confidencePercent: Int {
        Int(confidence * 100)
    }

    static let mockList: [TagSuggestion] = [
        TagSuggestion(tag: Tag(name: "Tutorial", category: .pillar), confidence: 0.94, source: .ai),
        TagSuggestion(tag: Tag(name: "Product Demo", category: .funnel), confidence: 0.87, source: .ai),
        TagSuggestion(tag: Tag(name: "Summer Vibes", category: .season), confidence: 0.72, source: .trending),
        TagSuggestion(tag: Tag(name: "Bold Tone", category: .tone), confidence: 0.68, source: .ai),
        TagSuggestion(tag: Tag(name: "Swipe CTA", category: .cta), confidence: 0.61, source: .history),
    ]
}

// MARK: - Content Metadata

/// Full metadata record for a single content asset.
struct ContentMetadata: Identifiable, Codable {
    var id: UUID { assetID }
    let assetID: UUID
    var tags: [Tag]
    var completenessScore: Double // 0.0 ... 1.0
    var embeddings: [Double]?

    init(
        assetID: UUID = UUID(),
        tags: [Tag] = [],
        completenessScore: Double = 0,
        embeddings: [Double]? = nil
    ) {
        self.assetID = assetID
        self.tags = tags
        self.completenessScore = min(max(completenessScore, 0), 1)
        self.embeddings = embeddings
    }

    var completenessPercent: Int {
        Int(completenessScore * 100)
    }

    /// Fields considered incomplete for the completeness gauge.
    var missingFields: [String] {
        var missing: [String] = []
        let categories = Set(tags.map(\.category))
        if !categories.contains(.campaign)     { missing.append("Campaign") }
        if !categories.contains(.persona)      { missing.append("Persona") }
        if !categories.contains(.funnel)       { missing.append("Funnel Stage") }
        if !categories.contains(.pillar)       { missing.append("Content Pillar") }
        if !categories.contains(.hook)         { missing.append("Hook Type") }
        if !categories.contains(.cta)          { missing.append("CTA") }
        if !categories.contains(.tone)         { missing.append("Tone") }
        if !categories.contains(.visual)       { missing.append("Visual Style") }
        if !categories.contains(.location)     { missing.append("Location") }
        return missing
    }

    static let mock = ContentMetadata(
        assetID: UUID(),
        tags: Array(Tag.mockList.prefix(6)),
        completenessScore: 0.65
    )
}

// MARK: - Topic Cluster

/// Groups related tags into discoverable knowledge-graph clusters.
struct TopicCluster: Identifiable, Codable {
    let id: UUID
    var name: String
    var relatedTags: [Tag]
    var contentCount: Int

    init(
        id: UUID = UUID(),
        name: String,
        relatedTags: [Tag] = [],
        contentCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.relatedTags = relatedTags
        self.contentCount = contentCount
    }

    static let mockList: [TopicCluster] = [
        TopicCluster(
            name: "Content Marketing",
            relatedTags: [
                Tag(name: "Education", category: .pillar),
                Tag(name: "Tutorial", category: .pillar),
                Tag(name: "Link in Bio", category: .cta),
            ],
            contentCount: 23
        ),
        TopicCluster(
            name: "Brand Awareness",
            relatedTags: [
                Tag(name: "Awareness", category: .funnel),
                Tag(name: "ENVI", category: .brand),
                Tag(name: "Summer Launch", category: .campaign),
            ],
            contentCount: 15
        ),
        TopicCluster(
            name: "Engagement Drivers",
            relatedTags: [
                Tag(name: "Question Hook", category: .hook),
                Tag(name: "High CTR", category: .performance),
                Tag(name: "Gen Z", category: .persona),
            ],
            contentCount: 31
        ),
    ]
}
