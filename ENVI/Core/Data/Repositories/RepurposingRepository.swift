import Foundation

// MARK: - Protocol

protocol RepurposingRepository {
    func createRepurposeJob(_ job: RepurposeJob) async throws -> RepurposeJob
    func fetchJobs() async throws -> [RepurposeJob]
    func fetchSuggestions(assetID: UUID?) async throws -> [RepurposeSuggestion]
    func fetchCrossPostMappings() async throws -> [CrossPostMapping]
}

// MARK: - Mock Implementation

final class MockRepurposingRepository: RepurposingRepository {
    private var jobs: [RepurposeJob] = RepurposeJob.mockList

    func createRepurposeJob(_ job: RepurposeJob) async throws -> RepurposeJob {
        var created = job
        created.status = .processing
        jobs.insert(created, at: 0)
        return created
    }

    func fetchJobs() async throws -> [RepurposeJob] {
        jobs
    }

    func fetchSuggestions(assetID: UUID?) async throws -> [RepurposeSuggestion] {
        if let assetID {
            return RepurposeSuggestion.mockList.filter { $0.sourceAssetID == assetID }
        }
        return RepurposeSuggestion.mockList
    }

    func fetchCrossPostMappings() async throws -> [CrossPostMapping] {
        CrossPostMapping.mockList
    }
}

// MARK: - API Implementation

final class APIRepurposingRepository: RepurposingRepository {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func createRepurposeJob(_ job: RepurposeJob) async throws -> RepurposeJob {
        try await apiClient.request(
            endpoint: "repurposing/jobs",
            method: .post,
            body: job,
            requiresAuth: true
        )
    }

    func fetchJobs() async throws -> [RepurposeJob] {
        try await apiClient.request(
            endpoint: "repurposing/jobs",
            method: .get,
            requiresAuth: true
        )
    }

    func fetchSuggestions(assetID: UUID?) async throws -> [RepurposeSuggestion] {
        var endpoint = "repurposing/suggestions"
        if let assetID {
            endpoint += "?assetID=\(assetID.uuidString)"
        }
        return try await apiClient.request(
            endpoint: endpoint,
            method: .get,
            requiresAuth: true
        )
    }

    func fetchCrossPostMappings() async throws -> [CrossPostMapping] {
        try await apiClient.request(
            endpoint: "repurposing/cross-post",
            method: .get,
            requiresAuth: true
        )
    }
}

// MARK: - Error

enum RepurposingError: LocalizedError {
    case notFound
    case jobFailed

    var errorDescription: String? {
        switch self {
        case .notFound:   return "The requested repurposing item was not found."
        case .jobFailed:  return "The repurposing job failed. Please try again."
        }
    }
}

// MARK: - Provider

@MainActor
enum RepurposingRepositoryProvider {
    static nonisolated(unsafe) var shared = RepositoryProvider<RepurposingRepository>(
        dev: MockRepurposingRepository(),
        api: APIRepurposingRepository()
    )
}
