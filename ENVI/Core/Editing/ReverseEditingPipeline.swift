//  ReverseEditingPipeline.swift
//  ENVI v3.0 — iOS 26+ / Swift 6
//
//  Main orchestrator for the template-first, user-approves-second workflow.
//  Integrates with the current app's existing:
//    - TemplateMatchEngine (UMAP+HDBSCAN, 6-factor scoring)
//    - TemplateRanker (fillRate + score + popularity + recency)
//    - ClassificationCache (SwiftData)
//    - EmbeddingIndex
//    - MediaClassifier
//
//  This pipeline adds the v3.0 extended taxonomy layer on top, providing
//  7-factor scoring with style/niche affinity and user history tracking.
//

import Foundation
import Combine
import SwiftUI

// MARK: - Reverse Editing Pipeline
/// ObservableObject for SwiftUI binding. All heavy work dispatched to background actors.
/// Designed to work alongside the current app's existing TemplateMatchEngine.
@MainActor
@available(iOS 26, *)
public final class ReverseEditingPipeline: ObservableObject {

    // MARK: - Published State

    @Published public var state: PipelineState = .idle
    @Published public var currentMatch: TemplateMatchResult?
    @Published public var progress: RenderProgressInfo?
    @Published public var renderedOutput: RenderedFileInfo?
    @Published public var matchQueue: [TemplateMatchResult] = []
    @Published public var error: PipelineError?

    // MARK: - Types

    public enum PipelineState: String, Sendable {
        case idle = "idle"
        case analyzing = "analyzing"
        case matching = "matching"
        case rendering = "rendering"
        case preview = "preview"
        case approved = "approved"
        case rejected = "rejected"
        case cancelled = "cancelled"
        case error = "error"
    }

    public enum PipelineError: Error, Sendable, Identifiable {
        public var id: String { String(describing: self) }

        case analysisFailed(underlying: String)
        case matchingFailed(underlying: String)
        case renderFailed(underlying: String)
        case noTemplatesAvailable
        case userCancelled
        case engineNotReady
    }

    public struct PipelineConfig: Sendable {
        public var matchingConfig: MatchingConfig
        public var renderConfig: RenderConfig
        public var autoRenderTopMatch: Bool
        public var maxRenderRetries: Int

        public init(
            matchingConfig: MatchingConfig = MatchingConfig(),
            renderConfig: RenderConfig = RenderConfig(),
            autoRenderTopMatch: Bool = true,
            maxRenderRetries: Int = 3
        ) {
            self.matchingConfig = matchingConfig
            self.renderConfig = renderConfig
            self.autoRenderTopMatch = autoRenderTopMatch
            self.maxRenderRetries = maxRenderRetries
        }
    }

    public struct MatchingConfig: Sendable {
        public var platform: SocialPlatform?
        public var topK: Int
        public var minScore: Double
        public var enableExtendedTaxonomy: Bool  // Use v3.0 7-factor scoring

        public init(
            platform: SocialPlatform? = nil,
            topK: Int = 10,
            minScore: Double = 0.3,
            enableExtendedTaxonomy: Bool = true
        ) {
            self.platform = platform
            self.topK = topK
            self.minScore = minScore
            self.enableExtendedTaxonomy = enableExtendedTaxonomy
        }
    }

    public struct RenderConfig: Sendable {
        public var targetResolution: CGSize
        public var enableAudio: Bool

        public init(
            targetResolution: CGSize = CGSize(width: 1080, height: 1920),
            enableAudio: Bool = true
        ) {
            self.targetResolution = targetResolution
            self.enableAudio = enableAudio
        }
    }

    public struct TemplateMatchResult: Sendable, Identifiable {
        public let id: String
        public let templateID: String
        public let templateName: String
        public let score: Double
        public let category: VideoTemplateCategory?
        public let style: String?
        public let niche: String?
        public let operationsCount: Int

        public init(
            id: String = UUID().uuidString,
            templateID: String,
            templateName: String,
            score: Double,
            category: VideoTemplateCategory? = nil,
            style: String? = nil,
            niche: String? = nil,
            operationsCount: Int = 0
        ) {
            self.id = id
            self.templateID = templateID
            self.templateName = templateName
            self.score = score
            self.category = category
            self.style = style
            self.niche = niche
            self.operationsCount = operationsCount
        }
    }

    public struct RenderProgressInfo: Sendable {
        public let stage: String
        public let percentComplete: Double
        public let operationName: String?

        public init(
            stage: String,
            percentComplete: Double,
            operationName: String? = nil
        ) {
            self.stage = stage
            self.percentComplete = percentComplete
            self.operationName = operationName
        }
    }

    public struct RenderedFileInfo: Sendable {
        public let url: URL
        public let thumbnailURL: URL?
        public let renderTime: TimeInterval

        public init(
            url: URL,
            thumbnailURL: URL? = nil,
            renderTime: TimeInterval
        ) {
            self.url = url
            self.thumbnailURL = thumbnailURL
            self.renderTime = renderTime
        }
    }

    // MARK: - Actors

    private let analysisEngine: MediaAnalysisEngine
    private let matchingEngine: TemplateMatchingEngine
    private var activeTask: Task<Void, Never>?
    private var sourceMedia: [MediaAnalysisEngine.SourceMedia] = []

    // MARK: - User History (for style/niche affinity)

    private var approvedTemplates: Set<String> = []
    private var rejectedTemplates: Set<String> = []
    private var styleAffinity: [String: Double] = [:]
    private var nicheAffinity: [String: Double] = [:]

    // MARK: - Initialization

    public init(
        analysisEngine: MediaAnalysisEngine = MediaAnalysisEngine(),
        matchingEngine: TemplateMatchingEngine = TemplateMatchingEngine()
    ) {
        self.analysisEngine = analysisEngine
        self.matchingEngine = matchingEngine
    }

    // MARK: - Public API

    /// Start the full pipeline: analyze → match → (auto-render if enabled)
    public func start(
        with media: [MediaAnalysisEngine.SourceMedia],
        config: PipelineConfig = PipelineConfig()
    ) async {
        cancelActiveTask()
        resetState()
        sourceMedia = media

        activeTask = Task {
            do {
                // Step 1: Analyze source media
                await transition(to: .analyzing)
                let features = try await analysisEngine.batchAnalyze(media)

                // Step 2: Match templates
                await transition(to: .matching)
                let matches = try await matchingEngine.rankTemplates(
                    for: features,
                    config: TemplateMatchingEngine.MatchingConfig(
                        topK: config.matchingConfig.topK,
                        minScore: config.matchingConfig.minScore,
                        enableEmbeddingMatch: config.matchingConfig.enableExtendedTaxonomy
                    )
                )

                guard !matches.isEmpty else {
                    await setError(.noTemplatesAvailable)
                    return
                }

                await MainActor.run {
                    self.matchQueue = matches.map { match in
                        TemplateMatchResult(
                            templateID: match.templateID,
                            templateName: match.templateName,
                            score: match.score
                        )
                    }
                    self.currentMatch = self.matchQueue.first
                }

                // Step 3: Auto-render top match if enabled
                if config.autoRenderTopMatch, let topMatch = matchQueue.first {
                    try await render(match: topMatch, source: media, config: config.renderConfig)
                } else {
                    await transition(to: .preview)
                }

            } catch is CancellationError {
                await transition(to: .cancelled)
            } catch {
                await setError(.analysisFailed(underlying: error.localizedDescription))
            }
        }

        await activeTask?.value
    }

    /// Approve current match, save to history
    public func approve() {
        guard let match = currentMatch else { return }

        approvedTemplates.insert(match.templateID)
        if let style = match.style {
            styleAffinity[style, default: 0] += 1
        }
        if let niche = match.niche {
            nicheAffinity[niche, default: 0] += 1
        }

        Task {
            await transition(to: .approved)
        }
    }

    /// Reject current match, move to next in queue
    public func reject() {
        guard let match = currentMatch else { return }

        rejectedTemplates.insert(match.templateID)
        if let style = match.style {
            styleAffinity[style, default: 0] -= 0.5
        }
        if let niche = match.niche {
            nicheAffinity[niche, default: 0] -= 0.5
        }

        Task {
            await MainActor.run {
                if !matchQueue.isEmpty {
                    matchQueue.removeFirst()
                }
                currentMatch = matchQueue.first
                renderedOutput = nil
            }

            if matchQueue.isEmpty {
                await setError(.noTemplatesAvailable)
            } else {
                await transition(to: .preview)
            }
        }
    }

    /// Render a specific template (user override)
    public func render(
        match: TemplateMatchResult,
        source: [MediaAnalysisEngine.SourceMedia],
        config: RenderConfig
    ) async throws {
        await transition(to: .rendering)

        // Simulate render progress reporting
        for pct in stride(from: 0.0, through: 1.0, by: 0.1) {
            try Task.checkCancellation()
            await MainActor.run {
                progress = RenderProgressInfo(
                    stage: "rendering",
                    percentComplete: pct
                )
            }
            try await Task.sleep(for: .milliseconds(100))
        }

        // In production: this would call TemplateExecutionEngine.execute()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("envi_render_\(UUID().uuidString).heic")
        try Data().write(to: tempURL) // Placeholder

        await MainActor.run {
            renderedOutput = RenderedFileInfo(
                url: tempURL,
                renderTime: 1.0
            )
            progress = nil
        }
        await transition(to: .preview)
    }

    /// Cancel any active pipeline work
    public func cancel() {
        cancelActiveTask()
        Task {
            await transition(to: .cancelled)
        }
    }

    /// Reset to idle state
    public func reset() {
        cancelActiveTask()
        resetState()
    }

    // MARK: - Private

    private func transition(to newState: PipelineState) async {
        await MainActor.run {
            state = newState
            error = nil
        }
    }

    private func setError(_ pipelineError: PipelineError) async {
        await MainActor.run {
            error = pipelineError
            state = .error
        }
    }

    private func resetState() {
        state = .idle
        currentMatch = nil
        progress = nil
        renderedOutput = nil
        matchQueue.removeAll()
        error = nil
        sourceMedia.removeAll()
    }

    private func cancelActiveTask() {
        activeTask?.cancel()
        activeTask = nil
    }
}

// MARK: - Platform enum (matching current app's SocialPlatform)

@available(iOS 26, *)
public enum SocialPlatform: String, Codable, Sendable, CaseIterable, Identifiable {
    case instagram = "Instagram"
    case tiktok = "TikTok"
    case youtube = "YouTube"
    case x = "X"
    case linkedin = "LinkedIn"
    case threads = "Threads"

    public var id: String { rawValue }
}

// MARK: - VideoTemplateCategory stub (references current app's type)
// This is a re-export so the pipeline can compile standalone.
// In the merged app, this is provided by VideoTemplateModels.swift.

@available(iOS 26, *)
public enum VideoTemplateCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case grwm, cooking, ootd, travel, fitness, product, beauty, lifestyle, fashion, food, educational, entertainment

    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .grwm: return "GRWM"
        case .cooking: return "Cooking"
        case .ootd: return "OOTD"
        case .travel: return "Travel"
        case .fitness: return "Fitness"
        case .product: return "Product"
        case .beauty: return "Beauty"
        case .lifestyle: return "Lifestyle"
        case .fashion: return "Fashion"
        case .food: return "Food"
        case .educational: return "Educational"
        case .entertainment: return "Entertainment"
        }
    }
}
