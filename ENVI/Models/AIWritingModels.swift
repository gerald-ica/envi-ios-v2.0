import Foundation

// MARK: - Writing Tone

enum WritingTone: String, Codable, CaseIterable, Identifiable {
    case professional
    case casual
    case bold
    case playful
    case educational
    case inspirational

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    var iconName: String {
        switch self {
        case .professional:  return "briefcase"
        case .casual:        return "hand.wave"
        case .bold:          return "flame"
        case .playful:       return "face.smiling"
        case .educational:   return "book"
        case .inspirational: return "sparkles"
        }
    }
}

// MARK: - Caption Draft

struct CaptionDraft: Identifiable, Codable {
    let id: UUID
    var text: String
    var platform: SocialPlatform
    var tone: WritingTone
    var hookStyle: String?
    var ctaStyle: String?
    var hashtagSuggestions: [String]
    var characterCount: Int
    var estimatedReadTime: TimeInterval

    init(
        id: UUID = UUID(),
        text: String,
        platform: SocialPlatform = .instagram,
        tone: WritingTone = .professional,
        hookStyle: String? = nil,
        ctaStyle: String? = nil,
        hashtagSuggestions: [String] = [],
        characterCount: Int? = nil,
        estimatedReadTime: TimeInterval? = nil
    ) {
        self.id = id
        self.text = text
        self.platform = platform
        self.tone = tone
        self.hookStyle = hookStyle
        self.ctaStyle = ctaStyle
        self.hashtagSuggestions = hashtagSuggestions
        self.characterCount = characterCount ?? text.count
        self.estimatedReadTime = estimatedReadTime ?? Self.readTime(for: text)
    }

    /// Estimates reading time at ~200 words per minute.
    private static func readTime(for text: String) -> TimeInterval {
        let wordCount = text.split(separator: " ").count
        return max(1, Double(wordCount) / 200.0 * 60.0)
    }

    static let mock = CaptionDraft(
        text: "Here's what nobody tells you about building a brand from scratch.\n\nIt takes consistency, not perfection.\n\nFollow for more creator tips.",
        platform: .instagram,
        tone: .professional,
        hookStyle: "Bold Statement",
        ctaStyle: "Follow for more",
        hashtagSuggestions: ["#creator", "#branding", "#growthtips", "#contentcreator", "#socialmedia"]
    )

    static let mockList: [CaptionDraft] = [
        .mock,
        CaptionDraft(
            text: "3 mistakes I made so you don't have to.\n\n1. Posting without a strategy\n2. Ignoring analytics\n3. Not engaging with my audience\n\nSave this for later.",
            platform: .instagram,
            tone: .educational,
            hookStyle: "Question",
            ctaStyle: "Save this",
            hashtagSuggestions: ["#socialmediatips", "#creatoreconomy", "#contentmarketing"]
        ),
        CaptionDraft(
            text: "POV: you finally figured out the algorithm.\n\nJust kidding. Nobody has. But here's what actually works.",
            platform: .tiktok,
            tone: .playful,
            hookStyle: "Story",
            hashtagSuggestions: ["#fyp", "#viral", "#algorithm"]
        ),
    ]
}

// MARK: - Script Segment

struct ScriptSegment: Identifiable, Codable {
    let id: UUID
    var type: SegmentType
    var text: String
    var duration: TimeInterval
    var speakerNotes: String?

    enum SegmentType: String, Codable, CaseIterable, Identifiable {
        case hook
        case body
        case cta
        case transition

        var id: String { rawValue }

        var displayName: String { rawValue.capitalized }

        var iconName: String {
            switch self {
            case .hook:       return "bolt"
            case .body:       return "text.alignleft"
            case .cta:        return "megaphone"
            case .transition: return "arrow.right"
            }
        }
    }

    init(
        id: UUID = UUID(),
        type: SegmentType,
        text: String,
        duration: TimeInterval = 5,
        speakerNotes: String? = nil
    ) {
        self.id = id
        self.type = type
        self.text = text
        self.duration = duration
        self.speakerNotes = speakerNotes
    }

    static let mockHook = ScriptSegment(
        type: .hook,
        text: "Stop scrolling. This changed everything for me.",
        duration: 3,
        speakerNotes: "Look directly at camera, energetic"
    )

    static let mockBody = ScriptSegment(
        type: .body,
        text: "I used to spend hours creating content with zero engagement. Then I discovered the power of storytelling frameworks.",
        duration: 12,
        speakerNotes: "Slow down, be genuine"
    )

    static let mockCTA = ScriptSegment(
        type: .cta,
        text: "Follow for more creator tips and hit that save button.",
        duration: 4,
        speakerNotes: "Point at camera, smile"
    )
}

// MARK: - Video Script

struct VideoScript: Identifiable, Codable {
    let id: UUID
    var title: String
    var segments: [ScriptSegment]
    var platform: SocialPlatform
    let createdAt: Date

    var totalDuration: TimeInterval {
        segments.reduce(0) { $0 + $1.duration }
    }

    /// Formatted total duration as "M:SS".
    var formattedDuration: String {
        let minutes = Int(totalDuration) / 60
        let seconds = Int(totalDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Full script text joined by newlines.
    var fullText: String {
        segments.map(\.text).joined(separator: "\n\n")
    }

    init(
        id: UUID = UUID(),
        title: String,
        segments: [ScriptSegment] = [],
        platform: SocialPlatform = .instagram,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.segments = segments
        self.platform = platform
        self.createdAt = createdAt
    }

    static let mock = VideoScript(
        title: "Creator Tips Reel",
        segments: [.mockHook, .mockBody, .mockCTA],
        platform: .instagram
    )

    static let mockList: [VideoScript] = [
        .mock,
        VideoScript(
            title: "LinkedIn Thought Leadership",
            segments: [
                ScriptSegment(type: .hook, text: "Most people get personal branding wrong.", duration: 3),
                ScriptSegment(type: .body, text: "It's not about perfection. It's about showing up consistently and providing value to your audience.", duration: 15),
                ScriptSegment(type: .transition, text: "Here's the framework I use.", duration: 2),
                ScriptSegment(type: .body, text: "Step 1: Define your niche. Step 2: Create a content calendar. Step 3: Engage daily.", duration: 20),
                ScriptSegment(type: .cta, text: "Connect with me for more insights on building your brand.", duration: 5),
            ],
            platform: .linkedin
        ),
    ]
}

// MARK: - Hook Template

struct HookTemplate: Identifiable, Codable {
    let id: UUID
    var name: String
    var pattern: String
    var example: String
    var performanceScore: Double
    var isFavorite: Bool

    init(
        id: UUID = UUID(),
        name: String,
        pattern: String,
        example: String,
        performanceScore: Double = 0,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.pattern = pattern
        self.example = example
        self.performanceScore = performanceScore
        self.isFavorite = isFavorite
    }

    /// Formatted score as percentage string.
    var formattedScore: String {
        "\(Int(performanceScore * 100))%"
    }

    static let mockList: [HookTemplate] = [
        HookTemplate(
            name: "Bold Statement",
            pattern: "[Contrarian opinion about topic].",
            example: "Most people get personal branding completely wrong.",
            performanceScore: 0.87
        ),
        HookTemplate(
            name: "Question",
            pattern: "Have you ever [common struggle]?",
            example: "Have you ever posted content that nobody saw?",
            performanceScore: 0.82
        ),
        HookTemplate(
            name: "Statistic",
            pattern: "[Surprising number]% of [audience] [unexpected behavior].",
            example: "90% of creators quit before reaching 1,000 followers.",
            performanceScore: 0.79
        ),
        HookTemplate(
            name: "Story",
            pattern: "[Time reference], I [relatable situation]. Here's what happened.",
            example: "Last year, I was about to give up on content creation. Here's what happened.",
            performanceScore: 0.84
        ),
        HookTemplate(
            name: "Controversy",
            pattern: "Unpopular opinion: [bold take on topic].",
            example: "Unpopular opinion: Hashtags don't matter anymore.",
            performanceScore: 0.91
        ),
        HookTemplate(
            name: "Curiosity Gap",
            pattern: "I discovered [result] by doing [unexpected action].",
            example: "I doubled my engagement by posting half as often.",
            performanceScore: 0.85
        ),
        HookTemplate(
            name: "List Tease",
            pattern: "[Number] [topic items] that will [desirable outcome].",
            example: "5 caption frameworks that will double your saves.",
            performanceScore: 0.76
        ),
        HookTemplate(
            name: "Fear of Missing Out",
            pattern: "If you're not [action], you're [consequence].",
            example: "If you're not repurposing your content, you're leaving growth on the table.",
            performanceScore: 0.73
        ),
    ]
}

// MARK: - Thread Draft

struct ThreadDraft: Identifiable, Codable {
    let id: UUID
    var posts: [String]
    var platform: SocialPlatform
    let createdAt: Date

    var postCount: Int { posts.count }

    init(
        id: UUID = UUID(),
        posts: [String] = [],
        platform: SocialPlatform = .x,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.posts = posts
        self.platform = platform
        self.createdAt = createdAt
    }

    static let mock = ThreadDraft(
        posts: [
            "Here's how I grew from 0 to 10K followers in 6 months (a thread):",
            "1/ I started by picking ONE platform and going all-in. Trying to be everywhere at once is the fastest way to burn out.",
            "2/ I posted every single day for 90 days. Not because every post was great, but because consistency beats perfection.",
            "3/ I spent 30 minutes engaging with others for every post I published. Community > content.",
            "4/ I repurposed my top-performing content across formats. One idea = 1 reel + 1 carousel + 1 thread.",
            "5/ The result? 10K followers and a community that actually engages. It wasn't luck. It was a system.\n\nFollow me for more creator strategies.",
        ],
        platform: .x
    )
}

// MARK: - AI Writing Request Bodies

struct CaptionRequest: Encodable {
    let prompt: String
    let platform: String
    let tone: String
}

struct ScriptRequest: Encodable {
    let topic: String
    let platform: String
    let duration: TimeInterval
}

struct HooksRequest: Encodable {
    let topic: String
    let count: Int
}

struct RephraseRequest: Encodable {
    let text: String
    let tone: String
}

struct ThreadRequest: Encodable {
    let topic: String
    let platform: String
    let postCount: Int
}

struct HashtagsRequest: Encodable {
    let caption: String
    let platform: String
    let count: Int
}

struct HashtagsResponse: Decodable {
    let hashtags: [String]
}
