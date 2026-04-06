import Foundation

// MARK: - Protocol

protocol AIWritingRepository {
    func generateCaption(prompt: String, platform: SocialPlatform, tone: WritingTone) async throws -> CaptionDraft
    func generateScript(topic: String, platform: SocialPlatform, duration: TimeInterval) async throws -> VideoScript
    func generateHooks(topic: String, count: Int) async throws -> [HookTemplate]
    func rephraseText(text: String, tone: WritingTone) async throws -> String
    func generateThread(topic: String, platform: SocialPlatform, postCount: Int) async throws -> ThreadDraft
    func generateHashtags(caption: String, platform: SocialPlatform, count: Int) async throws -> [String]
}

// MARK: - Mock Implementation

final class MockAIWritingRepository: AIWritingRepository {

    func generateCaption(prompt: String, platform: SocialPlatform, tone: WritingTone) async throws -> CaptionDraft {
        try await simulateDelay()
        return CaptionDraft(
            text: "Here's what nobody tells you about \(prompt).\n\nIt takes consistency, not perfection.\n\nFollow for more.",
            platform: platform,
            tone: tone,
            hookStyle: "Bold Statement",
            ctaStyle: "Follow for more",
            hashtagSuggestions: ["#creator", "#\(prompt.split(separator: " ").first ?? "content")", "#growthtips"]
        )
    }

    func generateScript(topic: String, platform: SocialPlatform, duration: TimeInterval) async throws -> VideoScript {
        try await simulateDelay()
        let hookDuration = min(duration * 0.15, 5)
        let ctaDuration = min(duration * 0.15, 5)
        let bodyDuration = duration - hookDuration - ctaDuration

        return VideoScript(
            title: "\(topic) Script",
            segments: [
                ScriptSegment(type: .hook, text: "Stop scrolling. This will change how you think about \(topic).", duration: hookDuration, speakerNotes: "High energy, direct to camera"),
                ScriptSegment(type: .body, text: "Here's the thing about \(topic) that most people miss. It's not about doing more — it's about doing the right things consistently.", duration: bodyDuration, speakerNotes: "Slow down, be genuine"),
                ScriptSegment(type: .cta, text: "Follow for more tips on \(topic).", duration: ctaDuration, speakerNotes: "Smile, point at camera"),
            ],
            platform: platform
        )
    }

    func generateHooks(topic: String, count: Int) async throws -> [HookTemplate] {
        try await simulateDelay()
        return Array(HookTemplate.mockList.prefix(count))
    }

    func rephraseText(text: String, tone: WritingTone) async throws -> String {
        try await simulateDelay()
        switch tone {
        case .professional:  return "In my professional experience, \(text.lowercased())"
        case .casual:        return "So basically, \(text.lowercased())"
        case .bold:          return "Let me be direct: \(text)"
        case .playful:       return "Okay hear me out... \(text.lowercased())"
        case .educational:   return "Here's what the research says: \(text)"
        case .inspirational: return "Imagine this: \(text.lowercased())"
        }
    }

    func generateThread(topic: String, platform: SocialPlatform, postCount: Int) async throws -> ThreadDraft {
        try await simulateDelay()
        var posts = ["Here's everything I learned about \(topic) (a thread):"]
        for i in 1..<postCount {
            if i == postCount - 1 {
                posts.append("\(i)/ That's a wrap. Follow me for more on \(topic).")
            } else {
                posts.append("\(i)/ Key insight #\(i) about \(topic) that most people overlook.")
            }
        }
        return ThreadDraft(posts: posts, platform: platform)
    }

    func generateHashtags(caption: String, platform: SocialPlatform, count: Int) async throws -> [String] {
        try await simulateDelay()
        let pool = ["#content", "#creator", "#socialmedia", "#growth", "#branding",
                     "#marketing", "#strategy", "#engagement", "#viral", "#fyp",
                     "#trending", "#tips", "#community", "#digital", "#influence"]
        return Array(pool.prefix(count))
    }

    private func simulateDelay() async throws {
        try await Task.sleep(for: .seconds(Double.random(in: 0.5...1.5)))
    }
}

// MARK: - API Implementation

final class APIAIWritingRepository: AIWritingRepository {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func generateCaption(prompt: String, platform: SocialPlatform, tone: WritingTone) async throws -> CaptionDraft {
        try await apiClient.request(
            endpoint: "ai/writing/caption",
            method: .post,
            body: CaptionRequest(prompt: prompt, platform: platform.apiSlug, tone: tone.rawValue),
            requiresAuth: true
        )
    }

    func generateScript(topic: String, platform: SocialPlatform, duration: TimeInterval) async throws -> VideoScript {
        try await apiClient.request(
            endpoint: "ai/writing/script",
            method: .post,
            body: ScriptRequest(topic: topic, platform: platform.apiSlug, duration: duration),
            requiresAuth: true
        )
    }

    func generateHooks(topic: String, count: Int) async throws -> [HookTemplate] {
        try await apiClient.request(
            endpoint: "ai/writing/hooks",
            method: .post,
            body: HooksRequest(topic: topic, count: count),
            requiresAuth: true
        )
    }

    func rephraseText(text: String, tone: WritingTone) async throws -> String {
        let response: RephraseResponse = try await apiClient.request(
            endpoint: "ai/writing/rephrase",
            method: .post,
            body: RephraseRequest(text: text, tone: tone.rawValue),
            requiresAuth: true
        )
        return response.text
    }

    func generateThread(topic: String, platform: SocialPlatform, postCount: Int) async throws -> ThreadDraft {
        try await apiClient.request(
            endpoint: "ai/writing/thread",
            method: .post,
            body: ThreadRequest(topic: topic, platform: platform.apiSlug, postCount: postCount),
            requiresAuth: true
        )
    }

    func generateHashtags(caption: String, platform: SocialPlatform, count: Int) async throws -> [String] {
        let response: HashtagsResponse = try await apiClient.request(
            endpoint: "ai/writing/hashtags",
            method: .post,
            body: HashtagsRequest(caption: caption, platform: platform.apiSlug, count: count),
            requiresAuth: true
        )
        return response.hashtags
    }
}

private struct RephraseResponse: Decodable {
    let text: String
}

// MARK: - Error

enum AIWritingError: LocalizedError {
    case generationFailed
    case emptyPrompt

    var errorDescription: String? {
        switch self {
        case .generationFailed: return "AI content generation failed. Please try again."
        case .emptyPrompt: return "Please enter a topic or prompt."
        }
    }
}

// MARK: - Provider

enum AIWritingRepositoryProvider {
    static var shared = RepositoryProvider<AIWritingRepository>(
        dev: MockAIWritingRepository(),
        api: APIAIWritingRepository()
    )
}
