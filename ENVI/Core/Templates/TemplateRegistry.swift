// TemplateRegistry.swift
// ENVI v3.0 — Extended Template Registry (Addon to existing VideoTemplate system)
// iOS 26+ | Swift 6 Strict Concurrency | Sendable
//
// PURPOSE:
// This registry is an ADDITION to the app's existing template system:
//   - TemplateCatalogClient (server-delivered templates)
//   - TemplateManifest (JSON schema for /v1/templates/manifest)
//   - VideoTemplate (the app's template model)
//   - TemplateMatchEngine (existing matching engine)
//   - TemplateRanker (existing ranker)
//
// It provides extended taxonomy queries (by style, niche, operation) that the
// current app's simpler VideoTemplate system doesn't have. TemplateDefinition
// is convertible to/from VideoTemplate for interoperability.

import Foundation

@available(iOS 26, *)
public actor TemplateRegistry {

    // MARK: - Singleton

    public static let shared = TemplateRegistry()

    // MARK: - Storage

    private var templates: [TemplateDefinition] = []
    private var archetypeIndex: [ContentArchetype: [TemplateDefinition]] = [:]
    private var styleIndex: [VisualStyle: [TemplateDefinition]] = [:]
    private var nicheIndex: [ContentNiche: [TemplateDefinition]] = [:]
    private var operationIndex: [String: [TemplateDefinition]] = [:]
    private var platformIndex: [Platform: [TemplateDefinition]] = [:]
    private var formatIndex: [ContentFormat: [TemplateDefinition]] = [:]

    // MARK: - Initialization

    public init() {
        self.templates = Self.buildAllTemplates()
        buildIndices()
    }

    // MARK: - Template Definition

    /// Extended template definition with full taxonomy.
    /// Convertible to/from the app's existing VideoTemplate model.
    public struct TemplateDefinition: Codable, Sendable, Hashable, Identifiable {
        public let id: String
        public let archetype: ContentArchetype
        public let style: VisualStyle
        public let niche: ContentNiche
        public let requiredOperations: [String]
        public let optionalOperations: [String]
        public let platform: Platform
        public let estimatedRenderTime: TimeInterval
        public let complexityScore: Double // 0.0 - 1.0
        public let metadata: TemplateMetadata

        public init(
            id: String,
            archetype: ContentArchetype,
            style: VisualStyle,
            niche: ContentNiche,
            requiredOperations: [String] = [],
            optionalOperations: [String] = [],
            platform: Platform = .general,
            estimatedRenderTime: TimeInterval = 1.0,
            complexityScore: Double = 0.5,
            metadata: TemplateMetadata = TemplateMetadata()
        ) {
            self.id = id
            self.archetype = archetype
            self.style = style
            self.niche = niche
            self.requiredOperations = requiredOperations
            self.optionalOperations = optionalOperations
            self.platform = platform
            self.estimatedRenderTime = estimatedRenderTime
            self.complexityScore = complexityScore
            self.metadata = metadata
        }
    }

    public struct TemplateMetadata: Codable, Sendable, Hashable {
        public let name: String
        public let description: String
        public let aspectRatio: AspectRatio
        public let minDuration: TimeInterval?
        public let maxDuration: TimeInterval?
        public let minPhotos: Int?
        public let maxPhotos: Int?
        public let requiresAudio: Bool
        public let requiresText: Bool
        public let creatorCount: Int // 1 = solo, 2+ = collab
        public let isAIGenerated: Bool
        public let isAREnhanced: Bool
        public let seasonalRelevance: [Season]?

        public init(
            name: String = "",
            description: String = "",
            aspectRatio: AspectRatio = .square,
            minDuration: TimeInterval? = nil,
            maxDuration: TimeInterval? = nil,
            minPhotos: Int? = nil,
            maxPhotos: Int? = nil,
            requiresAudio: Bool = false,
            requiresText: Bool = false,
            creatorCount: Int = 1,
            isAIGenerated: Bool = false,
            isAREnhanced: Bool = false,
            seasonalRelevance: [Season]? = nil
        ) {
            self.name = name
            self.description = description
            self.aspectRatio = aspectRatio
            self.minDuration = minDuration
            self.maxDuration = maxDuration
            self.minPhotos = minPhotos
            self.maxPhotos = maxPhotos
            self.requiresAudio = requiresAudio
            self.requiresText = requiresText
            self.creatorCount = creatorCount
            self.isAIGenerated = isAIGenerated
            self.isAREnhanced = isAREnhanced
            self.seasonalRelevance = seasonalRelevance
        }
    }

    public enum AspectRatio: String, Codable, Sendable, Hashable {
        case square = "1:1"
        case portrait = "4:5"
        case story = "9:16"
        case landscape = "16:9"
        case wide = "21:9"
        case classic = "3:2"
        case portraitTall = "2:3"
        case fourThree = "4:3"
        case threeFour = "3:4"
    }

    public enum Season: String, Codable, Sendable, Hashable {
        case spring, summer, autumn, winter
        case holiday, newYear, valentine, halloween
    }

    // MARK: - VideoTemplate Interop

    /// Convert this TemplateDefinition to the app's existing VideoTemplate.
    /// Maps taxonomy fields to VideoTemplate's simpler model. Non-video formats
    /// are mapped with sensible defaults so the existing engine can still use them.
    ///
    /// - Parameters:
    ///   - videoTemplateID: Optional override for the target VideoTemplate ID.
    ///     Uses this definition's `id` by default.
    ///   - categoryOverride: Optional string to use as the VideoTemplate's
    ///     category field. Uses the archetype's `id` by default.
    /// - Returns: A VideoTemplate instance, or nil if the conversion cannot
    ///   produce a valid VideoTemplate (e.g. non-video format).
    public func toVideoTemplate(
        videoTemplateID: String? = nil,
        categoryOverride: String? = nil
    ) -> VideoTemplate? {
        // Only convert video-format archetypes to VideoTemplate.
        // Photo/carousel/story formats stay in the extended registry only.
        guard archetype.format == .video else { return nil }

        let targetID = videoTemplateID ?? id
        let category = categoryOverride ?? archetype.id

        return VideoTemplate(
            id: targetID,
            name: metadata.name.isEmpty ? "\(style.rawValue) \(archetype.displayName)" : metadata.name,
            category: category,
            slotCount: 1,
            estimatedDuration: metadata.minDuration ?? 15.0,
            platform: platform.rawValue,
            complexity: complexityScore,
            requiresAudio: metadata.requiresAudio,
            requiresText: metadata.requiresText,
            tags: buildVideoTemplateTags()
        )
    }

    /// Create a TemplateDefinition from an existing VideoTemplate.
    /// This enriches the simpler VideoTemplate with extended taxonomy data
    /// by inferring style, niche, and operations from available hints.
    ///
    /// - Parameters:
    ///   - videoTemplate: The existing VideoTemplate to convert.
    ///   - style: The visual style to assign (defaults to .Minimal).
    ///   - niche: The content niche to assign (defaults to .GeneralLifestyle).
    ///   - operations: Required operations (inferred from VideoTemplate if empty).
    /// - Returns: A new TemplateDefinition with extended taxonomy fields populated.
    public static func fromVideoTemplate(
        _ videoTemplate: VideoTemplate,
        style: VisualStyle = .Minimal,
        niche: ContentNiche = .GeneralLifestyle,
        operations: [String]? = nil
    ) -> TemplateDefinition {
        let archetype = ContentArchetype.video(
            VideoArchetype(rawValue: videoTemplate.category) ?? .V1
        )

        let ops = operations ?? inferOperations(from: videoTemplate)

        return TemplateDefinition(
            id: videoTemplate.id,
            archetype: archetype,
            style: style,
            niche: niche,
            requiredOperations: ops,
            platform: Platform(rawValue: videoTemplate.platform) ?? .general,
            estimatedRenderTime: videoTemplate.estimatedDuration,
            complexityScore: videoTemplate.complexity,
            metadata: TemplateMetadata(
                name: videoTemplate.name,
                aspectRatio: .story, // VideoTemplate defaults to 9:16
                minDuration: videoTemplate.estimatedDuration,
                requiresAudio: videoTemplate.requiresAudio,
                requiresText: videoTemplate.requiresText
            )
        )
    }

    /// Batch-convert an array of VideoTemplates to TemplateDefinitions.
    public static func fromVideoTemplates(
        _ templates: [VideoTemplate],
        style: VisualStyle = .Minimal,
        niche: ContentNiche = .GeneralLifestyle
    ) -> [TemplateDefinition] {
        templates.map { fromVideoTemplate($0, style: style, niche: niche) }
    }

    // MARK: - Query API

    /// Find templates matching a specific archetype.
    public func templates(for archetype: ContentArchetype) -> [TemplateDefinition] {
        return archetypeIndex[archetype] ?? []
    }

    /// Find templates matching a specific style.
    public func templates(for style: VisualStyle) -> [TemplateDefinition] {
        return styleIndex[style] ?? []
    }

    /// Find templates matching a specific niche.
    public func templates(for niche: ContentNiche) -> [TemplateDefinition] {
        return nicheIndex[niche] ?? []
    }

    /// Find templates requiring a specific operation.
    public func templates(requiring operation: AlgorithmicOperation) -> [TemplateDefinition] {
        return operationIndex[operation] ?? []
    }

    /// Find templates optimized for a specific platform.
    public func templates(for platform: Platform) -> [TemplateDefinition] {
        return platformIndex[platform] ?? []
    }

    /// Find templates for a specific content format.
    public func templates(for format: ContentFormat) -> [TemplateDefinition] {
        return formatIndex[format] ?? []
    }

    /// Cross-dimensional query with scoring and filtering.
    /// This is the primary query API — it combines multiple taxonomy dimensions.
    public func query(
        archetypes: [ContentArchetype]? = nil,
        styles: [VisualStyle]? = nil,
        niches: [ContentNiche]? = nil,
        operations: [String]? = nil,
        platforms: [Platform]? = nil,
        formats: [ContentFormat]? = nil,
        maxComplexity: Double? = nil,
        minComplexity: Double? = nil,
        limit: Int = 50
    ) -> [TemplateDefinition] {
        var candidates = templates

        if let archetypes {
            candidates = candidates.filter { archetypes.contains($0.archetype) }
        }
        if let styles {
            candidates = candidates.filter { styles.contains($0.style) }
        }
        if let niches {
            candidates = candidates.filter { niches.contains($0.niche) }
        }
        if let operations {
            candidates = candidates.filter { tpl in
                operations.allSatisfy { op in
                    tpl.requiredOperations.contains(op) || tpl.optionalOperations.contains(op)
                }
            }
        }
        if let platforms {
            candidates = candidates.filter {
                platforms.contains($0.platform) || $0.platform == .general
            }
        }
        if let formats {
            candidates = candidates.filter { formats.contains($0.archetype.format) }
        }
        if let maxComplexity {
            candidates = candidates.filter { $0.complexityScore <= maxComplexity }
        }
        if let minComplexity {
            candidates = candidates.filter { $0.complexityScore >= minComplexity }
        }

        return Array(candidates.prefix(limit))
    }

    /// Query by style family — returns all templates whose style belongs to the family.
    public func templates(in family: VisualStyleFamily) -> [TemplateDefinition] {
        templates.filter { $0.style.family == family }
    }

    /// Query by niche category — returns all templates whose niche belongs to the category.
    public func templates(in category: ContentNicheCategory) -> [TemplateDefinition] {
        templates.filter { nicheBelongsToCategory($0.niche, category) }
    }

    /// Query by operation category — returns all templates with ops in the category.
    public func templates(in category: OperationCategory) -> [TemplateDefinition] {
        templates.filter { tpl in
            tpl.requiredOperations.contains { $0.category == category } ||
            tpl.optionalOperations.contains { $0.category == category }
        }
    }

    /// Find similar templates based on shared taxonomy dimensions.
    /// Returns templates that share at least one dimension (style, niche, or archetype format).
    public func similar(to template: TemplateDefinition, limit: Int = 10) -> [TemplateDefinition] {
        templates.filter { other in
            other.id != template.id && (
                other.style == template.style ||
                other.niche == template.niche ||
                other.archetype.format == template.archetype.format
            )
        }
        .prefix(limit)
    }

    /// Total template count.
    public var count: Int { templates.count }

    /// Count by format.
    public func count(by format: ContentFormat) -> Int {
        formatIndex[format]?.count ?? 0
    }

    /// Count by platform.
    public func count(by platform: Platform) -> Int {
        platformIndex[platform]?.count ?? 0
    }

    // MARK: - Registration

    /// Register a new template definition into the registry.
    /// Thread-safe via actor isolation.
    public func register(_ definition: TemplateDefinition) {
        templates.append(definition)
        archetypeIndex[definition.archetype, default: []].append(definition)
        styleIndex[definition.style, default: []].append(definition)
        nicheIndex[definition.niche, default: []].append(definition)
        platformIndex[definition.platform, default: []].append(definition)
        formatIndex[definition.archetype.format, default: []].append(definition)
        for op in definition.requiredOperations {
            operationIndex[op, default: []].append(definition)
        }
    }

    /// Register multiple template definitions at once.
    public func register(_ definitions: [TemplateDefinition]) {
        for definition in definitions {
            register(definition)
        }
    }

    /// Remove a template by ID.
    public func remove(id: String) {
        guard let index = templates.firstIndex(where: { $0.id == id }) else { return }
        let removed = templates.remove(at: index)
        removeFromIndices(removed)
    }

    /// Get a template by ID.
    public func get(id: String) -> TemplateDefinition? {
        templates.first { $0.id == id }
    }

    // MARK: - Private

    private func buildIndices() {
        for template in templates {
            archetypeIndex[template.archetype, default: []].append(template)
            styleIndex[template.style, default: []].append(template)
            nicheIndex[template.niche, default: []].append(template)
            platformIndex[template.platform, default: []].append(template)
            formatIndex[template.archetype.format, default: []].append(template)
            for op in template.requiredOperations {
                operationIndex[op, default: []].append(template)
            }
        }
    }

    private func removeFromIndices(_ definition: TemplateDefinition) {
        archetypeIndex[definition.archetype]?.removeAll { $0.id == definition.id }
        styleIndex[definition.style]?.removeAll { $0.id == definition.id }
        nicheIndex[definition.niche]?.removeAll { $0.id == definition.id }
        platformIndex[definition.platform]?.removeAll { $0.id == definition.id }
        formatIndex[definition.archetype.format]?.removeAll { $0.id == definition.id }
        for op in definition.requiredOperations {
            operationIndex[op]?.removeAll { $0.id == definition.id }
        }
    }

    private func nicheBelongsToCategory(_ niche: ContentNiche, _ category: ContentNicheCategory) -> Bool {
        niche.category == category
    }

    private func buildVideoTemplateTags() -> [String] {
        var tags: [String] = []
        tags.append(style.rawValue)
        tags.append(niche.rawValue)
        tags.append(archetype.displayName)
        if metadata.isAIGenerated { tags.append("ai-generated") }
        if metadata.isAREnhanced { tags.append("ar-enhanced") }
        if let seasons = metadata.seasonalRelevance {
            tags.append(contentsOf: seasons.map(\.rawValue))
        }
        return tags
    }

    private static func inferOperations(from videoTemplate: VideoTemplate) -> [String] {
        var ops: [String] = []
        if videoTemplate.requiresAudio {
            ops.append(.MusicSFXMatching)
        }
        if videoTemplate.requiresText {
            ops.append(.AutoCaptionGeneration)
        }
        // Default video operations
        ops.append(.SubjectDetection)
        ops.append(.SmartCropReframe)
        ops.append(.ColorGrading)
        return ops
    }

    // MARK: - Template Factory

    private static func buildAllTemplates() -> [TemplateDefinition] {
        // Seed factory generating representative templates across the taxonomy.
        // In production, templates load from CDN bundles via TemplateBundleLoader.
        var result: [TemplateDefinition] = []

        // Photo templates (seed set)
        let photoArchetypes: [ContentArchetype] = [
            .photo(.P1), .photo(.P2), .photo(.P3),
            .photo(.P4), .photo(.P5), .photo(.P6),
            .photo(.P7), .photo(.P8), .photo(.P9),
            .photo(.P10)
        ]

        let topStyles: [VisualStyle] = [
            .Minimal, .Clean, .Bold, .Vintage, .Cinematic,
            .Moody, .Dreamy, .Cyberpunk, .Editorial, .Luxury
        ]

        let topNiches: [ContentNiche] = [
            .GeneralLifestyle, .Fashion, .FitnessAndGym, .Travel,
            .RecipesAndCooking, .BeautyAndMakeup, .TechnologyAndGadgets,
            .ArtAndDesign, .Music, .Photography
        ]

        for archetype in photoArchetypes {
            for style in topStyles {
                for niche in topNiches {
                    let id = "\(archetype.id)_\(style.rawValue)_\(niche.rawValue)"
                    result.append(TemplateDefinition(
                        id: id,
                        archetype: archetype,
                        style: style,
                        niche: niche,
                        platform: .instagram,
                        metadata: TemplateMetadata(
                            name: "\(style) \(archetype.displayName) - \(niche)",
                            aspectRatio: .portrait,
                            requiresAudio: false
                        )
                    ))
                }
            }
        }

        // Video templates (seed set) — these are convertible to VideoTemplate
        let videoArchetypes: [ContentArchetype] = [
            .video(.V1), .video(.V2), .video(.V3),
            .video(.V4), .video(.V5), .video(.V6),
            .video(.V7), .video(.V8), .video(.V9),
            .video(.V10)
        ]

        for archetype in videoArchetypes {
            for style in topStyles.prefix(5) {
                for niche in topNiches.prefix(5) {
                    let id = "\(archetype.id)_\(style.rawValue)_\(niche.rawValue)"
                    result.append(TemplateDefinition(
                        id: id,
                        archetype: archetype,
                        style: style,
                        niche: niche,
                        requiredOperations: [.SubjectDetection, .SmartCropReframe, .ColorGrading],
                        platform: .tiktok,
                        estimatedRenderTime: 3.0,
                        metadata: TemplateMetadata(
                            name: "\(style) \(archetype.displayName) - \(niche)",
                            aspectRatio: .story,
                            minDuration: 15.0,
                            maxDuration: 60.0,
                            requiresAudio: true,
                            requiresText: true
                        )
                    ))
                }
            }
        }

        return result
    }
}

// MARK: - Template Bundle Loader

/// Loads template definitions from CDN or local cache.
/// Works alongside TemplateCatalogClient — use this for bulk bundle loads,
/// while TemplateCatalogClient handles per-template server delivery.
@available(iOS 26, *)
public actor TemplateBundleLoader {
    private var cachedBundles: [String: TemplateBundle] = [:]

    public struct TemplateBundle: Codable, Sendable {
        public let bundleId: String
        public let version: String
        public let templates: [TemplateRegistry.TemplateDefinition]
        public let styles: [StyleModel]
        public let niches: [NicheModel]
        public let operations: [OperationDescriptor]
        public let createdAt: Date
    }

    public func loadBundle(from url: URL) async throws -> TemplateBundle {
        let (data, _) = try await URLSession.shared.data(from: url)
        let bundle = try JSONDecoder().decode(TemplateBundle.self, from: data)
        cachedBundles[bundle.bundleId] = bundle
        return bundle
    }

    public func bundle(id: String) -> TemplateBundle? {
        return cachedBundles[id]
    }

    /// Merge a loaded bundle's templates into the shared registry.
    public func mergeBundleIntoRegistry(id: String, registry: TemplateRegistry) async {
        guard let bundle = cachedBundles[id] else { return }
        await registry.register(bundle.templates)
    }
}

// MARK: - TemplateCatalogClient Bridge

/// Bridge between the extended TemplateRegistry and the app's existing
/// TemplateCatalogClient. This allows the registry to receive server-delivered
/// templates and enrich them with extended taxonomy data.
@available(iOS 26, *)
public actor TemplateCatalogBridge {
    private let registry: TemplateRegistry
    private var manifestCache: TemplateManifest?

    public init(registry: TemplateRegistry) {
        self.registry = registry
    }

    /// Sync templates from the server's TemplateCatalogClient into the registry.
    /// Enriches each VideoTemplate with extended taxonomy fields.
    public func syncFromCatalog(
        _ videoTemplates: [VideoTemplate],
        style: VisualStyle = .Minimal,
        niche: ContentNiche = .GeneralLifestyle
    ) async {
        let definitions = TemplateRegistry.fromVideoTemplates(
            videoTemplates,
            style: style,
            niche: niche
        )
        await registry.register(definitions)
    }

    /// Cache the current manifest for manifest-aware sync decisions.
    public func cacheManifest(_ manifest: TemplateManifest) {
        manifestCache = manifest
    }

    /// Check if a registry refresh is needed based on manifest version.
    public var needsRefresh: Bool {
        guard let manifest = manifestCache else { return true }
        // Compare manifest version against cached bundle versions
        return true // Simplified — real impl would compare version strings
    }
}
