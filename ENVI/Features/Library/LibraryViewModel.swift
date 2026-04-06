import SwiftUI
import Combine

/// ViewModel for the Library screen.
final class LibraryViewModel: ObservableObject {
    enum FilterType: String, CaseIterable {
        case all = "All"
        case photos = "Photos"
        case videos = "Videos"
        case templates = "Templates"
        case drafts = "Drafts"
    }

    @Published var selectedFilter: FilterType = .all
    @Published var searchQuery: String = ""
    @Published var items: [LibraryItem] = []
    @Published var templates: [TemplateItem] = TemplateItem.mockTemplates
    @Published var contentPlan: [ContentPlanItem] = []
    @Published var isLoading = false
    @Published var isLoadingPlan = false
    @Published var isApplyingTemplateOperation = false
    @Published var isShowingPlanEditor = false
    @Published var editingPlanItem: ContentPlanItem? = nil
    @Published var loadErrorMessage: String?
    @Published var planErrorMessage: String?
    @Published var templateOperationErrorMessage: String?
    @Published var planOperationErrorMessage: String?
    @Published var templateToApply: TemplateItem? = nil
    private var cancellables = Set<AnyCancellable>()
    private let repository: ContentRepository

    init(repository: ContentRepository = ContentRepositoryProvider.shared.contentRepository) {
        self.repository = repository
        ApprovedMediaLibraryStore.shared.$approvedItems
            .receive(on: DispatchQueue.main)
            .sink { [weak self] approvedItems in
                self?.mergeApprovedItems(approvedItems)
            }
            .store(in: &cancellables)

        TelemetryManager.shared.track(.libraryOpened)

        Task {
            await reloadLibrary()
            await reloadContentPlan()
        }
    }

    @MainActor
    func reloadContentPlan() async {
        isLoadingPlan = true
        planErrorMessage = nil

        do {
            contentPlan = try await repository.fetchContentPlan()
        } catch {
            if AppEnvironment.current == .dev {
                contentPlan = ContentPlanItem.mockPlan
            } else {
                contentPlan = []
                planErrorMessage = "Unable to load content plan."
            }
        }

        isLoadingPlan = false
    }

    var filteredItems: [LibraryItem] {
        let base: [LibraryItem]
        if selectedFilter == .all {
            base = items
        } else {
            base = items.filter { $0.type.rawValue == selectedFilter.rawValue }
        }

        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return base }

        return base.filter { item in
            item.title.localizedCaseInsensitiveContains(query) ||
                item.type.rawValue.localizedCaseInsensitiveContains(query)
        }
    }

    @MainActor
    func reloadLibrary() async {
        isLoading = true
        loadErrorMessage = nil

        do {
            let contentItems = try await repository.fetchLibraryItems()
            let mapped = contentItems.map(LibraryItem.init(contentItem:))
            items = mapped
        } catch {
            if AppEnvironment.current == .dev {
                items = LibraryItem.mockItems
            } else {
                items = []
                loadErrorMessage = "Unable to load library content."
            }
        }

        isLoading = false
    }

    private func mergeApprovedItems(_ approvedItems: [LibraryItem]) {
        let nonApproved = items.filter { item in
            !approvedItems.contains(where: { $0.id == item.id })
        }
        items = approvedItems + nonApproved
    }

    @MainActor
    func duplicateTemplate(_ template: TemplateItem) async {
        isApplyingTemplateOperation = true
        templateOperationErrorMessage = nil

        do {
            let duplicated = try await repository.duplicateTemplate(templateID: template.id)
            templates.insert(duplicated, at: 0)
        } catch {
            templateOperationErrorMessage = "Could not duplicate template."
        }

        isApplyingTemplateOperation = false
    }

    @MainActor
    func applyTemplate(_ template: TemplateItem) {
        templateToApply = template
    }

    @MainActor
    func deleteTemplate(_ template: TemplateItem) async {
        isApplyingTemplateOperation = true
        templateOperationErrorMessage = nil

        let currentTemplates = templates
        templates.removeAll { $0.id == template.id }

        do {
            try await repository.deleteTemplate(templateID: template.id)
        } catch {
            templates = currentTemplates
            templateOperationErrorMessage = "Could not delete template."
        }

        isApplyingTemplateOperation = false
    }

    // MARK: - Planning CRUD

    @MainActor
    func createPlanItem(title: String, platform: SocialPlatform, scheduledAt: Date) async {
        planOperationErrorMessage = nil

        do {
            let created = try await repository.createPlanItem(title: title, platform: platform, scheduledAt: scheduledAt)
            contentPlan.insert(created, at: 0)
            // Re-index sort orders
            for i in contentPlan.indices { contentPlan[i].sortOrder = i }
        } catch {
            planOperationErrorMessage = "Could not create plan item."
        }
    }

    @MainActor
    func updatePlanItem(_ item: ContentPlanItem, title: String? = nil, platform: SocialPlatform? = nil, scheduledAt: Date? = nil, status: ContentPlanItem.Status? = nil) async {
        planOperationErrorMessage = nil

        guard let index = contentPlan.firstIndex(where: { $0.id == item.id }) else { return }
        let snapshot = contentPlan

        // Optimistic update
        if let title { contentPlan[index].title = title }
        if let platform { contentPlan[index].platform = platform }
        if let scheduledAt { contentPlan[index].scheduledAt = scheduledAt }
        if let status { contentPlan[index].status = status }

        do {
            _ = try await repository.updatePlanItem(id: item.id, title: title, platform: platform, scheduledAt: scheduledAt, status: status)
        } catch {
            contentPlan = snapshot
            planOperationErrorMessage = "Could not update plan item."
        }
    }

    @MainActor
    func deletePlanItem(_ item: ContentPlanItem) async {
        planOperationErrorMessage = nil

        let snapshot = contentPlan
        contentPlan.removeAll { $0.id == item.id }

        do {
            try await repository.deletePlanItem(id: item.id)
        } catch {
            contentPlan = snapshot
            planOperationErrorMessage = "Could not delete plan item."
        }
    }

    @MainActor
    func reorderPlanItems(from source: IndexSet, to destination: Int) {
        planOperationErrorMessage = nil

        let snapshot = contentPlan
        contentPlan.move(fromOffsets: source, toOffset: destination)
        for i in contentPlan.indices { contentPlan[i].sortOrder = i }

        let ids = contentPlan.map(\.id)
        Task {
            do {
                try await repository.reorderPlanItems(ids: ids)
            } catch {
                contentPlan = snapshot
                planOperationErrorMessage = "Could not reorder plan items."
            }
        }
    }
}

struct LibraryItem: Identifiable, Codable {
    let id: String
    let title: String
    let imageName: String
    let type: ItemType
    let height: CGFloat // For masonry layout

    enum ItemType: String, Codable {
        case photos = "Photos"
        case videos = "Videos"
        case templates = "Templates"
        case drafts = "Drafts"
    }

    init(id: String = UUID().uuidString, title: String, imageName: String, type: ItemType, height: CGFloat) {
        self.id = id
        self.title = title
        self.imageName = imageName
        self.type = type
        self.height = height
    }

    init(contentItem: ContentItem) {
        id = contentItem.id.uuidString
        title = contentItem.caption
        imageName = contentItem.imageName ?? LibraryItem.fallbackImageName(for: contentItem.platform)

        switch contentItem.type {
        case .photo:
            type = .photos
            height = 240
        case .video:
            type = .videos
            height = 240
        case .carousel:
            type = .photos
            height = 260
        case .textPost:
            type = .drafts
            height = 220
        }
    }

    private static func fallbackImageName(for platform: SocialPlatform) -> String {
        switch platform {
        case .instagram: return "studio-fashion"
        case .tiktok: return "industrial-girl"
        case .x: return "red-silhouette"
        case .threads: return "fashion-group"
        case .linkedin: return "office-girl"
        case .youtube: return "fire-stunt"
        }
    }

    static let mockItems: [LibraryItem] = [
        LibraryItem(title: "Desert Road", imageName: "desert-car", type: .photos, height: 200),
        LibraryItem(title: "Street Style", imageName: "fashion-group", type: .photos, height: 260),
        LibraryItem(title: "Urban Ride", imageName: "cyclist", type: .photos, height: 180),
        LibraryItem(title: "Studio Session", imageName: "studio-fashion", type: .photos, height: 240),
        LibraryItem(title: "Fire BTS", imageName: "fire-stunt", type: .videos, height: 220),
        LibraryItem(title: "Subway", imageName: "subway", type: .photos, height: 200),
        LibraryItem(title: "Runway", imageName: "runway", type: .photos, height: 260),
        LibraryItem(title: "Red Light", imageName: "red-silhouette", type: .photos, height: 230),
    ]
}

struct TemplateItem: Identifiable {
    let id: UUID
    let title: String
    let imageName: String
    let category: String
    let captionTemplate: String
    let suggestedPlatforms: [SocialPlatform]
    let contentKind: ExportContentKind

    init(
        id: UUID = UUID(),
        title: String,
        imageName: String,
        category: String,
        captionTemplate: String = "",
        suggestedPlatforms: [SocialPlatform] = [.instagram],
        contentKind: ExportContentKind = .photo
    ) {
        self.id = id
        self.title = title
        self.imageName = imageName
        self.category = category
        self.captionTemplate = captionTemplate
        self.suggestedPlatforms = suggestedPlatforms
        self.contentKind = contentKind
    }

    static let mockTemplates: [TemplateItem] = [
        TemplateItem(
            title: "Minimal Story",
            imageName: "jacket",
            category: "Instagram",
            captionTemplate: "✨ [Your story here] #minimal #aesthetic",
            suggestedPlatforms: [.instagram],
            contentKind: .photo
        ),
        TemplateItem(
            title: "Bold Reel",
            imageName: "industrial-girl",
            category: "TikTok",
            captionTemplate: "🔥 [Your hook] #trending #fyp",
            suggestedPlatforms: [.tiktok],
            contentKind: .video
        ),
        TemplateItem(
            title: "Clean Post",
            imageName: "office-girl",
            category: "LinkedIn",
            captionTemplate: "[Professional insight here] #thoughtleadership",
            suggestedPlatforms: [.linkedin, .x],
            contentKind: .textPost
        ),
    ]
}
