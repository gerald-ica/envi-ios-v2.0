import Foundation

// MARK: - Protocol

protocol EducationRepository {
    func fetchTutorials() async throws -> [Tutorial]
    func fetchCoachingTips(context: CoachingTip.Context?) async throws -> [CoachingTip]
    func fetchAchievements() async throws -> [AchievementBadge]
    func fetchLearningPaths() async throws -> [LearningPath]
}

// MARK: - Mock Implementation

final class MockEducationRepository: EducationRepository {
    func fetchTutorials() async throws -> [Tutorial] {
        Tutorial.mock
    }

    func fetchCoachingTips(context: CoachingTip.Context?) async throws -> [CoachingTip] {
        guard let context else { return CoachingTip.mock }
        return CoachingTip.mock.filter { $0.context == context }
    }

    func fetchAchievements() async throws -> [AchievementBadge] {
        AchievementBadge.mock
    }

    func fetchLearningPaths() async throws -> [LearningPath] {
        LearningPath.mock
    }
}

// MARK: - API Implementation

final class APIEducationRepository: EducationRepository {
    func fetchTutorials() async throws -> [Tutorial] {
        let response: [TutorialResponse] = try await APIClient.shared.request(
            endpoint: "education/tutorials",
            method: .get,
            requiresAuth: true
        )
        return response.map { $0.toDomain() }
    }

    func fetchCoachingTips(context: CoachingTip.Context?) async throws -> [CoachingTip] {
        var endpoint = "education/coaching-tips"
        if let context {
            endpoint += buildQuery(["context": context.rawValue])
        }
        let response: [CoachingTipResponse] = try await APIClient.shared.request(
            endpoint: endpoint,
            method: .get,
            requiresAuth: true
        )
        return response.map { $0.toDomain() }
    }

    func fetchAchievements() async throws -> [AchievementBadge] {
        let response: [AchievementBadgeResponse] = try await APIClient.shared.request(
            endpoint: "education/achievements",
            method: .get,
            requiresAuth: true
        )
        return response.map { $0.toDomain() }
    }

    func fetchLearningPaths() async throws -> [LearningPath] {
        let response: [LearningPathResponse] = try await APIClient.shared.request(
            endpoint: "education/learning-paths",
            method: .get,
            requiresAuth: true
        )
        return response.map { $0.toDomain() }
    }

    private func buildQuery(_ params: [String: String]) -> String {
        buildQueryString(params)
    }
}

// MARK: - Provider

enum EducationRepositoryProvider {
    static var shared = RepositoryProvider<EducationRepository>(
        dev: MockEducationRepository(),
        api: APIEducationRepository()
    )
}

// MARK: - API Response DTOs

private struct TutorialStepResponse: Decodable {
    let title: String
    let description: String
    let actionType: String

    func toDomain() -> TutorialStep {
        TutorialStep(
            title: title,
            description: description,
            actionType: TutorialStep.ActionType(rawValue: actionType) ?? .tap
        )
    }
}

private struct TutorialResponse: Decodable {
    let title: String
    let category: String
    let steps: [TutorialStepResponse]
    let completionRate: Double

    func toDomain() -> Tutorial {
        Tutorial(
            title: title,
            category: Tutorial.Category(rawValue: category) ?? .gettingStarted,
            steps: steps.map { $0.toDomain() },
            completionRate: completionRate
        )
    }
}

private struct CoachingTipResponse: Decodable {
    let title: String
    let message: String
    let context: String
    let priority: String

    func toDomain() -> CoachingTip {
        CoachingTip(
            title: title,
            message: message,
            context: CoachingTip.Context(rawValue: context) ?? .general,
            priority: CoachingTip.Priority(rawValue: priority) ?? .medium
        )
    }
}

private struct AchievementBadgeResponse: Decodable {
    let name: String
    let description: String
    let iconName: String
    let earnedAt: String?

    func toDomain() -> AchievementBadge {
        let date = earnedAt.flatMap { ISO8601DateFormatter().date(from: $0) }
        return AchievementBadge(
            name: name,
            description: description,
            iconName: iconName,
            earnedAt: date
        )
    }
}

private struct LearningPathResponse: Decodable {
    let name: String
    let tutorials: [TutorialResponse]
    let progress: Double

    func toDomain() -> LearningPath {
        LearningPath(
            name: name,
            tutorials: tutorials.map { $0.toDomain() },
            progress: progress
        )
    }
}
