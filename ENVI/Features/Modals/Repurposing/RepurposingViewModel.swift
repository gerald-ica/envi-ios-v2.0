import SwiftUI
import Combine

/// ViewModel for the Repurposing & Cross-Format Production feature set (D17).
@MainActor
final class RepurposingViewModel: ObservableObject {
    // MARK: - Jobs
    @Published var jobs: [RepurposeJob] = []
    @Published var isLoadingJobs = false
    @Published var jobError: String?

    // MARK: - Suggestions
    @Published var suggestions: [RepurposeSuggestion] = []
    @Published var isLoadingSuggestions = false

    // MARK: - Cross-Post Mappings
    @Published var mappings: [CrossPostMapping] = []
    @Published var isLoadingMappings = false

    // MARK: - Job Builder State
    @Published var selectedSourceFormat: RepurposeFormat = .reel
    @Published var selectedTargetFormats: Set<RepurposeFormat> = []
    @Published var isCreatingJob = false

    private nonisolated(unsafe) let repository: RepurposingRepository

    init(repository: RepurposingRepository = RepurposingRepositoryProvider.shared.repository) {
        self.repository = repository
        Task {
            await loadJobs()
            await loadSuggestions()
            await loadMappings()
        }
    }

    // MARK: - Computed

    var availableTargetFormats: [RepurposeFormat] {
        RepurposeFormat.allCases.filter { $0 != selectedSourceFormat }
    }

    var canCreateJob: Bool {
        !selectedTargetFormats.isEmpty && !isCreatingJob
    }

    // MARK: - Jobs

    @MainActor
    func loadJobs() async {
        isLoadingJobs = true
        jobError = nil

        do {
            jobs = try await repository.fetchJobs()
        } catch {
            if AppEnvironment.current == .dev {
                jobs = RepurposeJob.mockList
            } else {
                jobError = "Unable to load repurpose jobs."
            }
        }

        isLoadingJobs = false
    }

    @MainActor
    func createJob(sourceAssetID: UUID) async {
        isCreatingJob = true
        jobError = nil

        let job = RepurposeJob(
            sourceAssetID: sourceAssetID,
            sourceFormat: selectedSourceFormat,
            targetFormats: Array(selectedTargetFormats)
        )

        do {
            let created = try await repository.createRepurposeJob(job)
            jobs.insert(created, at: 0)
            selectedTargetFormats = []
        } catch {
            jobError = "Failed to create repurpose job."
        }

        isCreatingJob = false
    }

    // MARK: - Suggestions

    @MainActor
    func loadSuggestions(assetID: UUID? = nil) async {
        isLoadingSuggestions = true

        do {
            suggestions = try await repository.fetchSuggestions(assetID: assetID)
        } catch {
            if AppEnvironment.current == .dev {
                suggestions = RepurposeSuggestion.mockList
            }
        }

        isLoadingSuggestions = false
    }

    // MARK: - Cross-Post Mappings

    @MainActor
    func loadMappings() async {
        isLoadingMappings = true

        do {
            mappings = try await repository.fetchCrossPostMappings()
        } catch {
            if AppEnvironment.current == .dev {
                mappings = CrossPostMapping.mockList
            }
        }

        isLoadingMappings = false
    }

    // MARK: - Format Toggle

    func toggleTargetFormat(_ format: RepurposeFormat) {
        if selectedTargetFormats.contains(format) {
            selectedTargetFormats.remove(format)
        } else {
            selectedTargetFormats.insert(format)
        }
    }
}
