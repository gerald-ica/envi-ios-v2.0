import Foundation

// MARK: - Content Idea

struct ContentIdea: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var platform: SocialPlatform
    var format: ContentFormat
    var hookStyle: String
    var estimatedEngagement: Double
    var trendScore: Double
    var source: IdeaSource
    var boardColumn: IdeaBoardColumn
    let createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        platform: SocialPlatform = .instagram,
        format: ContentFormat = .post,
        hookStyle: String = "Question",
        estimatedEngagement: Double = 0.0,
        trendScore: Double = 0.0,
        source: IdeaSource = .ai,
        boardColumn: IdeaBoardColumn = .new,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.platform = platform
        self.format = format
        self.hookStyle = hookStyle
        self.estimatedEngagement = estimatedEngagement
        self.trendScore = trendScore
        self.source = source
        self.boardColumn = boardColumn
        self.createdAt = createdAt
    }

    static let hookStyles = ["Question", "Bold Statement", "Statistic", "Story", "Controversy", "How-To", "List"]

    static let mockList: [ContentIdea] = [
        ContentIdea(
            title: "Behind the scenes of my morning routine",
            description: "Show authentic daily prep process with raw, unfiltered footage.",
            platform: .instagram,
            format: .reel,
            hookStyle: "Story",
            estimatedEngagement: 4.2,
            trendScore: 78
        ),
        ContentIdea(
            title: "5 tools every creator needs in 2026",
            description: "Listicle-style carousel breaking down essential creator stack.",
            platform: .instagram,
            format: .carousel,
            hookStyle: "List",
            estimatedEngagement: 3.8,
            trendScore: 65
        ),
        ContentIdea(
            title: "Hot take: Threads is underrated for growth",
            description: "Contrarian opinion piece with data-backed insights.",
            platform: .threads,
            format: .post,
            hookStyle: "Controversy",
            estimatedEngagement: 5.1,
            trendScore: 82
        ),
        ContentIdea(
            title: "How I gained 10K followers in 30 days",
            description: "Step-by-step breakdown of growth strategy with proof.",
            platform: .tiktok,
            format: .reel,
            hookStyle: "How-To",
            estimatedEngagement: 6.3,
            trendScore: 91,
            source: .trend
        ),
    ]
}

// MARK: - Content Format

enum ContentFormat: String, Codable, CaseIterable {
    case post
    case reel
    case story
    case carousel
    case thread
    case article
    case live

    var displayName: String { rawValue.capitalized }

    var iconName: String {
        switch self {
        case .post:     return "square.and.pencil"
        case .reel:     return "video"
        case .story:    return "rectangle.portrait"
        case .carousel: return "square.stack"
        case .thread:   return "text.alignleft"
        case .article:  return "doc.text"
        case .live:     return "antenna.radiowaves.left.and.right"
        }
    }
}

// MARK: - Idea Source

enum IdeaSource: String, Codable, CaseIterable {
    case ai
    case trend
    case competitor
    case manual

    var displayName: String {
        switch self {
        case .ai:         return "AI Generated"
        case .trend:      return "Trending"
        case .competitor: return "Competitor"
        case .manual:     return "Manual"
        }
    }

    var iconName: String {
        switch self {
        case .ai:         return "sparkles"
        case .trend:      return "chart.line.uptrend.xyaxis"
        case .competitor: return "person.2"
        case .manual:     return "hand.draw"
        }
    }
}

// MARK: - Idea Board Column

enum IdeaBoardColumn: String, Codable, CaseIterable {
    case new
    case inProgress
    case published

    var displayName: String {
        switch self {
        case .new:        return "New"
        case .inProgress: return "In Progress"
        case .published:  return "Published"
        }
    }
}

// MARK: - Trend Topic

struct TrendTopic: Identifiable, Codable {
    let id: UUID
    var topic: String
    var momentum: Double // 0-100
    var platforms: [SocialPlatform]
    var relatedHashtags: [String]
    var category: String
    let detectedAt: Date

    init(
        id: UUID = UUID(),
        topic: String,
        momentum: Double = 50,
        platforms: [SocialPlatform] = [.instagram],
        relatedHashtags: [String] = [],
        category: String = "General",
        detectedAt: Date = Date()
    ) {
        self.id = id
        self.topic = topic
        self.momentum = momentum
        self.platforms = platforms
        self.relatedHashtags = relatedHashtags
        self.category = category
        self.detectedAt = detectedAt
    }

    static let mockList: [TrendTopic] = [
        TrendTopic(
            topic: "AI-generated content ethics",
            momentum: 92,
            platforms: [.instagram, .tiktok, .threads],
            relatedHashtags: ["#AIContent", "#CreatorEthics", "#Authenticity"],
            category: "Tech"
        ),
        TrendTopic(
            topic: "Micro-community building",
            momentum: 78,
            platforms: [.threads, .linkedin],
            relatedHashtags: ["#CommunityBuilding", "#NicheAudience", "#Engagement"],
            category: "Growth"
        ),
        TrendTopic(
            topic: "Short-form documentary style",
            momentum: 85,
            platforms: [.tiktok, .youtube, .instagram],
            relatedHashtags: ["#MiniDoc", "#Storytelling", "#ContentCreation"],
            category: "Format"
        ),
        TrendTopic(
            topic: "Creator burnout recovery",
            momentum: 67,
            platforms: [.instagram, .threads],
            relatedHashtags: ["#MentalHealth", "#CreatorLife", "#Burnout"],
            category: "Lifestyle"
        ),
    ]
}

// MARK: - Competitor Insight

struct CompetitorInsight: Identifiable, Codable {
    let id: UUID
    var competitorHandle: String
    var platform: SocialPlatform
    var contentType: ContentFormat
    var engagementRate: Double
    var takeaway: String
    var followerCount: Int
    var postFrequency: String
    let analyzedAt: Date

    init(
        id: UUID = UUID(),
        competitorHandle: String,
        platform: SocialPlatform = .instagram,
        contentType: ContentFormat = .post,
        engagementRate: Double = 0.0,
        takeaway: String = "",
        followerCount: Int = 0,
        postFrequency: String = "Daily",
        analyzedAt: Date = Date()
    ) {
        self.id = id
        self.competitorHandle = competitorHandle
        self.platform = platform
        self.contentType = contentType
        self.engagementRate = engagementRate
        self.takeaway = takeaway
        self.followerCount = followerCount
        self.postFrequency = postFrequency
        self.analyzedAt = analyzedAt
    }

    static let mockList: [CompetitorInsight] = [
        CompetitorInsight(
            competitorHandle: "@creator.pro",
            platform: .instagram,
            contentType: .reel,
            engagementRate: 5.4,
            takeaway: "Strong hooks in first 2 seconds drive 3x watch-through rate.",
            followerCount: 125_000,
            postFrequency: "2x daily"
        ),
        CompetitorInsight(
            competitorHandle: "@growth.hacker",
            platform: .tiktok,
            contentType: .reel,
            engagementRate: 8.2,
            takeaway: "Leverages trending sounds within 24 hours of release.",
            followerCount: 340_000,
            postFrequency: "3x daily"
        ),
        CompetitorInsight(
            competitorHandle: "@thought.leader",
            platform: .linkedin,
            contentType: .post,
            engagementRate: 3.1,
            takeaway: "Long-form text posts with personal stories outperform link shares 4:1.",
            followerCount: 89_000,
            postFrequency: "Daily"
        ),
    ]
}

// MARK: - Niche Keyword

struct NicheKeyword: Identifiable, Codable {
    let id: UUID
    var keyword: String
    var searchVolume: Int
    var difficulty: Double // 0-100
    var opportunity: Double // 0-100
    var relatedTerms: [String]

    init(
        id: UUID = UUID(),
        keyword: String,
        searchVolume: Int = 0,
        difficulty: Double = 50,
        opportunity: Double = 50,
        relatedTerms: [String] = []
    ) {
        self.id = id
        self.keyword = keyword
        self.searchVolume = searchVolume
        self.difficulty = difficulty
        self.opportunity = opportunity
        self.relatedTerms = relatedTerms
    }

    static let mockList: [NicheKeyword] = [
        NicheKeyword(
            keyword: "content creation tips",
            searchVolume: 14_800,
            difficulty: 72,
            opportunity: 45,
            relatedTerms: ["creator tips", "social media tips", "content strategy"]
        ),
        NicheKeyword(
            keyword: "instagram reels tutorial",
            searchVolume: 22_400,
            difficulty: 85,
            opportunity: 30,
            relatedTerms: ["reels editing", "viral reels", "reel ideas"]
        ),
        NicheKeyword(
            keyword: "niche audience growth",
            searchVolume: 3_200,
            difficulty: 35,
            opportunity: 82,
            relatedTerms: ["audience building", "niche marketing", "target audience"]
        ),
        NicheKeyword(
            keyword: "creator monetization 2026",
            searchVolume: 8_900,
            difficulty: 48,
            opportunity: 74,
            relatedTerms: ["make money creating", "creator economy", "monetize content"]
        ),
    ]
}

// MARK: - Idea Board

struct IdeaBoard: Identifiable, Codable {
    let id: UUID
    var name: String
    var ideas: [ContentIdea]
    var campaignID: UUID?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        ideas: [ContentIdea] = [],
        campaignID: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.ideas = ideas
        self.campaignID = campaignID
        self.createdAt = createdAt
    }

    var newIdeas: [ContentIdea] { ideas.filter { $0.boardColumn == .new } }
    var inProgressIdeas: [ContentIdea] { ideas.filter { $0.boardColumn == .inProgress } }
    var publishedIdeas: [ContentIdea] { ideas.filter { $0.boardColumn == .published } }

    static let mock = IdeaBoard(
        name: "Q2 Content Sprint",
        ideas: ContentIdea.mockList
    )

    static let mockList: [IdeaBoard] = [
        IdeaBoard(name: "Q2 Content Sprint", ideas: ContentIdea.mockList),
        IdeaBoard(name: "Brand Launch Series", ideas: Array(ContentIdea.mockList.prefix(2))),
    ]
}

// MARK: - Idea Generation Request

struct IdeaGenerationRequest: Encodable {
    let prompt: String
    let platform: SocialPlatform
    let count: Int
}
