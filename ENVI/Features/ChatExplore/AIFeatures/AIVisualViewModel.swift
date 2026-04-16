import SwiftUI
import Combine

/// ViewModel for the AI Visual Editing and Generation domain.
final class AIVisualViewModel: ObservableObject {

    // MARK: - Editor State
    @Published var selectedEditType: AIEditType = .backgroundRemoval
    @Published var sourceAssetID: String = ""
    @Published var sourceImageURL: URL?
    @Published var editParameters: [String: String] = [:]
    @Published var currentEditResult: AIEditResult?
    @Published var editHistory: [AIEditResult] = []
    @Published var isApplyingEdit = false
    @Published var beforeAfterPosition: CGFloat = 0.5

    // MARK: - Style Transfer
    @Published var stylePresets: [StylePreset] = []
    @Published var selectedPreset: StylePreset?
    @Published var selectedCategory: StylePreset.StyleCategory?
    @Published var isLoadingPresets = false

    // MARK: - Image Generation
    @Published var generationPrompt = ""
    @Published var selectedDimensions: ImageDimensions = .square
    @Published var generatedImages: [GeneratedImage] = []
    @Published var isGeneratingImage = false

    // MARK: - General
    @Published var errorMessage: String?

    private let repository: AIVisualRepository

    init(repository: AIVisualRepository = AIVisualRepositoryProvider.shared.repository) {
        self.repository = repository
    }

    // MARK: - Filtered Style Presets

    var filteredPresets: [StylePreset] {
        guard let category = selectedCategory else { return stylePresets }
        return stylePresets.filter { $0.category == category }
    }

    // MARK: - Edit Operations

    @MainActor
    func applyEdit() async {
        guard !sourceAssetID.isEmpty else {
            errorMessage = AIVisualError.noSourceImage.localizedDescription
            return
        }

        isApplyingEdit = true
        errorMessage = nil

        let request = AIEditRequest(
            sourceAssetID: sourceAssetID,
            editType: selectedEditType,
            parameters: editParameters
        )

        do {
            let result = try await repository.requestEdit(request: request)
            currentEditResult = result
            editHistory.insert(result, at: 0)
        } catch {
            if AppEnvironment.current == .dev {
                let mock = AIEditResult.mock
                currentEditResult = mock
                editHistory.insert(mock, at: 0)
            } else {
                errorMessage = AIVisualError.editFailed.localizedDescription
            }
        }

        isApplyingEdit = false
    }

    @MainActor
    func loadEditHistory() async {
        errorMessage = nil

        do {
            editHistory = try await repository.fetchEditHistory()
        } catch {
            if AppEnvironment.current == .dev {
                editHistory = AIEditResult.mockList
            } else {
                errorMessage = "Unable to load edit history."
            }
        }
    }

    func clearCurrentEdit() {
        currentEditResult = nil
        beforeAfterPosition = 0.5
    }

    // MARK: - Style Presets

    @MainActor
    func loadStylePresets() async {
        isLoadingPresets = true
        errorMessage = nil

        do {
            stylePresets = try await repository.fetchStylePresets()
        } catch {
            if AppEnvironment.current == .dev {
                stylePresets = StylePreset.mockList
            } else {
                errorMessage = "Unable to load style presets."
            }
        }

        isLoadingPresets = false
    }

    func selectPreset(_ preset: StylePreset) {
        selectedPreset = preset
        selectedEditType = .styleTransfer
        editParameters["stylePresetID"] = preset.id.uuidString
    }

    // MARK: - Image Generation

    @MainActor
    func generateImage() async {
        let prompt = generationPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            errorMessage = AIVisualError.emptyPrompt.localizedDescription
            return
        }

        isGeneratingImage = true
        errorMessage = nil

        do {
            let image = try await repository.generateImage(
                prompt: prompt,
                dimensions: selectedDimensions
            )
            generatedImages.insert(image, at: 0)
        } catch {
            if AppEnvironment.current == .dev {
                generatedImages.insert(.mock, at: 0)
            } else {
                errorMessage = AIVisualError.generationFailed.localizedDescription
            }
        }

        isGeneratingImage = false
    }

    @MainActor
    func loadGeneratedImages() async {
        errorMessage = nil

        do {
            generatedImages = try await repository.fetchGeneratedImages()
        } catch {
            if AppEnvironment.current == .dev {
                generatedImages = GeneratedImage.mockList
            } else {
                errorMessage = "Unable to load generated images."
            }
        }
    }

    func removeGeneratedImage(_ image: GeneratedImage) {
        generatedImages.removeAll { $0.id == image.id }
    }
}
