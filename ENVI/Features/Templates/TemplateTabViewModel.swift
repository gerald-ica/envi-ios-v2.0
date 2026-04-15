//
//  TemplateTabViewModel.swift
//  ENVI
//
//  Phase 3 — Task 4: SwiftUI-ready ViewModel for the Template tab.
//
//  Consumes Phase 3's engine (TemplateMatchEngine + TemplateRanker) over a
//  VideoTemplateRepository protocol, and mirrors MediaScanCoordinator
//  progress so the UI (Phase 5) can show "Analyzing your N photos…".
//
//  Design:
//    - @MainActor @Observable (iOS 26 / Swift 6.2 Observation macro) —
//      no ObservableObject / @Published; SwiftUI reads properties directly.
//    - Presentation-agnostic: selection is published via an AsyncStream
//      so a coordinator/route layer can `for await` picks and present
//      preview UI. No SwiftUI imports here.
//    - Graceful refresh: failures preserve previously-loaded templates;
//      scan failures are logged but do not block render.
//
//  Part of Phase 3 — Template Engine (Template Tab v1).
//

import Foundation
import Combine

@MainActor
@Observable
public final class TemplateTabViewModel {

    // MARK: - Published state (via @Observable — no @Published needed)

    public private(set) var populatedTemplates: [PopulatedTemplate] = []
    public private(set) var trending: [PopulatedTemplate] = []
    public private(set) var byCategory: [VideoTemplateCategory: [PopulatedTemplate]] = [:]
    public private(set) var isLoading: Bool = false
    public private(set) var scanProgress: MediaScanProgress = .idle
    public private(set) var error: Error?
    public private(set) var selectedCategory: VideoTemplateCategory? = nil  // nil = "All"

    // MARK: - Selection handoff (AsyncStream)
    //
    // The VM emits a picked template here; a coordinator / route layer
    // consumes via `for await populated in vm.selections { ... }` and
    // drives navigationDestination. Keeps the VM presentation-agnostic.

    public var selections: AsyncStream<PopulatedTemplate> { selectionStream }
    private let selectionStream: AsyncStream<PopulatedTemplate>
    private let selectionContinuation: AsyncStream<PopulatedTemplate>.Continuation

    // MARK: - Dependencies

    private let repo: VideoTemplateRepository
    private let matcher: TemplateMatchEngine
    private let ranker: TemplateRanker
    private let cache: ClassificationCache
    private let index: EmbeddingIndex
    private let scanner: MediaScanCoordinator

    private var progressSubscription: AnyCancellable?

    // MARK: - Init

    public init(
        repo: VideoTemplateRepository,
        matcher: TemplateMatchEngine = TemplateMatchEngine(),
        ranker: TemplateRanker = TemplateRanker(),
        cache: ClassificationCache,
        index: EmbeddingIndex,
        scanner: MediaScanCoordinator
    ) {
        self.repo = repo
        self.matcher = matcher
        self.ranker = ranker
        self.cache = cache
        self.index = index
        self.scanner = scanner

        var continuation: AsyncStream<PopulatedTemplate>.Continuation!
        self.selectionStream = AsyncStream { continuation = $0 }
        self.selectionContinuation = continuation

        // Mirror MediaScanCoordinator progress into our @Observable state
        // so SwiftUI observers see progress updates on the main actor.
        // Snapshot progress updates into the @Observable property on the
        // main actor. Use a Task hop so the closure remains Sendable under
        // Swift 6 strict concurrency.
        self.progressSubscription = scanner.$progress
            .sink { [weak self] next in
                Task { @MainActor [weak self] in
                    self?.scanProgress = next
                }
            }
    }

    deinit {
        selectionContinuation.finish()
    }

    // MARK: - Intents

    /// Triggers a lazy rescan (non-blocking for render) then reloads the
    /// catalog, populates all templates against the cache + index, ranks
    /// them, and publishes into the observable properties.
    ///
    /// On repo failure: sets `error`, keeps existing templates visible.
    /// On scan failure: logs, still proceeds with existing cache state.
    public func refresh() async {
        isLoading = true
        defer { isLoading = false }

        // 1. Catch new PHAssets. Don't block UI if this fails.
        await performLazyRescan()

        // 2. Fetch catalog. On failure, keep prior templates visible.
        let templates: [VideoTemplate]
        do {
            templates = try await repo.fetchCatalog()
            self.error = nil
        } catch {
            self.error = error
            return
        }

        // 3. Populate + rank off the main actor.
        let populated = await matcher.populateAll(
            templates: templates,
            from: cache,
            using: index
        )
        let ranked = ranker.rank(populated)

        // 4. Fetch trending (best-effort — failure non-fatal).
        var trendingRanked: [PopulatedTemplate] = []
        if let trendingTemplates = try? await repo.fetchTrending() {
            let trendingPopulated = await matcher.populateAll(
                templates: trendingTemplates,
                from: cache,
                using: index
            )
            trendingRanked = ranker.rank(trendingPopulated)
        }

        // 5. Publish.
        self.populatedTemplates = ranked
        self.trending = trendingRanked
        self.byCategory = Dictionary(grouping: ranked, by: { $0.template.category })
    }

    /// Filters the visible templates by category (nil = "All").
    public func selectCategory(_ category: VideoTemplateCategory?) {
        self.selectedCategory = category
    }

    /// Swaps a slot's matched asset in a populated template.
    /// Delegates to `TemplateMatchEngine.swap` (actor-isolated) and
    /// re-publishes the mutated template in-place.
    public func swap(
        slot: TemplateSlot,
        in populated: PopulatedTemplate,
        to asset: ClassifiedAsset
    ) async {
        let updated = await matcher.swap(slot: slot, in: populated, to: asset)
        replace(populated: updated)
    }

    /// Emits a chosen template into the selection AsyncStream for a
    /// coordinator to pick up (Phase 5 will present preview UI).
    public func select(_ populated: PopulatedTemplate) {
        selectionContinuation.yield(populated)
    }

    // MARK: - Helpers

    private func performLazyRescan() async {
        _ = await scanner.lazyRescan()
    }

    private func replace(populated: PopulatedTemplate) {
        if let idx = populatedTemplates.firstIndex(where: { $0.id == populated.id }) {
            populatedTemplates[idx] = populated
        }
        if let idx = trending.firstIndex(where: { $0.id == populated.id }) {
            trending[idx] = populated
        }
        let category = populated.template.category
        if var bucket = byCategory[category],
           let idx = bucket.firstIndex(where: { $0.id == populated.id }) {
            bucket[idx] = populated
            byCategory[category] = bucket
        }
    }
}
