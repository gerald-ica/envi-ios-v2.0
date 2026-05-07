import Foundation

// MARK: - Protocol

protocol DataPlatformRepository {
    func fetchEventSchemas() async throws -> [EventSchema]
    func fetchMLModels() async throws -> [MLModel]
    func fetchEvaluations() async throws -> [EvaluationResult]
    func fetchPromptTemplates() async throws -> [PromptTemplate]
    func fetchDataQuality() async throws -> [DataQualityCheck]
}

// MARK: - Mock Implementation

final class MockDataPlatformRepository: DataPlatformRepository {
    func fetchEventSchemas() async throws -> [EventSchema] {
        EventSchema.mock
    }

    func fetchMLModels() async throws -> [MLModel] {
        MLModel.mock
    }

    func fetchEvaluations() async throws -> [EvaluationResult] {
        EvaluationResult.mock
    }

    func fetchPromptTemplates() async throws -> [PromptTemplate] {
        PromptTemplate.mock
    }

    func fetchDataQuality() async throws -> [DataQualityCheck] {
        DataQualityCheck.mock
    }
}

// MARK: - API Implementation

final class APIDataPlatformRepository: DataPlatformRepository {
    func fetchEventSchemas() async throws -> [EventSchema] {
        let response: [EventSchemaResponse] = try await APIClient.shared.request(
            endpoint: "data-platform/schemas",
            method: .get,
            requiresAuth: true
        )
        return response.map { $0.toDomain() }
    }

    func fetchMLModels() async throws -> [MLModel] {
        let response: [MLModelResponse] = try await APIClient.shared.request(
            endpoint: "data-platform/ml-models",
            method: .get,
            requiresAuth: true
        )
        return response.map { $0.toDomain() }
    }

    func fetchEvaluations() async throws -> [EvaluationResult] {
        let response: [EvaluationResultResponse] = try await APIClient.shared.request(
            endpoint: "data-platform/evaluations",
            method: .get,
            requiresAuth: true
        )
        return response.map { $0.toDomain() }
    }

    func fetchPromptTemplates() async throws -> [PromptTemplate] {
        let response: [PromptTemplateResponse] = try await APIClient.shared.request(
            endpoint: "data-platform/prompt-templates",
            method: .get,
            requiresAuth: true
        )
        return response.map { $0.toDomain() }
    }

    func fetchDataQuality() async throws -> [DataQualityCheck] {
        let response: [DataQualityCheckResponse] = try await APIClient.shared.request(
            endpoint: "data-platform/data-quality",
            method: .get,
            requiresAuth: true
        )
        return response.map { $0.toDomain() }
    }
}

// MARK: - Provider

enum DataPlatformRepositoryProvider {
    nonisolated(unsafe) static var shared = RepositoryProvider<DataPlatformRepository>(
        dev: MockDataPlatformRepository(),
        api: APIDataPlatformRepository()
    )
}

// MARK: - API Response DTOs

private struct EventSchemaResponse: Decodable {
    let id: String
    let name: String
    let version: Int
    let fields: [String]

    func toDomain() -> EventSchema {
        EventSchema(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            version: version,
            fields: fields
        )
    }
}

private struct MLModelResponse: Decodable {
    let id: String
    let name: String
    let version: String
    let accuracy: Double
    let lastTrained: String
    let status: String

    func toDomain() -> MLModel {
        let date = ISO8601DateFormatter().date(from: lastTrained) ?? Date()
        return MLModel(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            version: version,
            accuracy: accuracy,
            lastTrained: date,
            status: MLModelStatus(rawValue: status) ?? .training
        )
    }
}

private struct EvaluationResultResponse: Decodable {
    let id: String
    let modelID: String
    let metric: String
    let score: Double
    let threshold: Double
    let passed: Bool

    func toDomain() -> EvaluationResult {
        EvaluationResult(
            id: UUID(uuidString: id) ?? UUID(),
            modelID: modelID,
            metric: metric,
            score: score,
            threshold: threshold,
            passed: passed
        )
    }
}

private struct PromptTemplateResponse: Decodable {
    let id: String
    let name: String
    let template: String
    let version: Int
    let evaluationScore: Double

    func toDomain() -> PromptTemplate {
        PromptTemplate(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            template: template,
            version: version,
            evaluationScore: evaluationScore
        )
    }
}

private struct DataQualityCheckResponse: Decodable {
    let id: String
    let table: String
    let checkType: String
    let status: String
    let lastRun: String

    func toDomain() -> DataQualityCheck {
        let date = ISO8601DateFormatter().date(from: lastRun) ?? Date()
        return DataQualityCheck(
            id: UUID(uuidString: id) ?? UUID(),
            table: table,
            checkType: checkType,
            status: DataQualityStatus(rawValue: status) ?? .pending,
            lastRun: date
        )
    }
}
