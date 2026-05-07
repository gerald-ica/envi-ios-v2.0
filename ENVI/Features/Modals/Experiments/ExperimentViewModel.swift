import SwiftUI
import Combine

/// ViewModel for Experiments and A/B Testing.
@MainActor
final class ExperimentViewModel: ObservableObject {
    // MARK: - Published State
    @Published var experiments: [Experiment] = []
    @Published var selectedExperiment: Experiment?
    @Published var editingExperiment: Experiment?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Results
    @Published var currentResult: ABTestResult?
    @Published var isLoadingResults = false

    // MARK: - Filters
    @Published var statusFilter: ExperimentStatus?

    // MARK: - Sheet State
    @Published var isShowingEditor = false
    @Published var isShowingResults = false

    private nonisolated(unsafe) let repository: ExperimentRepository

    init(repository: ExperimentRepository = ExperimentRepositoryProvider.shared.repository) {
        self.repository = repository
        Task { [weak self] in
            guard let self else { return }
            await loadExperiments()
        }
    }

    // MARK: - Filtered Experiments

    var filteredExperiments: [Experiment] {
        guard let filter = statusFilter else { return experiments }
        return experiments.filter { $0.status == filter }
    }

    // MARK: - Load

    func loadExperiments() async {
        isLoading = true
        errorMessage = nil

        do {
            experiments = try await repository.fetchExperiments()
        } catch {
            if AppEnvironment.current == .dev {
                experiments = Experiment.mockList
            } else {
                errorMessage = "Unable to load experiments."
            }
        }

        isLoading = false
    }

    // MARK: - Create

    func createExperiment(_ experiment: Experiment) async {
        errorMessage = nil
        experiments.insert(experiment, at: 0)

        do {
            _ = try await repository.createExperiment(experiment)
        } catch {
            experiments.removeAll { $0.id == experiment.id }
            errorMessage = "Could not create experiment."
        }
    }

    // MARK: - Start / Stop

    func startExperiment(_ experiment: Experiment) async {
        errorMessage = nil
        guard let index = experiments.firstIndex(where: { $0.id == experiment.id }) else { return }
        let snapshot = experiments[index]
        experiments[index].status = .running

        do {
            experiments[index] = try await repository.startExperiment(id: experiment.id)
        } catch {
            experiments[index] = snapshot
            errorMessage = "Could not start experiment."
        }
    }

    func stopExperiment(_ experiment: Experiment) async {
        errorMessage = nil
        guard let index = experiments.firstIndex(where: { $0.id == experiment.id }) else { return }
        let snapshot = experiments[index]
        experiments[index].status = .completed

        do {
            experiments[index] = try await repository.stopExperiment(id: experiment.id)
        } catch {
            experiments[index] = snapshot
            errorMessage = "Could not stop experiment."
        }
    }

    // MARK: - Results

    func loadResults(for experiment: Experiment) async {
        isLoadingResults = true
        currentResult = nil

        do {
            currentResult = try await repository.fetchResults(id: experiment.id)
        } catch {
            if AppEnvironment.current == .dev {
                currentResult = ABTestResult.mock
            } else {
                errorMessage = "Could not load results."
            }
        }

        isLoadingResults = false
    }

    // MARK: - Save

    func saveExperiment(_ experiment: Experiment) async {
        if experiments.contains(where: { $0.id == experiment.id }) {
            // Update in-memory (no dedicated update endpoint needed for draft edits)
            if let index = experiments.firstIndex(where: { $0.id == experiment.id }) {
                experiments[index] = experiment
            }
        } else {
            await createExperiment(experiment)
        }
        isShowingEditor = false
        editingExperiment = nil
    }

    // MARK: - Editor Helpers

    func startCreatingExperiment() {
        editingExperiment = Experiment(
            name: "",
            variants: [
                ExperimentVariant(name: "Variant A"),
                ExperimentVariant(name: "Variant B"),
            ]
        )
        isShowingEditor = true
    }

    func startEditingExperiment(_ experiment: Experiment) {
        editingExperiment = experiment
        isShowingEditor = true
    }

    func showResults(for experiment: Experiment) {
        selectedExperiment = experiment
        isShowingResults = true
        Task { [weak self] in
            guard let self else { return }
            await loadResults(for: experiment)
        }
    }
}
