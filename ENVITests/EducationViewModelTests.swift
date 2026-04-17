//
//  EducationViewModelTests.swift
//  ENVITests
//
//  Phase 17 — Plan 03. Pins the contract that EducationViewModel no longer
//  defaults to `Tutorial.mock` / `LearningPath.mock` / `AchievementBadge.mock`
//  in production, and that it correctly populates state from the injected
//  repository (and surfaces an error message on failure rather than silently
//  falling back to mocks).
//

import XCTest
@testable import ENVI

@MainActor
final class EducationViewModelTests: XCTestCase {

    // MARK: - Test Doubles

    /// Spyable repository used across tests. Separate from
    /// `MockEducationRepository` to give tests full control over the
    /// payloads returned and to exercise error paths.
    final class StubRepository: EducationRepository {
        var tutorials: [Tutorial] = []
        var paths: [LearningPath] = []
        var badges: [AchievementBadge] = []
        var tips: [CoachingTip] = []
        var shouldThrow: Bool = false

        struct BoomError: Error {}

        func fetchTutorials() async throws -> [Tutorial] {
            if shouldThrow { throw BoomError() }
            return tutorials
        }

        func fetchCoachingTips(context: CoachingTip.Context?) async throws -> [CoachingTip] {
            if shouldThrow { throw BoomError() }
            guard let context else { return tips }
            return tips.filter { $0.context == context }
        }

        func fetchAchievements() async throws -> [AchievementBadge] {
            if shouldThrow { throw BoomError() }
            return badges
        }

        func fetchLearningPaths() async throws -> [LearningPath] {
            if shouldThrow { throw BoomError() }
            return paths
        }
    }

    // MARK: - Tests

    /// v1.2 Audit finding: Education views were rendering `Tutorial.mock` /
    /// `LearningPath.mock` / `AchievementBadge.mock` by default because the
    /// views held those mocks as `@State` defaults. The VM must start empty
    /// so a regression surfaces as an empty UI, not silently-shipped mocks.
    func testDefaultStateIsEmpty() {
        let vm = EducationViewModel(repository: StubRepository())
        XCTAssertTrue(vm.tutorials.isEmpty, "EducationViewModel should start with no tutorials.")
        XCTAssertTrue(vm.learningPaths.isEmpty, "EducationViewModel should start with no learning paths.")
        XCTAssertTrue(vm.achievements.isEmpty, "EducationViewModel should start with no achievements.")
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    /// `loadTutorials()` must populate tutorials + learning paths from the
    /// repository and clear the loading flag.
    func testLoadTutorialsPopulatesFromRepo() async {
        let repo = StubRepository()
        repo.tutorials = Tutorial.mock
        repo.paths = LearningPath.mock

        let vm = EducationViewModel(repository: repo)
        await vm.loadTutorials()

        XCTAssertEqual(vm.tutorials.count, Tutorial.mock.count)
        XCTAssertEqual(vm.learningPaths.count, LearningPath.mock.count)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    /// `loadAchievements()` must populate achievements from the repository.
    func testLoadAchievementsPopulatesFromRepo() async {
        let repo = StubRepository()
        repo.badges = AchievementBadge.mock

        let vm = EducationViewModel(repository: repo)
        await vm.loadAchievements()

        XCTAssertEqual(vm.achievements.count, AchievementBadge.mock.count)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    /// When the repository throws we must surface an `errorMessage` and
    /// NOT silently fall back to mock data — that was the audit's whole
    /// concern with the old mock-in-@State pattern.
    func testLoadTutorialsErrorSetsErrorMessage() async {
        let repo = StubRepository()
        repo.shouldThrow = true

        let vm = EducationViewModel(repository: repo)
        await vm.loadTutorials()

        XCTAssertNotNil(vm.errorMessage, "An error from the repo must populate errorMessage.")
        XCTAssertFalse(vm.isLoading)
        XCTAssertTrue(vm.tutorials.isEmpty, "Tutorials must stay empty on error, NOT fall back to mocks.")
        XCTAssertTrue(vm.learningPaths.isEmpty)
    }
}
