import Foundation

// MARK: - Protocol

protocol ExperimentRepository {
    func fetchExperiments() async throws -> [Experiment]
    func createExperiment(_ experiment: Experiment) async throws -> Experiment
    func startExperiment(id: UUID) async throws -> Experiment
    func stopExperiment(id: UUID) async throws -> Experiment
    func fetchResults(id: UUID) async throws -> ABTestResult
}

// MARK: - Mock Implementation

final class MockExperimentRepository: ExperimentRepository {
    private var experiments: [Experiment] = Experiment.mockList

    func fetchExperiments() async throws -> [Experiment] {
        experiments
    }

    func createExperiment(_ experiment: Experiment) async throws -> Experiment {
        experiments.insert(experiment, at: 0)
        return experiment
    }

    func startExperiment(id: UUID) async throws -> Experiment {
        guard let index = experiments.firstIndex(where: { $0.id == id }) else {
            throw ExperimentError.notFound
        }
        experiments[index].status = .running
        experiments[index].startDate = Date()
        return experiments[index]
    }

    func stopExperiment(id: UUID) async throws -> Experiment {
        guard let index = experiments.firstIndex(where: { $0.id == id }) else {
            throw ExperimentError.notFound
        }
        experiments[index].status = .completed
        experiments[index].endDate = Date()
        return experiments[index]
    }

    func fetchResults(id: UUID) async throws -> ABTestResult {
        guard let experiment = experiments.first(where: { $0.id == id }) else {
            throw ExperimentError.notFound
        }
        guard experiment.status == .completed else {
            throw ExperimentError.notCompleted
        }
        return ABTestResult.mock
    }
}

// MARK: - API Implementation

final class APIExperimentRepository: ExperimentRepository {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchExperiments() async throws -> [Experiment] {
        try await apiClient.request(
            endpoint: "experiments",
            method: .get,
            requiresAuth: true
        )
    }

    func createExperiment(_ experiment: Experiment) async throws -> Experiment {
        try await apiClient.request(
            endpoint: "experiments",
            method: .post,
            body: experiment,
            requiresAuth: true
        )
    }

    func startExperiment(id: UUID) async throws -> Experiment {
        try await apiClient.request(
            endpoint: "experiments/start",
            method: .post,
            body: ["id": id.uuidString],
            requiresAuth: true
        )
    }

    func stopExperiment(id: UUID) async throws -> Experiment {
        try await apiClient.request(
            endpoint: "experiments/stop",
            method: .post,
            body: ["id": id.uuidString],
            requiresAuth: true
        )
    }

    func fetchResults(id: UUID) async throws -> ABTestResult {
        try await apiClient.request(
            endpoint: "experiments/results",
            method: .get,
            requiresAuth: true
        )
    }
}

// MARK: - Error

enum ExperimentError: LocalizedError {
    case notFound
    case notCompleted

    var errorDescription: String? {
        switch self {
        case .notFound:     return "The requested experiment was not found."
        case .notCompleted: return "Results are only available for completed experiments."
        }
    }
}

// MARK: - Provider

enum ExperimentRepositoryProvider {
    static var shared = Shared(repository: defaultRepository())

    struct Shared {
        var repository: ExperimentRepository
    }

    private static func defaultRepository() -> ExperimentRepository {
        switch AppEnvironment.current {
        case .dev:
            return MockExperimentRepository()
        case .staging, .prod:
            return APIExperimentRepository()
        }
    }
}
