//  TemplateMatchingEngine.swift
//  ENVI v3.0 — iOS 26+ / Swift 6
//
//  Extended template matching that works alongside the current app's existing:
//    - TemplateMatchEngine (actor, 6-factor scoring, UMAP+HDBSCAN)
//    - TemplateRanker (fillRate + score + popularity + recency)
//
//  This engine adds:
//    - 7-factor scoring (vibe 30%, aesthetics 15%, scene 10%, quality 15%, motion 15%, people 10%, recency 10%)
//    - User history tracking (style/niche affinity)
//    - Cross-format matching (photo, carousel, video, story, newFormat)
//    - ContentFormat-aware candidate generation
//
//  Usage: Use the existing TemplateMatchEngine for video-slot matching,
//  use this engine for extended taxonomy queries across all 5 formats.

import Foundation

// MARK: - Template Matching Engine
/// Actor-isolated for Swift 6 strict concurrency.
@available(iOS 26, *)
public actor TemplateMatchingEngine {

    // MARK: - Types

    public struct TemplateMatchResult: Sendable, Hashable, Identifiable {
        public let id: String
        public let templateID: String
        public let templateName: String
        public let score: Double
        public let scoreBreakdown: ScoreBreakdown
        public let style: String?
        public let niche: String?
        public let category: VideoTemplateCategory?

        public init(
            id: String = UUID().uuidString,
            templateID: String,
            templateName: String,
            score: Double,
            scoreBreakdown: ScoreBreakdown,
            style: String? = nil,
            niche: String? = nil,
            category: VideoTemplateCategory? = nil
        ) {
            self.id = id
            self.templateID = templateID
            self.templateName = templateName
            self.score = score
            self.scoreBreakdown = scoreBreakdown
            self.style = style
            self.niche = niche
            self.category = category
        }
    }

    public struct ScoreBreakdown: Sendable, Hashable {
        public let vibe: Double          // 30% — embedding cosine similarity
        public let aesthetics: Double     // 15% — aesthetic profile match
        public let scene: Double          // 10% — scene label overlap
        public let quality: Double        // 15% — source quality vs template complexity
        public let motion: Double         // 15% — motion energy vs template requirements
        public let people: Double         // 10% — face count alignment
        public let recency: Double        // 10% — user history bias

        public var weightedTotal: Double {
            vibe * 0.30 + aesthetics * 0.15 + scene * 0.10 +
            quality * 0.15 + motion * 0.15 + people * 0.10 + recency * 0.10
        }

        public init(
            vibe: Double,
            aesthetics: Double,
            scene: Double,
            quality: Double,
            motion: Double,
            people: Double,
            recency: Double
        ) {
            self.vibe = vibe
            self.aesthetics = aesthetics
            self.scene = scene
            self.quality = quality
            self.motion = motion
            self.people = people
            self.recency = recency
        }
    }

    public struct MatchingConfig: Sendable {
        public var topK: Int
        public var minScore: Double
        public var requireAllOperations: Bool
        public var enableEmbeddingMatch: Bool

        public init(
            topK: Int = 10,
            minScore: Double = 0.3,
            requireAllOperations: Bool = true,
            enableEmbeddingMatch: Bool = true
        ) {
            self.topK = topK
            self.minScore = minScore
            self.requireAllOperations = requireAllOperations
            self.enableEmbeddingMatch = enableEmbeddingMatch
        }
    }

    // MARK: - State

    private var templates: [TemplateDefinition] = []
    private var embeddingIndex: [String: [Float]] = [:]  // templateID -> embedding
    private var userHistory: UserStyleHistory?

    // MARK: - Template Definition (simplified for v3.0)

    public struct TemplateDefinition: Sendable, Hashable, Identifiable {
        public let id: String
        public let name: String
        public let format: String  // "photo", "carousel", "video", "story", "newFormat"
        public let category: VideoTemplateCategory?
        public let style: String?
        public let niche: String?
        public let requiredOperations: [String]
        public let complexityScore: Double  // 0.0 - 1.0

        public init(
            id: String,
            name: String,
            format: String,
            category: VideoTemplateCategory? = nil,
            style: String? = nil,
            niche: String? = nil,
            requiredOperations: [String] = [],
            complexityScore: Double = 0.5
        ) {
            self.id = id
            self.name = name
            self.format = format
            self.category = category
            self.style = style
            self.niche = niche
            self.requiredOperations = requiredOperations
            self.complexityScore = complexityScore
        }
    }

    // MARK: - Initialization

    public init() {
        seedTemplates()
    }

    /// Attach user history for recency/style affinity scoring
    public func attachHistory(_ history: UserStyleHistory) async {
        self.userHistory = history
    }

    // MARK: - Public API

    /// Rank templates for a single feature vector
    public func rankTemplates(
        for features: MediaAnalysisEngine.MediaFeatureVector,
        config: MatchingConfig = MatchingConfig()
    ) async throws -> [TemplateMatchResult] {
        let candidates = generateCandidates(for: features, config: config)
        let scored = await scoreCandidates(candidates, against: features, config: config)
        return Array(scored.prefix(config.topK))
    }

    /// Rank templates for multiple feature vectors (carousel, multi-clip)
    public func rankTemplates(
        for features: [MediaAnalysisEngine.MediaFeatureVector],
        config: MatchingConfig = MatchingConfig()
    ) async throws -> [TemplateMatchResult] {
        guard let primary = features.first else { return [] }
        let aggregated = aggregateFeatures(features)
        return try await rankTemplates(for: aggregated, config: config)
    }

    // MARK: - Candidate Generation

    private func generateCandidates(
        for features: MediaAnalysisEngine.MediaFeatureVector,
        config: MatchingConfig
    ) -> [TemplateDefinition] {
        var candidates = templates

        // Format constraint
        candidates = candidates.filter { $0.format == features.format }

        return candidates
    }

    // MARK: - Scoring

    private func scoreCandidates(
        _ candidates: [TemplateDefinition],
        against features: MediaAnalysisEngine.MediaFeatureVector,
        config: MatchingConfig
    ) async -> [TemplateMatchResult] {
        var matches: [TemplateMatchResult] = []

        for template in candidates {
            let breakdown = computeScoreBreakdown(template, features: features)
            let totalScore = breakdown.weightedTotal

            if totalScore >= config.minScore {
                matches.append(TemplateMatchResult(
                    templateID: template.id,
                    templateName: template.name,
                    score: totalScore,
                    scoreBreakdown: breakdown,
                    style: template.style,
                    niche: template.niche,
                    category: template.category
                ))
            }
        }

        matches.sort { $0.score > $1.score }

        // Fallback: return top 3 if nothing above threshold
        if matches.isEmpty, let fallback = candidates.first {
            let breakdown = ScoreBreakdown(
                vibe: 0.3, aesthetics: 0.3, scene: 0.3,
                quality: 0.3, motion: 0.3, people: 0.3, recency: 0.3
            )
            matches.append(TemplateMatchResult(
                templateID: fallback.id,
                templateName: fallback.name,
                score: 0.25,
                scoreBreakdown: breakdown,
                style: fallback.style,
                niche: fallback.niche,
                category: fallback.category
            ))
        }

        return matches
    }

    private func computeScoreBreakdown(
        _ template: TemplateDefinition,
        features: MediaAnalysisEngine.MediaFeatureVector
    ) -> ScoreBreakdown {
        // 1. Vibe match (30%): cosine similarity
        let vibeScore = computeVibeScore(template: template, features: features)

        // 2. Aesthetics (15%)
        let aestheticsScore = Double(features.aestheticScores.average)

        // 3. Scene match (10%)
        let sceneScore = computeSceneScore(template: template, features: features)

        // 4. Quality (15%)
        let qualityScore = computeQualityScore(template: template, features: features)

        // 5. Motion (15%)
        let motionScore = computeMotionScore(template: template, features: features)

        // 6. People (10%)
        let peopleScore = Double(features.faceCount > 0 ? 0.8 : 0.5)

        // 7. Recency (10%)
        let recencyScore = computeRecencyScore(template: template)

        return ScoreBreakdown(
            vibe: vibeScore,
            aesthetics: aestheticsScore,
            scene: sceneScore,
            quality: qualityScore,
            motion: motionScore,
            people: peopleScore,
            recency: recencyScore
        )
    }

    // MARK: - Individual Scoring Factors

    private func computeVibeScore(
        template: TemplateDefinition,
        features: MediaAnalysisEngine.MediaFeatureVector
    ) -> Double {
        guard config.enableEmbeddingMatch,
              !features.vibeEmbedding.isEmpty,
              let templateEmbedding = embeddingIndex[template.id] else {
            return 0.5
        }
        return cosineSimilarity(features.vibeEmbedding, templateEmbedding)
    }

    private func computeSceneScore(
        template: TemplateDefinition,
        features: MediaAnalysisEngine.MediaFeatureVector
    ) -> Double {
        let detectedLabels = Set(features.sceneLabels.map(\.label.lowercased()))
        // Simple heuristic: if template has niche hints that match detected scenes
        let templateScenes = sceneHintsForCategory(template.category)
        let overlap = templateScenes.filter { detectedLabels.contains($0) }.count
        return Double(overlap) / Double(max(templateScenes.count, 1))
    }

    private func computeQualityScore(
        template: TemplateDefinition,
        features: MediaAnalysisEngine.MediaFeatureVector
    ) -> Double {
        let sourceQuality = Double(features.aestheticScores.overall)
        let templateComplexity = template.complexityScore

        if templateComplexity > 0.7 {
            return sourceQuality
        } else if templateComplexity < 0.3 {
            return 0.5 + sourceQuality * 0.5
        } else {
            return 0.3 + sourceQuality * 0.7
        }
    }

    private func computeMotionScore(
        template: TemplateDefinition,
        features: MediaAnalysisEngine.MediaFeatureVector
    ) -> Double {
        guard let motionEnergy = features.motionEnergy else { return 0.5 }
        let isMotionHeavy = template.requiredOperations.contains("motionTracking")
        return isMotionHeavy ? Double(motionEnergy) : 1.0 - Double(motionEnergy) * 0.3
    }

    private func computeRecencyScore(
        template: TemplateDefinition
    ) -> Double {
        guard let history = userHistory else { return 0.5 }
        let key = template.id
        if history.approvedTemplates.contains(key) {
            return 1.0
        } else if history.rejectedTemplates.contains(key) {
            return 0.1
        } else {
            return 0.5
        }
    }

    // MARK: - Helpers

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0.0 }

        var dot: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        for i in 0..<a.count {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        let denom = sqrt(normA * normB)
        return denom > 0 ? Double(dot / denom) : 0.0
    }

    private func sceneHintsForCategory(_ category: VideoTemplateCategory?) -> Set<String> {
        guard let category = category else { return ["general"] }
        switch category {
        case .travel:
            return ["outdoor", "landscape", "nature", "city", "architecture"]
        case .food, .cooking:
            return ["food", "indoor", "table"]
        case .fitness:
            return ["people", "sports", "gym", "outdoor"]
        case .beauty, .fashion:
            return ["people", "portrait", "face", "clothing"]
        case .grwm:
            return ["people", "portrait", "indoor", "face"]
        case .product:
            return ["product", "indoor", "studio"]
        default:
            return ["general"]
        }
    }

    private func aggregateFeatures(
        _ features: [MediaAnalysisEngine.MediaFeatureVector]
    ) -> MediaAnalysisEngine.MediaFeatureVector {
        guard let first = features.first else {
            return MediaAnalysisEngine.MediaFeatureVector(
                sourceID: "empty", format: .photo,
                vibeEmbedding: [], aestheticScores: .init(),
                sceneLabels: [], dominantColors: [],
                faceCount: 0, hasText: false
            )
        }

        if features.count == 1 { return first }

        let avgVibe = averageEmbeddings(features.map(\.vibeEmbedding))
        let avgAesthetics = averageAesthetics(features.map(\.aestheticScores))
        let allScenes = features.flatMap(\.sceneLabels).prefix(10)
        let allColors = features.flatMap(\.dominantColors).prefix(10)
        let totalFaces = features.reduce(0) { $0 + $1.faceCount }
        let hasText = features.contains(where: \.hasText)

        return MediaAnalysisEngine.MediaFeatureVector(
            sourceID: first.sourceID + "_aggregated",
            format: first.format,
            vibeEmbedding: avgVibe,
            aestheticScores: avgAesthetics,
            sceneLabels: Array(allScenes),
            dominantColors: Array(allColors),
            faceCount: totalFaces,
            hasText: hasText
        )
    }

    private func averageEmbeddings(_ embeddings: [[Float]]) -> [Float] {
        guard let first = embeddings.first, !first.isEmpty else { return [] }
        let dim = first.count
        var result = [Float](repeating: 0.0, count: dim)

        for emb in embeddings {
            for i in 0..<min(dim, emb.count) {
                result[i] += emb[i]
            }
        }

        let count = Float(embeddings.count)
        return result.map { $0 / count }
    }

    private func averageAesthetics(_ scores: [MediaAnalysisEngine.AestheticScores]) -> MediaAnalysisEngine.AestheticScores {
        guard !scores.isEmpty else { return .init() }
        let count = Float(scores.count)
        return MediaAnalysisEngine.AestheticScores(
            overall: scores.map(\.overall).reduce(0, +) / count,
            composition: scores.map(\.composition).reduce(0, +) / count,
            colorHarmony: scores.map(\.colorHarmony).reduce(0, +) / count,
            lighting: scores.map(\.lighting).reduce(0, +) / count,
            subjectFocus: scores.map(\.subjectFocus).reduce(0, +) / count,
            depthOfField: scores.map(\.depthOfField).reduce(0, +) / count,
            symmetry: scores.map(\.symmetry).reduce(0, +) / count,
            textureDetail: scores.map(\.textureDetail).reduce(0, +) / count
        )
    }

    // MARK: - Seed Templates (placeholder)

    private func seedTemplates() {
        // Seed with representative templates across the 12 categories and 5 formats
        let formats: [ContentFormat] = [.photo, .carousel, .video, .story, .newFormat]
        let categories: [VideoTemplateCategory] = VideoTemplateCategory.allCases

        for category in categories {
            for format in formats {
                let id = "\(category.rawValue)_\(format.rawValue)"
                templates.append(TemplateDefinition(
                    id: id,
                    name: "\(category.displayName) \(format.displayName)",
                    format: format,
                    category: category
                ))
            }
        }
    }
}

// MARK: - User Style History

@available(iOS 26, *)
public actor UserStyleHistory {
    public var approvedTemplates: Set<String> = []
    public var rejectedTemplates: Set<String> = []
    public var styleAffinity: [String: Double] = [:]
    public var nicheAffinity: [String: Double] = [:]

    public func recordApproval(templateID: String, style: String?, niche: String?) {
        approvedTemplates.insert(templateID)
        if let style = style { styleAffinity[style, default: 0] += 1 }
        if let niche = niche { nicheAffinity[niche, default: 0] += 1 }
    }

    public func recordRejection(templateID: String, style: String?, niche: String?) {
        rejectedTemplates.insert(templateID)
        if let style = style { styleAffinity[style, default: 0] -= 0.5 }
        if let niche = niche { nicheAffinity[niche, default: 0] -= 0.5 }
    }
}

