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
final class TemplateTabViewModel {

    // MARK: - Published state (via @Observable — no @Published needed)

    private(set) var populatedTemplates: [PopulatedTemplate] = []
    private(set) var trending: [PopulatedTemplate] = []
    private(set) var byCategory: [VideoTemplateCategory: [PopulatedTemplate]] = [:]
    private(set) var isLoading: Bool = false
    private(set) var scanProgress: MediaScanProgress = .idle
    private(set) var error: Error?
    private(set) var selectedCategory: VideoTemplateCategory? = nil  // nil = "All"

    // Phase 18-03: locally-hidden template ids. Persisted via
    // UserDefaultsManager so Hide survives app relaunches. Read into
    // `visibleTemplates` so the list filter is a derived property, not
    // a mutation of the underlying `populatedTemplates` store.
    private(set) var hiddenIDs: Set<String> = []

    // MARK: - Selection handoff (AsyncStream)
    //
    // The VM emits a picked template here; a coordinator / route layer
    // consumes via `for await populated in vm.selections { ... }` and
    // drives navigationDestination. Keeps the VM presentation-agnostic.

    var selections: AsyncStream<PopulatedTemplate> { selectionStream }
    private let selectionStream: AsyncStream<PopulatedTemplate>
    private let selectionContinuation: AsyncStream<PopulatedTemplate>.Continuation

    // MARK: - Dependencies

    private nonisolated(unsafe) let repo: VideoTemplateRepository
    private nonisolated(unsafe) let scanner: MediaScanCoordinator
    private let matcher: TemplateMatchEngine
    private let ranker: TemplateRanker
    private let cache: ClassificationCache
    private let index: EmbeddingIndex
    /// Injected UserDefaults shim so tests can use a fresh domain.
    /// Defaults to the shared singleton — production code stays unchanged.
    private let preferences: UserDefaultsManager

    private var progressSubscription: AnyCancellable?

    // MARK: - Init

    init(
        repo: VideoTemplateRepository,
        matcher: TemplateMatchEngine = TemplateMatchEngine(),
        ranker: TemplateRanker = TemplateRanker(),
        cache: ClassificationCache,
        index: EmbeddingIndex,
        scanner: MediaScanCoordinator,
        preferences: UserDefaultsManager = .shared
    ) {
        self.repo = repo
        self.matcher = matcher
        self.ranker = ranker
        self.cache = cache
        self.index = index
        self.scanner = scanner
        self.preferences = preferences
        // Phase 18-03: restore Hide preferences from disk before any render.
        self.hiddenIDs = preferences.hiddenTemplateIDs

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

    // MARK: - Visible / Hide filtering (Phase 18-03)

    /// `populatedTemplates` filtered by the locally-hidden ids. Views bind
    /// to this instead of `populatedTemplates` so Hide actually removes
    /// items from the visible grid. Source of truth remains
    /// `populatedTemplates` (so unhideAll can restore without a refetch).
    var visibleTemplates: [PopulatedTemplate] {
        populatedTemplates.filter { !hiddenIDs.contains($0.id.uuidString) }
    }

    /// Hide a template locally. Persists to UserDefaults so it survives
    /// relaunches. Local-only — we don't sync Hide to the server.
    func hide(_ populated: PopulatedTemplate) {
        hiddenIDs.insert(populated.id.uuidString)
        preferences.hiddenTemplateIDs = hiddenIDs
    }

    /// Restore all hidden templates. Future surfaces (a "show hidden"
    /// toggle) can call this; not wired to UI in 18-03 but kept here
    /// so the contract is symmetric.
    func unhideAll() {
        hiddenIDs.removeAll()
        preferences.hiddenTemplateIDs = hiddenIDs
    }

    /// Duplicate a template via the repo and prepend the clone to
    /// `populatedTemplates` so it appears in the grid immediately. The
    /// clone is populated via the matcher so its thumbnail + slot fill
    /// is consistent with other visible cards.
    ///
    /// Errors are surfaced via the existing `error` property so the
    /// banner shown for catalog load failures also covers this path.
    func duplicate(_ populated: PopulatedTemplate) async {
        do {
            let clone = try await repo.duplicate(templateID: populated.template.id)
            let populatedClone = await matcher.populate(
                template: clone,
                from: cache,
                using: index
            )
            populatedTemplates.insert(populatedClone, at: 0)
            // Keep the per-category bucket in sync so the clone appears
            // under its category row too.
            let category = populatedClone.template.category
            var bucket = byCategory[category] ?? []
            bucket.insert(populatedClone, at: 0)
            byCategory[category] = bucket
            self.error = nil
        } catch {
            self.error = error
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
    func refresh() async {
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
    func selectCategory(_ category: VideoTemplateCategory?) {
        self.selectedCategory = category
    }

    /// Swaps a slot's matched asset in a populated template.
    /// Delegates to `TemplateMatchEngine.swap` (actor-isolated) and
    /// re-publishes the mutated template in-place.
    func swap(
        slot: TemplateSlot,
        in populated: PopulatedTemplate,
        to asset: sending ClassifiedAsset
    ) async {
        let updated = await matcher.swap(slot: slot, in: populated, to: asset)
        replace(populated: updated)
    }

    /// Emits a chosen template into the selection AsyncStream for a
    /// coordinator to pick up (Phase 5 will present preview UI).
    func select(_ populated: sending PopulatedTemplate) {
        selectionContinuation.yield(populated)
    }

    // MARK: - Helpers

    private func performLazyRescan() async {
        _ = await scanner.lazyRescan()
    }

    // MARK: - Factory (Phase 4 — Task 4)

    /// Builds a `TemplateTabViewModel` wired with the repository
    /// selected by `FeatureFlags.shared.templateCatalogSource`.
    ///
    /// - `"lynx"` → `TemplateCatalogClient` (server manifest + Lynx bundle)
    /// - `"mock"` → `MockVideoTemplateRepository` (offline dev + tests)
    /// - anything else → assertion in DEBUG, fallback to mock in release
    ///   (fail-open emergency rollback path).
    ///
    /// Callers should not `TemplateTabViewModel(...)` directly from
    /// app code — go through this factory so the feature flag is
    /// always honored. Tests may continue to construct the VM
    /// directly with an injected repo.
    static func makeDefault(
        cache: ClassificationCache,
        index: EmbeddingIndex,
        scanner: MediaScanCoordinator
    ) -> TemplateTabViewModel {
        let repo: VideoTemplateRepository = resolveRepository(
            for: FeatureFlags.shared.templateCatalogSource
        )
        return TemplateTabViewModel(
            repo: repo,
            cache: cache,
            index: index,
            scanner: scanner
        )
    }

    /// Visible for testing — returns the repo instance that would be
    /// selected for a given flag value. Mirrors `makeDefault`'s
    /// switch so tests can assert the selection without building the
    /// full VM graph (which requires ClassificationCache + scanner).
    static func resolveRepository(for source: String) -> VideoTemplateRepository {
        switch source {
        case "lynx":
            return TemplateCatalogClient()
        case "mock":
            return MockVideoTemplateRepository()
        default:
            assertionFailure("Unknown templateCatalogSource: \(source)")
            return MockVideoTemplateRepository()
        }
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
