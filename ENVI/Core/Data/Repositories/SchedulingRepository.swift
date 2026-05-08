import Foundation

// MARK: - Protocol

protocol SchedulingRepository {
    func fetchScheduledPosts(range: DateInterval) async throws -> [ScheduledPost]
    func createScheduledPost(_ post: ScheduledPost) async throws -> ScheduledPost
    func updateScheduledPost(_ post: ScheduledPost) async throws -> ScheduledPost
    func cancelScheduledPost(id: UUID) async throws
    func fetchPublishQueue() async throws -> PublishQueue
    func fetchPublishResults(jobID: String) async throws -> [PublishResult]
    func retryFailedPost(id: UUID) async throws -> ScheduledPost
    func createRecurringSchedule(_ schedule: RecurringSchedule) async throws -> RecurringSchedule
    func deleteRecurringSchedule(id: UUID) async throws
    func fetchRecurringSchedules() async throws -> [RecurringSchedule]
    func fetchDistributionRules() async throws -> [DistributionRule]
    func updateDistributionRule(_ rule: DistributionRule) async throws -> DistributionRule
}

// MARK: - Mock

final class MockSchedulingRepository: SchedulingRepository {
    private var posts: [ScheduledPost] = ScheduledPost.mockPosts
    private var recurringSchedules: [RecurringSchedule] = RecurringSchedule.mock
    private var distributionRules: [DistributionRule] = DistributionRule.mock

    func fetchScheduledPosts(range: DateInterval) async throws -> [ScheduledPost] {
        posts.filter { range.contains($0.scheduledAt) }
    }

    func createScheduledPost(_ post: ScheduledPost) async throws -> ScheduledPost {
        posts.append(post)
        return post
    }

    func updateScheduledPost(_ post: ScheduledPost) async throws -> ScheduledPost {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else {
            throw SchedulingError.notFound
        }
        posts[index] = post
        return posts[index]
    }

    func cancelScheduledPost(id: UUID) async throws {
        guard let index = posts.firstIndex(where: { $0.id == id }) else {
            throw SchedulingError.notFound
        }
        posts[index].status = .cancelled
    }

    func fetchPublishQueue() async throws -> PublishQueue {
        .mock
    }

    func fetchPublishResults(jobID: String) async throws -> [PublishResult] {
        PublishResult.mock
    }

    func retryFailedPost(id: UUID) async throws -> ScheduledPost {
        guard let index = posts.firstIndex(where: { $0.id == id }) else {
            throw SchedulingError.notFound
        }
        posts[index].status = .pending
        return posts[index]
    }

    func createRecurringSchedule(_ schedule: RecurringSchedule) async throws -> RecurringSchedule {
        recurringSchedules.append(schedule)
        return schedule
    }

    func deleteRecurringSchedule(id: UUID) async throws {
        recurringSchedules.removeAll { $0.id == id }
    }

    func fetchRecurringSchedules() async throws -> [RecurringSchedule] {
        recurringSchedules
    }

    func fetchDistributionRules() async throws -> [DistributionRule] {
        distributionRules
    }

    func updateDistributionRule(_ rule: DistributionRule) async throws -> DistributionRule {
        guard let index = distributionRules.firstIndex(where: { $0.id == rule.id }) else {
            throw SchedulingError.notFound
        }
        distributionRules[index] = rule
        return distributionRules[index]
    }
}

// MARK: - API

final class APISchedulingRepository: SchedulingRepository {
    private let apiClient: APIClient
    private nonisolated(unsafe) static let iso = ISO8601DateFormatter()

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchScheduledPosts(range: DateInterval) async throws -> [ScheduledPost] {
        let start = Self.iso.string(from: range.start)
        let end = Self.iso.string(from: range.end)
        return try await apiClient.request(
            endpoint: "scheduling/posts?start=\(start)&end=\(end)",
            method: .get,
            requiresAuth: true
        )
    }

    func createScheduledPost(_ post: ScheduledPost) async throws -> ScheduledPost {
        try await apiClient.request(
            endpoint: "scheduling/posts",
            method: .post,
            body: post,
            requiresAuth: true
        )
    }

    func updateScheduledPost(_ post: ScheduledPost) async throws -> ScheduledPost {
        try await apiClient.request(
            endpoint: "scheduling/posts/\(post.id.uuidString)",
            method: .put,
            body: post,
            requiresAuth: true
        )
    }

    func cancelScheduledPost(id: UUID) async throws {
        try await apiClient.requestVoid(
            endpoint: "scheduling/posts/\(id.uuidString)/cancel",
            method: .post,
            body: EmptyBody(),
            requiresAuth: true
        )
    }

    func fetchPublishQueue() async throws -> PublishQueue {
        try await apiClient.request(
            endpoint: "scheduling/queue",
            method: .get,
            requiresAuth: true
        )
    }

    func fetchPublishResults(jobID: String) async throws -> [PublishResult] {
        try await apiClient.request(
            endpoint: "scheduling/posts/\(jobID)/results",
            method: .get,
            requiresAuth: true
        )
    }

    func retryFailedPost(id: UUID) async throws -> ScheduledPost {
        try await apiClient.request(
            endpoint: "scheduling/posts/\(id.uuidString)/retry",
            method: .post,
            body: EmptyBody(),
            requiresAuth: true
        )
    }

    func createRecurringSchedule(_ schedule: RecurringSchedule) async throws -> RecurringSchedule {
        try await apiClient.request(
            endpoint: "scheduling/recurring",
            method: .post,
            body: schedule,
            requiresAuth: true
        )
    }

    func deleteRecurringSchedule(id: UUID) async throws {
        try await apiClient.requestVoid(
            endpoint: "scheduling/recurring/\(id.uuidString)",
            method: .delete,
            body: EmptyBody(),
            requiresAuth: true
        )
    }

    func fetchRecurringSchedules() async throws -> [RecurringSchedule] {
        try await apiClient.request(
            endpoint: "scheduling/recurring",
            method: .get,
            requiresAuth: true
        )
    }

    func fetchDistributionRules() async throws -> [DistributionRule] {
        try await apiClient.request(
            endpoint: "scheduling/distribution",
            method: .get,
            requiresAuth: true
        )
    }

    func updateDistributionRule(_ rule: DistributionRule) async throws -> DistributionRule {
        try await apiClient.request(
            endpoint: "scheduling/distribution/\(rule.id.uuidString)",
            method: .put,
            body: rule,
            requiresAuth: true
        )
    }
}

// MARK: - Provider

@MainActor
enum SchedulingRepositoryProvider {
    static nonisolated(unsafe) var shared = RepositoryProvider<SchedulingRepository>(
        dev: MockSchedulingRepository(),
        api: APISchedulingRepository()
    )
}

// MARK: - Errors

enum SchedulingError: LocalizedError {
    case notFound
    case invalidSchedule
    case publishFailed(String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Scheduled post not found."
        case .invalidSchedule:
            return "Invalid schedule configuration."
        case .publishFailed(let reason):
            return "Publish failed: \(reason)"
        }
    }
}

// MARK: - Helpers

// Uses shared EmptyBody from RepositoryProvider.swift
