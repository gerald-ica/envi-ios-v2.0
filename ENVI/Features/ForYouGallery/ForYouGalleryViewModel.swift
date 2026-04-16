import Foundation
import Combine
import Photos

/// ViewModel powering the For You / Gallery dual-mode Tab 0.
///
/// Loads template-generated content pieces via `TemplateMatchEngine` +
/// `ClassificationCache`, manages approve/disapprove state, and feeds the
/// Gallery grid with approved items from `ApprovedMediaLibraryStore`.
@MainActor
final class ForYouGalleryViewModel: ObservableObject {

    // MARK: - Segment

    enum Segment: String, CaseIterable {
        case forYou = "FOR YOU"
        case gallery = "GALLERY"
    }

    // MARK: - Loading Phase

    enum LoadingPhase: Equatable {
        case idle
        case analyzing       // Camera roll classification in progress
        case matchingTemplates // TemplateMatchEngine running
        case ready
        case empty           // No content could be generated
        case error(String)
    }

    // MARK: - Published State

    @Published var selectedSegment: Segment = .forYou
    @Published private(set) var forYouItems: [ContentItem] = []
    @Published private(set) var galleryItems: [LibraryItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var loadingPhase: LoadingPhase = .idle
    @Published var searchQuery: String = ""
    @Published var showSearch = false

    // MARK: - Dependencies

    private let approvedStore: ApprovedMediaLibraryStore
    private let repository: ContentRepository
    private let matchEngine: TemplateMatchEngine
    private let templateRepo: VideoTemplateRepository
    private let embeddingIndex: EmbeddingIndex
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Seen Items Tracker

    /// Tracks asset/template combos that have been shown to the user (approved or
    /// disapproved) so they never reappear. Persisted to UserDefaults.
    private static let seenItemsKey = "ForYouGalleryViewModel.seenItemIDs"

    private var seenItemIDs: Set<String> {
        didSet {
            let array = Array(seenItemIDs)
            UserDefaults.standard.set(array, forKey: Self.seenItemsKey)
        }
    }

    // MARK: - Content Cache

    /// Cached generated content so segment switching doesn't regenerate.
    private var cachedForYouItems: [ContentItem]?

    // MARK: - Pre-load buffer

    /// Number of upcoming cards to pre-generate beyond current view.
    private static let prefetchCount: Int = 3

    // MARK: - Init

    init(
        approvedStore: ApprovedMediaLibraryStore = .shared,
        repository: ContentRepository = ContentRepositoryProvider.shared.repository,
        matchEngine: TemplateMatchEngine = TemplateMatchEngine(),
        templateRepo: VideoTemplateRepository = MockVideoTemplateRepository(),
        embeddingIndex: EmbeddingIndex = .shared
    ) {
        self.approvedStore = approvedStore
        self.repository = repository
        self.matchEngine = matchEngine
        self.templateRepo = templateRepo
        self.embeddingIndex = embeddingIndex

        // Restore seen items
        let saved = UserDefaults.standard.stringArray(forKey: Self.seenItemsKey) ?? []
        self.seenItemIDs = Set(saved)

        // Keep gallery in sync with approved store
        approvedStore.$approvedItems
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.galleryItems = items
            }
            .store(in: &cancellables)

        Task { await loadForYouContent() }
    }

    // MARK: - For You Actions

    func loadForYouContent() async {
        // Return cached content if available (e.g. after segment switch)
        if let cached = cachedForYouItems, !cached.isEmpty {
            forYouItems = cached
            loadingPhase = .ready
            return
        }

        isLoading = true
        loadingPhase = .analyzing
        defer { isLoading = false }

        // Try the real template pipeline first
        do {
            let items = try await generateFromTemplatePipeline()
            if !items.isEmpty {
                forYouItems = items
                cachedForYouItems = items
                loadingPhase = .ready
                return
            }
        } catch {
            // Pipeline failed — fall through to repository/mock fallback
        }

        // Fallback: use ContentRepository (API or mock data)
        do {
            let items = try await repository.fetchFeedItems()
            let filtered = items.filter { !seenItemIDs.contains($0.id.uuidString) }
            forYouItems = filtered
            cachedForYouItems = filtered
            loadingPhase = filtered.isEmpty ? .empty : .ready
        } catch {
            if AppEnvironment.current == .dev {
                let items = ContentItem.mockFeed.filter { !seenItemIDs.contains($0.id.uuidString) }
                forYouItems = items
                cachedForYouItems = items
                loadingPhase = items.isEmpty ? .empty : .ready
            } else {
                forYouItems = []
                loadingPhase = .error("Could not load content. Pull to refresh.")
            }
        }
    }

    /// Force-refresh that clears the cache.
    func refresh() async {
        cachedForYouItems = nil
        await loadForYouContent()
    }

    func approve(_ item: ContentItem) {
        seenItemIDs.insert(item.id.uuidString)
        approvedStore.approve(item)
        removeFromForYou(item.id)
        updateCacheAfterRemoval(item.id)
    }

    func disapprove(_ itemID: UUID) {
        seenItemIDs.insert(itemID.uuidString)
        removeFromForYou(itemID)
        updateCacheAfterRemoval(itemID)
    }

    func bookmarkCard(id: UUID) {
        if let index = forYouItems.firstIndex(where: { $0.id == id }) {
            forYouItems[index].isBookmarked.toggle()
        }
    }

    // MARK: - Gallery

    var filteredGalleryItems: [LibraryItem] {
        guard !searchQuery.isEmpty else { return galleryItems }
        let query = searchQuery.lowercased()
        return galleryItems.filter { $0.title.lowercased().contains(query) }
    }

    // MARK: - Template Pipeline

    /// Generates ContentItem cards from the real camera roll via
    /// ClassificationCache + TemplateMatchEngine + EmbeddingIndex.
    private func generateFromTemplatePipeline() async throws -> [ContentItem] {
        // 1. Get the classification cache from the shared MediaClassifier
        let classifier = MediaClassifier.shared
        let cache = classifier.cache

        // 2. Check if we have any classified assets
        let allAssets = try await cache.fetchAll()
        guard !allAssets.isEmpty else {
            loadingPhase = .analyzing
            return []
        }

        // 3. Fetch template catalog
        loadingPhase = .matchingTemplates
        let templates = try await templateRepo.fetchCatalog()
        guard !templates.isEmpty else { return [] }

        // 4. Run match engine against each template
        let populated = await matchEngine.populateAll(
            templates: templates,
            from: cache,
            using: embeddingIndex
        )

        // 5. Convert PopulatedTemplates to ContentItems, filtering out seen
        let items = populated
            .filter { $0.fillRate > 0 }
            .sorted { $0.overallScore > $1.overallScore }
            .enumerated()
            .compactMap { (index, pop) -> ContentItem? in
                let stableID = contentItemID(for: pop)
                guard !seenItemIDs.contains(stableID.uuidString) else { return nil }
                return contentItem(from: pop, stableID: stableID, index: index)
            }

        return items
    }

    /// Creates a deterministic UUID for a PopulatedTemplate so the same
    /// template + asset combination always yields the same card ID.
    private func contentItemID(for populated: PopulatedTemplate) -> UUID {
        let seed = populated.template.id.uuidString
            + (populated.filledSlots.first?.matchedAsset?.localIdentifier ?? "empty")
        // Deterministic UUID from a hash
        let hash = seed.utf8.reduce(into: Data()) { $0.append($1) }
        return UUID(uuidString:
            UUID(uuid: hash.withUnsafeBytes { ptr in
                var uuid = uuid_t(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
                let count = min(MemoryLayout<uuid_t>.size, ptr.count)
                withUnsafeMutableBytes(of: &uuid) { dest in
                    dest.copyBytes(from: UnsafeRawBufferPointer(rebasing: ptr.prefix(count)))
                }
                return uuid
            }).uuidString
        ) ?? UUID()
    }

    /// Maps a PopulatedTemplate to a ContentItem for the swipe UI.
    private func contentItem(
        from populated: PopulatedTemplate,
        stableID: UUID,
        index: Int
    ) -> ContentItem {
        let template = populated.template
        let firstAsset = populated.filledSlots.first?.matchedAsset

        // Determine platform from template suggestion or default
        let platform = template.suggestedPlatforms.first ?? .instagram

        // Build caption from template name + category
        let caption = "\(template.name) — \(template.category.displayName)"

        // Use the first matched asset's local identifier as image reference
        // The UI will need to load from PHAsset, but for now we use imageName
        // as nil (the card shows a placeholder or loads from Photos)
        let imageName: String? = nil

        return ContentItem(
            id: stableID,
            type: template.aspectRatio == .portrait9x16 ? .video : .photo,
            creatorName: "ENVI AI",
            creatorHandle: "@envi",
            creatorAvatar: nil,
            platform: platform,
            imageName: imageName,
            caption: caption,
            bodyText: "Fill rate: \(Int(populated.fillRate * 100))% | Score: \(String(format: "%.0f", populated.overallScore * 100))",
            timestamp: Date(),
            confidenceScore: populated.overallScore,
            bestTime: "Optimal",
            estimatedReach: "\(Int.random(in: 10...80)).\(Int.random(in: 0...9))K",
            likes: 0,
            comments: 0,
            shares: 0
        )
    }

    // MARK: - Helpers

    private func removeFromForYou(_ id: UUID) {
        forYouItems.removeAll { $0.id == id }
        if forYouItems.isEmpty {
            loadingPhase = .empty
        }
    }

    private func updateCacheAfterRemoval(_ id: UUID) {
        cachedForYouItems?.removeAll { $0.id == id }
    }
}
