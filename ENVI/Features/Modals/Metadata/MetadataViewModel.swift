import SwiftUI
import Combine

/// ViewModel for the Metadata, Tagging, and Knowledge Graph domain (D07).
@MainActor
final class MetadataViewModel: ObservableObject {
    // MARK: - Tags
    @Published var tags: [Tag] = []
    @Published var searchText: String = ""
    @Published var selectedCategory: TagCategory?
    @Published var isLoadingTags = false
    @Published var tagError: String?

    // MARK: - Auto-Tag
    @Published var suggestions: [TagSuggestion] = []
    @Published var acceptedSuggestions: Set<UUID> = []
    @Published var rejectedSuggestions: Set<UUID> = []
    @Published var isGenerating = false
    @Published var autoTagError: String?

    // MARK: - Completeness
    @Published var contentMetadata: ContentMetadata?
    @Published var isLoadingCompleteness = false

    // MARK: - Clusters
    @Published var topicClusters: [TopicCluster] = []
    @Published var isLoadingClusters = false

    // MARK: - Sheet State
    @Published var isShowingTagEditor = false
    @Published var editingTag: Tag?

    private nonisolated(unsafe) let repository: MetadataRepository

    init(repository: MetadataRepository = MetadataRepositoryProvider.shared.repository) {
        self.repository = repository
        Task {
            await loadTags()
        }
    }

    // MARK: - Filtered Tags

    var filteredTags: [Tag] {
        var result = tags

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return result
    }

    // MARK: - Tag CRUD

    @MainActor
    func loadTags() async {
        isLoadingTags = true
        tagError = nil

        do {
            tags = try await repository.fetchTags()
        } catch {
            if AppEnvironment.current == .dev {
                tags = Tag.mockList
            } else {
                tagError = "Unable to load tags."
            }
        }

        isLoadingTags = false
    }

    @MainActor
    func createTag(_ tag: Tag) async {
        tagError = nil
        tags.insert(tag, at: 0)

        do {
            _ = try await repository.createTag(tag)
        } catch {
            tags.removeAll { $0.id == tag.id }
            tagError = "Could not create tag."
        }
    }

    @MainActor
    func updateTag(_ tag: Tag) async {
        tagError = nil
        guard let index = tags.firstIndex(where: { $0.id == tag.id }) else { return }
        let snapshot = tags[index]
        tags[index] = tag

        do {
            try await repository.updateTag(tag)
        } catch {
            tags[index] = snapshot
            tagError = "Could not update tag."
        }
    }

    @MainActor
    func deleteTag(_ tag: Tag) async {
        tagError = nil
        let snapshot = tags
        tags.removeAll { $0.id == tag.id }

        do {
            try await repository.deleteTag(id: tag.id)
        } catch {
            tags = snapshot
            tagError = "Could not delete tag."
        }
    }

    @MainActor
    func saveTag(_ tag: Tag) async {
        if tags.contains(where: { $0.id == tag.id }) {
            await updateTag(tag)
        } else {
            await createTag(tag)
        }
        isShowingTagEditor = false
        editingTag = nil
    }

    // MARK: - Auto-Tag

    @MainActor
    func autoGenerateTags(for assetID: UUID) async {
        isGenerating = true
        autoTagError = nil
        acceptedSuggestions.removeAll()
        rejectedSuggestions.removeAll()

        do {
            suggestions = try await repository.autoGenerateTags(assetID: assetID)
        } catch {
            if AppEnvironment.current == .dev {
                suggestions = TagSuggestion.mockList
            } else {
                autoTagError = "Auto-tag generation failed."
            }
        }

        isGenerating = false
    }

    func acceptSuggestion(_ suggestion: TagSuggestion) {
        acceptedSuggestions.insert(suggestion.id)
        rejectedSuggestions.remove(suggestion.id)
    }

    func rejectSuggestion(_ suggestion: TagSuggestion) {
        rejectedSuggestions.insert(suggestion.id)
        acceptedSuggestions.remove(suggestion.id)
    }

    var pendingSuggestions: [TagSuggestion] {
        suggestions.filter { !acceptedSuggestions.contains($0.id) && !rejectedSuggestions.contains($0.id) }
    }

    @MainActor
    func applyAcceptedSuggestions(to assetID: UUID) async {
        let accepted = suggestions.filter { acceptedSuggestions.contains($0.id) }
        let newTags = accepted.map(\.tag)

        do {
            contentMetadata = try await repository.batchUpdateTags(assetID: assetID, tags: newTags)
        } catch {
            autoTagError = "Could not apply tags."
        }
    }

    // MARK: - Completeness

    @MainActor
    func loadCompleteness(for assetID: UUID) async {
        isLoadingCompleteness = true

        do {
            contentMetadata = try await repository.fetchCompleteness(assetID: assetID)
        } catch {
            if AppEnvironment.current == .dev {
                contentMetadata = .mock
            }
        }

        isLoadingCompleteness = false
    }

    // MARK: - Topic Clusters

    @MainActor
    func loadTopicClusters() async {
        isLoadingClusters = true

        do {
            topicClusters = try await repository.fetchTopicClusters()
        } catch {
            if AppEnvironment.current == .dev {
                topicClusters = TopicCluster.mockList
            }
        }

        isLoadingClusters = false
    }

    // MARK: - Editor Helpers

    func startCreatingTag() {
        editingTag = Tag(name: "")
        isShowingTagEditor = true
    }

    func startEditingTag(_ tag: Tag) {
        editingTag = tag
        isShowingTagEditor = true
    }
}
