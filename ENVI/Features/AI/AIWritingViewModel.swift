import SwiftUI
import Combine

/// ViewModel for the AI Writing and Script Generation domain.
final class AIWritingViewModel: ObservableObject {

    // MARK: - Caption Generation
    @Published var captionPrompt = ""
    @Published var captionPlatform: SocialPlatform = .instagram
    @Published var captionTone: WritingTone = .professional
    @Published var generatedCaptions: [CaptionDraft] = []
    @Published var isGeneratingCaption = false

    // MARK: - Script Generation
    @Published var scriptTopic = ""
    @Published var scriptPlatform: SocialPlatform = .instagram
    @Published var scriptDuration: TimeInterval = 30
    @Published var generatedScripts: [VideoScript] = []
    @Published var editingScript: VideoScript?
    @Published var isGeneratingScript = false

    // MARK: - Hook Library
    @Published var hookTemplates: [HookTemplate] = []
    @Published var hookSearchQuery = ""
    @Published var isLoadingHooks = false

    // MARK: - Thread Generation
    @Published var threadTopic = ""
    @Published var threadPlatform: SocialPlatform = .x
    @Published var threadPostCount = 5
    @Published var generatedThread: ThreadDraft?
    @Published var isGeneratingThread = false

    // MARK: - General
    @Published var errorMessage: String?

    // MARK: - Saved Items
    @Published var savedCaptions: [CaptionDraft] = []
    @Published var savedScripts: [VideoScript] = []
    @Published var favoriteHooks: [HookTemplate] = []

    private let repository: AIWritingRepository

    init(repository: AIWritingRepository = AIWritingRepositoryProvider.shared.repository) {
        self.repository = repository
    }

    // MARK: - Filtered Hooks

    var filteredHooks: [HookTemplate] {
        guard !hookSearchQuery.isEmpty else { return hookTemplates }
        let query = hookSearchQuery.lowercased()
        return hookTemplates.filter {
            $0.name.lowercased().contains(query) ||
            $0.pattern.lowercased().contains(query) ||
            $0.example.lowercased().contains(query)
        }
    }

    // MARK: - Caption Generation

    @MainActor
    func generateCaption() async {
        let prompt = captionPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            errorMessage = AIWritingError.emptyPrompt.localizedDescription
            return
        }

        isGeneratingCaption = true
        errorMessage = nil

        do {
            let caption = try await repository.generateCaption(
                prompt: prompt,
                platform: captionPlatform,
                tone: captionTone
            )
            generatedCaptions.insert(caption, at: 0)
        } catch {
            if AppEnvironment.current == .dev {
                generatedCaptions.insert(.mock, at: 0)
            } else {
                errorMessage = AIWritingError.generationFailed.localizedDescription
            }
        }

        isGeneratingCaption = false
    }

    @MainActor
    func regenerateCaption(_ caption: CaptionDraft) async {
        isGeneratingCaption = true
        errorMessage = nil

        do {
            let newCaption = try await repository.generateCaption(
                prompt: captionPrompt,
                platform: caption.platform,
                tone: caption.tone
            )
            if let index = generatedCaptions.firstIndex(where: { $0.id == caption.id }) {
                generatedCaptions[index] = newCaption
            }
        } catch {
            errorMessage = AIWritingError.generationFailed.localizedDescription
        }

        isGeneratingCaption = false
    }

    func saveCaption(_ caption: CaptionDraft) {
        guard !savedCaptions.contains(where: { $0.id == caption.id }) else { return }
        savedCaptions.insert(caption, at: 0)
    }

    func removeCaption(_ caption: CaptionDraft) {
        generatedCaptions.removeAll { $0.id == caption.id }
    }

    // MARK: - Script Generation

    @MainActor
    func generateScript() async {
        let topic = scriptTopic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !topic.isEmpty else {
            errorMessage = AIWritingError.emptyPrompt.localizedDescription
            return
        }

        isGeneratingScript = true
        errorMessage = nil

        do {
            let script = try await repository.generateScript(
                topic: topic,
                platform: scriptPlatform,
                duration: scriptDuration
            )
            generatedScripts.insert(script, at: 0)
            editingScript = script
        } catch {
            if AppEnvironment.current == .dev {
                generatedScripts.insert(.mock, at: 0)
                editingScript = .mock
            } else {
                errorMessage = AIWritingError.generationFailed.localizedDescription
            }
        }

        isGeneratingScript = false
    }

    func saveScript(_ script: VideoScript) {
        guard !savedScripts.contains(where: { $0.id == script.id }) else { return }
        savedScripts.insert(script, at: 0)
    }

    func updateScript(_ script: VideoScript) {
        if let index = generatedScripts.firstIndex(where: { $0.id == script.id }) {
            generatedScripts[index] = script
        }
        if editingScript?.id == script.id {
            editingScript = script
        }
    }

    // MARK: - Hook Library

    @MainActor
    func loadHooks(topic: String = "content creation") async {
        isLoadingHooks = true
        errorMessage = nil

        do {
            hookTemplates = try await repository.generateHooks(topic: topic, count: 10)
        } catch {
            if AppEnvironment.current == .dev {
                hookTemplates = HookTemplate.mockList
            } else {
                errorMessage = "Unable to load hook templates."
            }
        }

        isLoadingHooks = false
    }

    func toggleHookFavorite(_ hook: HookTemplate) {
        if let index = hookTemplates.firstIndex(where: { $0.id == hook.id }) {
            hookTemplates[index].isFavorite.toggle()
            if hookTemplates[index].isFavorite {
                favoriteHooks.append(hookTemplates[index])
            } else {
                favoriteHooks.removeAll { $0.id == hook.id }
            }
        }
    }

    // MARK: - Thread Generation

    @MainActor
    func generateThread() async {
        let topic = threadTopic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !topic.isEmpty else {
            errorMessage = AIWritingError.emptyPrompt.localizedDescription
            return
        }

        isGeneratingThread = true
        errorMessage = nil

        do {
            generatedThread = try await repository.generateThread(
                topic: topic,
                platform: threadPlatform,
                postCount: threadPostCount
            )
        } catch {
            if AppEnvironment.current == .dev {
                generatedThread = .mock
            } else {
                errorMessage = AIWritingError.generationFailed.localizedDescription
            }
        }

        isGeneratingThread = false
    }

    // MARK: - Rephrase

    @MainActor
    func rephraseText(_ text: String, tone: WritingTone) async -> String? {
        errorMessage = nil
        do {
            return try await repository.rephraseText(text: text, tone: tone)
        } catch {
            errorMessage = AIWritingError.generationFailed.localizedDescription
            return nil
        }
    }

    // MARK: - Hashtags

    @MainActor
    func generateHashtags(for caption: String, platform: SocialPlatform, count: Int = 10) async -> [String] {
        do {
            return try await repository.generateHashtags(caption: caption, platform: platform, count: count)
        } catch {
            return []
        }
    }

    // MARK: - Export

    func exportScriptAsText(_ script: VideoScript) -> String {
        var lines: [String] = []
        lines.append(script.title.uppercased())
        lines.append("Platform: \(script.platform.rawValue)")
        lines.append("Total Duration: \(script.formattedDuration)")
        lines.append(String(repeating: "-", count: 40))
        lines.append("")

        for (index, segment) in script.segments.enumerated() {
            lines.append("[\(segment.type.displayName.uppercased())] (\(Int(segment.duration))s)")
            lines.append(segment.text)
            if let notes = segment.speakerNotes, !notes.isEmpty {
                lines.append("  Speaker Notes: \(notes)")
            }
            if index < script.segments.count - 1 {
                lines.append("")
            }
        }

        return lines.joined(separator: "\n")
    }
}
