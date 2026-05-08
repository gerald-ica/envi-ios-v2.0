import SwiftUI
import Combine

/// ViewModel for the Brand Kit and Template system.
@MainActor
final class BrandKitViewModel: ObservableObject {
    // MARK: - Brand Kits
    @Published var brandKits: [BrandKit] = []
    @Published var selectedBrandKit: BrandKit?
    @Published var editingBrandKit: BrandKit?
    @Published var isLoadingBrandKits = false
    @Published var brandKitError: String?

    // MARK: - Templates
    @Published var templates: [ContentTemplate] = []
    @Published var selectedCategory: TemplateCategory?
    @Published var selectedPlatformFilter: SocialPlatform?
    @Published var selectedBrandKitFilter: UUID?
    @Published var editingTemplate: ContentTemplate?
    @Published var isLoadingTemplates = false
    @Published var templateError: String?

    // MARK: - Caption Style Guide
    @Published var captionStyleGuide: CaptionStyleGuide = .mock

    // MARK: - Sheet State
    @Published var isShowingBrandKitEditor = false
    @Published var isShowingTemplateEditor = false

    private nonisolated(unsafe) let repository: BrandKitRepository

    init(repository: BrandKitRepository = BrandKitRepositoryProvider.shared.repository) {
        self.repository = repository
        Task { @MainActor in
            await loadBrandKits()
            await loadTemplates()
        }
    }

    // MARK: - Filtered Templates

    var filteredTemplates: [ContentTemplate] {
        var result = templates

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        if let platform = selectedPlatformFilter {
            result = result.filter { $0.suggestedPlatforms.contains(platform) }
        }

        if let brandKitID = selectedBrandKitFilter {
            result = result.filter { $0.brandKitID == brandKitID }
        }

        return result
    }

    // MARK: - Brand Kit CRUD

    @MainActor
    func loadBrandKits() async {
        isLoadingBrandKits = true
        brandKitError = nil

        do {
            brandKits = try await repository.fetchBrandKits()
        } catch {
            if AppEnvironment.current == .dev {
                brandKits = BrandKit.mockList
            } else {
                brandKitError = "Unable to load brand kits."
            }
        }

        isLoadingBrandKits = false
    }

    @MainActor
    func createBrandKit(_ kit: BrandKit) async {
        brandKitError = nil

        // Optimistic insert
        brandKits.insert(kit, at: 0)

        do {
            _ = try await repository.createBrandKit(kit)
        } catch {
            brandKits.removeAll { $0.id == kit.id }
            brandKitError = "Could not create brand kit."
        }
    }

    @MainActor
    func updateBrandKit(_ kit: BrandKit) async {
        brandKitError = nil

        guard let index = brandKits.firstIndex(where: { $0.id == kit.id }) else { return }
        let snapshot = brandKits[index]

        // Optimistic update
        brandKits[index] = kit

        do {
            try await repository.updateBrandKit(kit)
        } catch {
            brandKits[index] = snapshot
            brandKitError = "Could not update brand kit."
        }
    }

    @MainActor
    func deleteBrandKit(_ kit: BrandKit) async {
        brandKitError = nil

        let snapshot = brandKits
        brandKits.removeAll { $0.id == kit.id }

        do {
            try await repository.deleteBrandKit(id: kit.id)
        } catch {
            brandKits = snapshot
            brandKitError = "Could not delete brand kit."
        }
    }

    // MARK: - Template CRUD

    @MainActor
    func loadTemplates() async {
        isLoadingTemplates = true
        templateError = nil

        do {
            templates = try await repository.fetchTemplates(brandKitID: nil)
        } catch {
            if AppEnvironment.current == .dev {
                templates = ContentTemplate.mockList
            } else {
                templateError = "Unable to load templates."
            }
        }

        isLoadingTemplates = false
    }

    @MainActor
    func createTemplate(_ template: ContentTemplate) async {
        templateError = nil

        templates.insert(template, at: 0)

        do {
            _ = try await repository.createTemplate(template)
        } catch {
            templates.removeAll { $0.id == template.id }
            templateError = "Could not create template."
        }
    }

    @MainActor
    func duplicateTemplate(_ template: ContentTemplate) async {
        templateError = nil

        do {
            let duplicate = try await repository.duplicateTemplate(id: template.id)
            templates.insert(duplicate, at: 0)
        } catch {
            templateError = "Could not duplicate template."
        }
    }

    @MainActor
    func deleteTemplate(_ template: ContentTemplate) async {
        templateError = nil

        let snapshot = templates
        templates.removeAll { $0.id == template.id }

        do {
            try await repository.deleteTemplate(id: template.id)
        } catch {
            templates = snapshot
            templateError = "Could not delete template."
        }
    }

    // MARK: - Caption Style Guide

    @MainActor
    func loadCaptionStyleGuide(for brandKitID: UUID) async {
        do {
            captionStyleGuide = try await repository.fetchCaptionStyleGuide(brandKitID: brandKitID)
        } catch {
            captionStyleGuide = .mock
        }
    }

    // MARK: - Editor Helpers

    func startCreatingBrandKit() {
        editingBrandKit = BrandKit(name: "")
        isShowingBrandKitEditor = true
    }

    func startEditingBrandKit(_ kit: BrandKit) {
        editingBrandKit = kit
        isShowingBrandKitEditor = true
    }

    func startCreatingTemplate() {
        editingTemplate = ContentTemplate(name: "")
        isShowingTemplateEditor = true
    }

    func startEditingTemplate(_ template: ContentTemplate) {
        editingTemplate = template
        isShowingTemplateEditor = true
    }

    @MainActor
    func saveBrandKit(_ kit: BrandKit) async {
        if brandKits.contains(where: { $0.id == kit.id }) {
            await updateBrandKit(kit)
        } else {
            await createBrandKit(kit)
        }
        isShowingBrandKitEditor = false
        editingBrandKit = nil
    }

    @MainActor
    func saveTemplate(_ template: ContentTemplate) async {
        if templates.contains(where: { $0.id == template.id }) {
            // Update in place
            templateError = nil
            if let index = templates.firstIndex(where: { $0.id == template.id }) {
                templates[index] = template
            }
        } else {
            await createTemplate(template)
        }
        isShowingTemplateEditor = false
        editingTemplate = nil
    }
}
