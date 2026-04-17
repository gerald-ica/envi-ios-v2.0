//
//  SchedulingViewModelTests.swift
//  ENVITests
//
//  Phase 19 — Plan 04. Baseline coverage for the Publishing tab's VM.
//  Pins default-empty, load-populates, and error handling. Matches the
//  house pattern used by GrowthViewModelTests / EducationViewModelTests.
//

import XCTest
@testable import ENVI

@MainActor
final class SchedulingViewModelTests: XCTestCase {

    // MARK: - Test Doubles

    final class StubSchedulingRepository: SchedulingRepository {
        var posts: [ScheduledPost] = []
        var queue: PublishQueue = .empty
        var recurring: [RecurringSchedule] = []
        var rules: [DistributionRule] = []
        var results: [PublishResult] = []
        var shouldThrow = false
        struct BoomError: Error {}

        func fetchScheduledPosts(range: DateInterval) async throws -> [ScheduledPost] {
            if shouldThrow { throw BoomError() }
            return posts
        }
        func createScheduledPost(_ post: ScheduledPost) async throws -> ScheduledPost {
            if shouldThrow { throw BoomError() }
            return post
        }
        func updateScheduledPost(_ post: ScheduledPost) async throws -> ScheduledPost {
            if shouldThrow { throw BoomError() }
            return post
        }
        func cancelScheduledPost(id: UUID) async throws {
            if shouldThrow { throw BoomError() }
        }
        func retryFailedPost(id: UUID) async throws -> ScheduledPost {
            if shouldThrow { throw BoomError() }
            return posts.first ?? ScheduledPost.mockPosts.first!
        }
        func fetchPublishQueue() async throws -> PublishQueue {
            if shouldThrow { throw BoomError() }
            return queue
        }
        func fetchPublishResults(jobID: String) async throws -> [PublishResult] {
            if shouldThrow { throw BoomError() }
            return results
        }
        func fetchRecurringSchedules() async throws -> [RecurringSchedule] {
            if shouldThrow { throw BoomError() }
            return recurring
        }
        func createRecurringSchedule(_ schedule: RecurringSchedule) async throws -> RecurringSchedule {
            if shouldThrow { throw BoomError() }
            return schedule
        }
        func deleteRecurringSchedule(id: UUID) async throws {
            if shouldThrow { throw BoomError() }
        }
        func fetchDistributionRules() async throws -> [DistributionRule] {
            if shouldThrow { throw BoomError() }
            return rules
        }
        func updateDistributionRule(_ rule: DistributionRule) async throws -> DistributionRule {
            if shouldThrow { throw BoomError() }
            return rule
        }
    }

    // MARK: - Tests

    /// Default state: no posts, no queue, no recurring schedules, no rules,
    /// not loading, no error.
    func testDefaultStateIsEmpty() {
        let vm = SchedulingViewModel(repository: StubSchedulingRepository())
        XCTAssertTrue(vm.scheduledPosts.isEmpty)
        XCTAssertTrue(vm.recurringSchedules.isEmpty)
        XCTAssertTrue(vm.distributionRules.isEmpty)
        XCTAssertEqual(vm.selectedQueueTab, .pending)
        XCTAssertNil(vm.errorMessage)
    }

    /// `reload()` populates all four slices from the repository.
    func testReloadPopulatesFromRepo() async {
        let repo = StubSchedulingRepository()
        repo.posts = ScheduledPost.mockPosts
        repo.queue = .mock
        repo.recurring = RecurringSchedule.mock
        repo.rules = DistributionRule.mock

        let vm = SchedulingViewModel(repository: repo)
        await vm.reload()

        XCTAssertEqual(vm.scheduledPosts.count, ScheduledPost.mockPosts.count)
        XCTAssertEqual(vm.recurringSchedules.count, RecurringSchedule.mock.count)
        XCTAssertEqual(vm.distributionRules.count, DistributionRule.mock.count)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    /// In dev, a repo failure must fall back to mock data (matching the
    /// house pattern). If that ever changes to prod-style error surfacing,
    /// the test forces a conscious update.
    func testReloadDevFallbackOnError() async throws {
        guard AppEnvironment.current == .dev else {
            throw XCTSkip("Dev fallback only applies in .dev AppEnvironment")
        }
        let repo = StubSchedulingRepository()
        repo.shouldThrow = true

        let vm = SchedulingViewModel(repository: repo)
        await vm.reload()

        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage, "Dev env should silently fall back to mock data.")
        XCTAssertFalse(vm.scheduledPosts.isEmpty, "Dev fallback populates ScheduledPost.mockPosts.")
    }
}
