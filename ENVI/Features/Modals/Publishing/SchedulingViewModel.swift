import SwiftUI
import Combine

/// ViewModel for scheduling, queue monitoring, and distribution management.
@MainActor
final class SchedulingViewModel: ObservableObject {

    // MARK: - Published State

    @Published var scheduledPosts: [ScheduledPost] = []
    @Published var publishQueue: PublishQueue = .empty
    @Published var publishResults: [PublishResult] = []
    @Published var recurringSchedules: [RecurringSchedule] = []
    @Published var distributionRules: [DistributionRule] = []

    @Published var selectedQueueTab: ScheduledPostStatus = .pending
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Private

    private nonisolated(unsafe) let repository: SchedulingRepository
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(repository: SchedulingRepository = SchedulingRepositoryProvider.shared.repository) {
        self.repository = repository
        Task { await reload() }
    }

    // MARK: - Computed

    var filteredPosts: [ScheduledPost] {
        scheduledPosts.filter { $0.status == selectedQueueTab }
    }

    var pendingPosts: [ScheduledPost] {
        scheduledPosts.filter { $0.status == .pending }
    }

    var failedPosts: [ScheduledPost] {
        scheduledPosts.filter { $0.status == .failed }
    }

    // MARK: - Actions

    @MainActor
    func reload() async {
        isLoading = true
        errorMessage = nil

        let calendar = Calendar.current
        let start = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let end = calendar.date(byAdding: .month, value: 2, to: Date()) ?? Date()
        let range = DateInterval(start: start, end: end)

        do {
            async let postsTask = repository.fetchScheduledPosts(range: range)
            async let queueTask = repository.fetchPublishQueue()
            async let recurringTask = repository.fetchRecurringSchedules()
            async let rulesTask = repository.fetchDistributionRules()

            let (fetchedPosts, fetchedQueue, fetchedRecurring, fetchedRules) =
                try await (postsTask, queueTask, recurringTask, rulesTask)

            scheduledPosts = fetchedPosts
            publishQueue = fetchedQueue
            recurringSchedules = fetchedRecurring
            distributionRules = fetchedRules
        } catch {
            if AppEnvironment.current == .dev {
                scheduledPosts = ScheduledPost.mockPosts
                publishQueue = .mock
                recurringSchedules = RecurringSchedule.mock
                distributionRules = DistributionRule.mock
            } else {
                errorMessage = "Unable to load scheduling data."
            }
        }

        isLoading = false
    }

    @MainActor
    func createPost(_ post: ScheduledPost) async {
        do {
            let created = try await repository.createScheduledPost(post)
            scheduledPosts.append(created)
            await refreshQueue()
        } catch {
            errorMessage = "Failed to create scheduled post."
        }
    }

    @MainActor
    func updatePost(_ post: ScheduledPost) async {
        do {
            let updated = try await repository.updateScheduledPost(post)
            if let index = scheduledPosts.firstIndex(where: { $0.id == updated.id }) {
                scheduledPosts[index] = updated
            }
        } catch {
            errorMessage = "Failed to update scheduled post."
        }
    }

    @MainActor
    func cancelPost(_ post: ScheduledPost) async {
        let snapshot = scheduledPosts
        if let index = scheduledPosts.firstIndex(where: { $0.id == post.id }) {
            scheduledPosts[index].status = .cancelled
        }

        do {
            try await repository.cancelScheduledPost(id: post.id)
            await refreshQueue()
        } catch {
            scheduledPosts = snapshot
            errorMessage = "Could not cancel post."
        }
    }

    @MainActor
    func retryPost(_ post: ScheduledPost) async {
        do {
            let retried = try await repository.retryFailedPost(id: post.id)
            if let index = scheduledPosts.firstIndex(where: { $0.id == retried.id }) {
                scheduledPosts[index] = retried
            }
            await refreshQueue()
        } catch {
            errorMessage = "Failed to retry post."
        }
    }

    @MainActor
    func loadResults(for jobID: String) async {
        do {
            publishResults = try await repository.fetchPublishResults(jobID: jobID)
        } catch {
            if AppEnvironment.current == .dev {
                publishResults = PublishResult.mock
            } else {
                errorMessage = "Failed to load publish results."
            }
        }
    }

    @MainActor
    func createRecurring(_ schedule: RecurringSchedule) async {
        do {
            let created = try await repository.createRecurringSchedule(schedule)
            recurringSchedules.append(created)
        } catch {
            errorMessage = "Failed to create recurring schedule."
        }
    }

    @MainActor
    func deleteRecurring(_ schedule: RecurringSchedule) async {
        let snapshot = recurringSchedules
        recurringSchedules.removeAll { $0.id == schedule.id }

        do {
            try await repository.deleteRecurringSchedule(id: schedule.id)
        } catch {
            recurringSchedules = snapshot
            errorMessage = "Failed to delete recurring schedule."
        }
    }

    @MainActor
    func updateDistributionRule(_ rule: DistributionRule) async {
        do {
            let updated = try await repository.updateDistributionRule(rule)
            if let index = distributionRules.firstIndex(where: { $0.id == updated.id }) {
                distributionRules[index] = updated
            }
        } catch {
            errorMessage = "Failed to update distribution rule."
        }
    }

    // MARK: - Private

    @MainActor
    private func refreshQueue() async {
        do {
            publishQueue = try await repository.fetchPublishQueue()
        } catch {
            // Non-critical; keep existing queue data
        }
    }
}
