import Foundation

// MARK: - Protocol

protocol AIVisualRepository {
    func requestEdit(request: AIEditRequest) async throws -> AIEditResult
    func fetchEditHistory() async throws -> [AIEditResult]
    func fetchStylePresets() async throws -> [StylePreset]
    func generateImage(prompt: String, dimensions: ImageDimensions) async throws -> GeneratedImage
    func fetchGeneratedImages() async throws -> [GeneratedImage]
}

// MARK: - Mock Implementation

final class MockAIVisualRepository: AIVisualRepository {

    func requestEdit(request: AIEditRequest) async throws -> AIEditResult {
        try await simulateDelay()
        guard let editType = AIEditType(rawValue: request.editType) else {
            throw AIVisualError.editFailed
        }
        return AIEditResult(
            originalURL: URL(string: "https://example.com/assets/\(request.sourceAssetID).jpg")!,
            editedURL: URL(string: "https://example.com/assets/\(request.sourceAssetID)_edited.jpg")!,
            editType: editType,
            confidence: Double.random(in: 0.85...0.99)
        )
    }

    func fetchEditHistory() async throws -> [AIEditResult] {
        try await simulateDelay()
        return AIEditResult.mockList
    }

    func fetchStylePresets() async throws -> [StylePreset] {
        try await simulateDelay()
        return StylePreset.mockList
    }

    func generateImage(prompt: String, dimensions: ImageDimensions) async throws -> GeneratedImage {
        try await simulateDelay()
        return GeneratedImage(
            prompt: prompt,
            imageURL: URL(string: "https://example.com/generated/\(UUID().uuidString).jpg")!,
            dimensions: dimensions,
            seed: Int.random(in: 1...99999)
        )
    }

    func fetchGeneratedImages() async throws -> [GeneratedImage] {
        try await simulateDelay()
        return GeneratedImage.mockList
    }

    private func simulateDelay() async throws {
        try await Task.sleep(for: .seconds(Double.random(in: 0.5...1.5)))
    }
}

// MARK: - API Implementation

final class APIAIVisualRepository: AIVisualRepository {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func requestEdit(request: AIEditRequest) async throws -> AIEditResult {
        try await apiClient.request(
            endpoint: "ai/visual/edit",
            method: .post,
            body: request,
            requiresAuth: true
        )
    }

    func fetchEditHistory() async throws -> [AIEditResult] {
        try await apiClient.request(
            endpoint: "ai/visual/history",
            method: .get,
            requiresAuth: true
        )
    }

    func fetchStylePresets() async throws -> [StylePreset] {
        try await apiClient.request(
            endpoint: "ai/visual/styles",
            method: .get,
            requiresAuth: true
        )
    }

    func generateImage(prompt: String, dimensions: ImageDimensions) async throws -> GeneratedImage {
        try await apiClient.request(
            endpoint: "ai/visual/generate",
            method: .post,
            body: GenerateImageRequest(prompt: prompt, dimensions: dimensions.rawValue),
            requiresAuth: true
        )
    }

    func fetchGeneratedImages() async throws -> [GeneratedImage] {
        try await apiClient.request(
            endpoint: "ai/visual/generate",
            method: .get,
            requiresAuth: true
        )
    }
}

// MARK: - Error

enum AIVisualError: LocalizedError {
    case editFailed
    case generationFailed
    case emptyPrompt
    case noSourceImage

    var errorDescription: String? {
        switch self {
        case .editFailed:       return "AI visual edit failed. Please try again."
        case .generationFailed: return "Image generation failed. Please try again."
        case .emptyPrompt:      return "Please enter a prompt to generate an image."
        case .noSourceImage:    return "Please select a source image first."
        }
    }
}

// MARK: - Provider

enum AIVisualRepositoryProvider {
    static var shared = Shared(repository: defaultRepository())

    struct Shared {
        var repository: AIVisualRepository
    }

    private static func defaultRepository() -> AIVisualRepository {
        switch AppEnvironment.current {
        case .dev:
            return MockAIVisualRepository()
        case .staging, .prod:
            return APIAIVisualRepository()
        }
    }
}
