import SwiftUI
import Combine

/// ViewModel for the Education surfaces (tutorials, learning paths, achievements).
///
/// Phase 17 — Plan 03. Replaces the prior pattern where `TutorialListView`
/// and `AchievementsView` held `Tutorial.mock` / `LearningPath.mock` /
/// `AchievementBadge.mock` in `@State` defaults and never called
/// `EducationRepository`. Now backed by
/// `EducationRepositoryProvider.shared.repository`.
final class EducationViewModel: ObservableObject {
    // MARK: - State
    @Published var tutorials: [Tutorial] = []
    @Published var learningPaths: [LearningPath] = []
    @Published var achievements: [AchievementBadge] = []

    @Published var isLoading = false
    @Published var errorMessage: String?

    private nonisolated(unsafe) let repository: EducationRepository

    init(repository: EducationRepository = EducationRepositoryProvider.shared.repository) {
        self.repository = repository
    }

    // MARK: - Loading

    @MainActor
    func loadTutorials() async {
        isLoading = true
        errorMessage = nil

        do {
            async let tutorialsTask = repository.fetchTutorials()
            async let pathsTask = repository.fetchLearningPaths()

            let (t, p) = try await (tutorialsTask, pathsTask)
            tutorials = t
            learningPaths = p
        } catch {
            errorMessage = "Unable to load tutorials."
        }

        isLoading = false
    }

    @MainActor
    func loadAchievements() async {
        isLoading = true
        errorMessage = nil

        do {
            achievements = try await repository.fetchAchievements()
        } catch {
            errorMessage = "Unable to load achievements."
        }

        isLoading = false
    }
}

// MARK: - Preview Helper

#if DEBUG
extension EducationViewModel {
    /// Hydrates a VM with mock data for SwiftUI previews. Never reaches
    /// production because it's wrapped in `#if DEBUG`.
    static func preview() -> EducationViewModel {
        let vm = EducationViewModel(repository: MockEducationRepository())
        vm.tutorials = Tutorial.mock
        vm.learningPaths = LearningPath.mock
        vm.achievements = AchievementBadge.mock
        return vm
    }
}
#endif
