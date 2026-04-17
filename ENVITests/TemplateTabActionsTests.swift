//
//  TemplateTabActionsTests.swift
//  ENVITests
//
//  Phase 18 — Plan 03. Pins the contract that the `onDuplicate` and
//  `onHide` handlers on TemplateTabView (formerly TODO-only closures at
//  TemplateTabView.swift:231-232) now reach `VideoTemplateRepository`
//  and `UserDefaultsManager` respectively.
//
//  We exercise the VM directly rather than SwiftUI's view tree — the
//  context-menu is a thin pass-through to `viewModel.duplicate(...)`
//  and `viewModel.hide(...)`, and the VM's @Observable state is the
//  load-bearing surface.
//

import XCTest
import Photos
@testable import ENVI

// MARK: - Shared test doubles (duplicated from TemplateTabViewModelTests
// because that suite is SPM-only; this suite is compiled into the Xcode
// test bundle per the Phase 17-era test-target convention).

/// Minimal classifier stub — MediaScanCoordinator's init requires one.
final class TemplateActionsStubClassifier: MediaClassifierProtocol, @unchecked Sendable {
    func classifyBatch(
        _ assets: [PHAsset],
        progress: ((Int, Int) -> Void)?
    ) async -> [ClassifiedAsset] { [] }

    func classify(
        _ asset: PHAsset,
        priority: TaskPriority
    ) async throws -> ClassifiedAsset {
        throw NSError(domain: "StubMediaClassifier", code: -1)
    }
}

/// Empty PHAsset provider — lazyRescan() is a no-op under this.
final class TemplateActionsEmptyAssetProvider: PHAssetProviding, @unchecked Sendable {
    func fetchRecentMedia(limit: Int, mediaTypes: [PHAssetMediaType]) -> [PHAsset] { [] }
    func totalMediaCount() -> Int { 0 }
}

@MainActor
final class TemplateTabActionsTests: XCTestCase {

    // MARK: - Test doubles

    /// Spyable repo records every duplicate call + lets tests inject a
    /// canned response via `catalog`. Mirrors the SpyRepository in
    /// TemplateTabViewModelTests (SPM-only) but lives here so the Xcode
    /// ENVITests bundle can compile these assertions.
    final class SpyRepository: VideoTemplateRepository {
        var catalog: [VideoTemplate] = []
        var trending: [VideoTemplate] = []
        private(set) var duplicateCalls: [UUID] = []
        var shouldThrow: Bool = false
        struct BoomError: Error {}

        func fetchCatalog() async throws -> [VideoTemplate] {
            if shouldThrow { throw BoomError() }
            return catalog
        }
        func fetchTrending() async throws -> [VideoTemplate] {
            if shouldThrow { throw BoomError() }
            return trending
        }
        func fetchByCategory(_ category: VideoTemplateCategory) async throws -> [VideoTemplate] {
            if shouldThrow { throw BoomError() }
            return catalog.filter { $0.category == category }
        }
        func duplicate(templateID: UUID) async throws -> VideoTemplate {
            duplicateCalls.append(templateID)
            if shouldThrow { throw BoomError() }
            let source = catalog.first(where: { $0.id == templateID })
                ?? catalog.first
                ?? VideoTemplate(name: "Untitled", category: .grwm, aspectRatio: .portrait9x16)
            return VideoTemplate(
                id: UUID(),
                name: "\(source.name) Copy",
                category: source.category,
                aspectRatio: source.aspectRatio,
                duration: source.duration,
                slots: source.slots,
                textOverlays: source.textOverlays,
                transitions: source.transitions,
                audioTrack: source.audioTrack,
                suggestedPlatforms: source.suggestedPlatforms,
                thumbnailURL: source.thumbnailURL,
                popularity: source.popularity
            )
        }
    }

    // MARK: - Fixtures

    private func makeScanner(cache: ClassificationCache) -> MediaScanCoordinator {
        MediaScanCoordinator(
            classifier: TemplateActionsStubClassifier(),
            cache: cache,
            library: TemplateActionsEmptyAssetProvider(),
            defaults: UserDefaults(suiteName: "TemplateActionsTests-\(UUID().uuidString)")!
        )
    }

    private func makeVM(
        repo: SpyRepository,
        preferences: UserDefaultsManager = .shared
    ) throws -> TemplateTabViewModel {
        let cache = try ClassificationCache(inMemory: true)
        let index = EmbeddingIndex()
        let scanner = makeScanner(cache: cache)
        return TemplateTabViewModel(
            repo: repo,
            cache: cache,
            index: index,
            scanner: scanner,
            preferences: preferences
        )
    }

    private func makePopulated(_ template: VideoTemplate) -> PopulatedTemplate {
        PopulatedTemplate(
            template: template,
            filledSlots: [],
            fillRate: 0,
            overallScore: 0
        )
    }

    override func setUp() async throws {
        try await super.setUp()
        // Tests touch the shared UserDefaults — clear the Phase 18-03 key
        // so stale state from a previous run can't leak into assertions.
        UserDefaultsManager.shared.hiddenTemplateIDs = []
    }

    override func tearDown() async throws {
        UserDefaultsManager.shared.hiddenTemplateIDs = []
        try await super.tearDown()
    }

    // MARK: - Tests

    /// `vm.duplicate(populated)` must call `repo.duplicate(templateID:)`
    /// exactly once with the source template's id, and prepend the clone
    /// to `populatedTemplates` so the UI gets a new card to render.
    /// Audit Wave 2 finding: the context menu's Duplicate action was a
    /// TODO-only closure at TemplateTabView:231 — this pins the fix.
    func testDuplicateCallsRepoAndAppendsClone() async throws {
        let repo = SpyRepository()
        let source = VideoTemplate.mockLibrary[0]
        repo.catalog = [source]
        let vm = try makeVM(repo: repo)

        await vm.refresh() // populate templates[0] from catalog
        let before = vm.populatedTemplates.count
        XCTAssertEqual(repo.duplicateCalls.count, 0, "Baseline — no duplicate calls yet.")

        await vm.duplicate(makePopulated(source))

        XCTAssertEqual(repo.duplicateCalls, [source.id],
            "vm.duplicate must call repo.duplicate(templateID:) with the source template's id.")
        XCTAssertEqual(vm.populatedTemplates.count, before + 1,
            "The clone must be prepended to populatedTemplates.")
        XCTAssertTrue(
            vm.populatedTemplates.first?.template.name.hasSuffix(" Copy") ?? false,
            "The clone's name should suffix with ' Copy' (matches repo contract)."
        )
    }

    /// `vm.hide(...)` must persist to UserDefaults so a fresh VM
    /// instance restores the hidden set on launch. Audit finding:
    /// Hide used to be a TODO at TemplateTabView:232; this pins that
    /// hidden ids round-trip through UserDefaults.
    func testHidePersistsAcrossVMInstances() async throws {
        let repo = SpyRepository()
        let source = VideoTemplate.mockLibrary[0]
        repo.catalog = [source]
        let vm1 = try makeVM(repo: repo)
        await vm1.refresh()
        let populated = vm1.populatedTemplates[0]

        vm1.hide(populated)
        XCTAssertTrue(vm1.hiddenIDs.contains(populated.id.uuidString),
            "In-memory set must reflect the hide immediately.")

        // Simulate relaunch — a new VM reads the same UserDefaults shim.
        let vm2 = try makeVM(repo: repo)
        XCTAssertTrue(vm2.hiddenIDs.contains(populated.id.uuidString),
            "A freshly-constructed VM must restore hidden ids from UserDefaults.")
    }

    /// `visibleTemplates` must exclude ids that have been hidden. This
    /// is the derived property the view binds to so Hide actually
    /// removes the card from the grid.
    func testVisibleTemplatesExcludesHidden() async throws {
        let repo = SpyRepository()
        repo.catalog = Array(VideoTemplate.mockLibrary.prefix(5))
        let vm = try makeVM(repo: repo)
        await vm.refresh()
        XCTAssertEqual(vm.populatedTemplates.count, 5)
        XCTAssertEqual(vm.visibleTemplates.count, 5, "All 5 visible baseline.")

        let hideTarget = vm.populatedTemplates[2]
        vm.hide(hideTarget)

        XCTAssertEqual(vm.visibleTemplates.count, 4,
            "Hiding one template must drop visibleTemplates by exactly one.")
        XCTAssertFalse(vm.visibleTemplates.contains(where: { $0.id == hideTarget.id }),
            "The hidden template must be absent from the visible set.")
        XCTAssertEqual(vm.populatedTemplates.count, 5,
            "Source-of-truth populatedTemplates stays intact (for unhideAll).")
    }

    /// `unhideAll()` must clear the hidden set AND its UserDefaults
    /// persistence so a relaunched VM sees everything again. Kept in
    /// scope for the future "show hidden" toggle.
    func testUnhideAllClearsSetAndPersistence() async throws {
        let repo = SpyRepository()
        let source = VideoTemplate.mockLibrary[0]
        repo.catalog = [source]
        let vm1 = try makeVM(repo: repo)
        await vm1.refresh()

        vm1.hide(vm1.populatedTemplates[0])
        XCTAssertFalse(vm1.hiddenIDs.isEmpty)

        vm1.unhideAll()
        XCTAssertTrue(vm1.hiddenIDs.isEmpty)

        let vm2 = try makeVM(repo: repo)
        XCTAssertTrue(vm2.hiddenIDs.isEmpty,
            "unhideAll must clear persistence — a fresh VM sees no hidden ids.")
    }
}
