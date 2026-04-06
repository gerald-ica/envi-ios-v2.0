import Foundation

// MARK: - Brand Kit

struct BrandKit: Identifiable, Codable {
    let id: UUID
    var name: String
    var primaryColor: String
    var secondaryColor: String
    var accentColor: String
    var backgroundColor: String
    var headingFont: String
    var bodyFont: String
    var logoURL: String?
    var watermarkURL: String?
    var voiceTone: String // "Professional", "Casual", "Bold", "Playful"
    var hashtags: [String]
    var defaultCTA: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        primaryColor: String = "#000000",
        secondaryColor: String = "#1A1A1A",
        accentColor: String = "#30217C",
        backgroundColor: String = "#FFFFFF",
        headingFont: String = "Inter-Bold",
        bodyFont: String = "Inter-Regular",
        logoURL: String? = nil,
        watermarkURL: String? = nil,
        voiceTone: String = "Professional",
        hashtags: [String] = [],
        defaultCTA: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.accentColor = accentColor
        self.backgroundColor = backgroundColor
        self.headingFont = headingFont
        self.bodyFont = bodyFont
        self.logoURL = logoURL
        self.watermarkURL = watermarkURL
        self.voiceTone = voiceTone
        self.hashtags = hashtags
        self.defaultCTA = defaultCTA
        self.createdAt = createdAt
    }

    static let voiceTones = ["Professional", "Casual", "Bold", "Playful"]

    static let availableFonts = [
        "Inter-Regular", "Inter-Medium", "Inter-SemiBold", "Inter-Bold",
        "Inter-ExtraBold", "Inter-Black", "SpaceMono-Regular", "SpaceMono-Bold"
    ]

    static let mock = BrandKit(
        name: "My Brand",
        primaryColor: "#000000",
        secondaryColor: "#1A1A1A",
        accentColor: "#30217C",
        backgroundColor: "#FFFFFF",
        headingFont: "Inter-Bold",
        bodyFont: "Inter-Regular",
        voiceTone: "Professional",
        hashtags: ["#envi", "#creator"],
        defaultCTA: "Follow for more"
    )

    static let mockList: [BrandKit] = [
        BrandKit(
            name: "Personal Brand",
            primaryColor: "#000000",
            secondaryColor: "#333333",
            accentColor: "#30217C",
            backgroundColor: "#FFFFFF",
            voiceTone: "Professional",
            hashtags: ["#creator", "#content"]
        ),
        BrandKit(
            name: "Side Project",
            primaryColor: "#1A1A1A",
            secondaryColor: "#4A4A4A",
            accentColor: "#E4405F",
            backgroundColor: "#F4F4F4",
            voiceTone: "Casual",
            hashtags: ["#project", "#launch"]
        ),
    ]
}

// MARK: - Content Template

struct ContentTemplate: Identifiable, Codable {
    let id: UUID
    var name: String
    var category: TemplateCategory
    var captionTemplate: String
    var hashtagSets: [[String]]
    var suggestedPlatforms: [SocialPlatform]
    var contentKind: String
    var brandKitID: UUID?
    var aspectRatio: String
    var hookStyle: String?
    var ctaStyle: String?
    var usageCount: Int
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        category: TemplateCategory = .post,
        captionTemplate: String = "",
        hashtagSets: [[String]] = [],
        suggestedPlatforms: [SocialPlatform] = [.instagram],
        contentKind: String = "photo",
        brandKitID: UUID? = nil,
        aspectRatio: String = "1:1",
        hookStyle: String? = nil,
        ctaStyle: String? = nil,
        usageCount: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.captionTemplate = captionTemplate
        self.hashtagSets = hashtagSets
        self.suggestedPlatforms = suggestedPlatforms
        self.contentKind = contentKind
        self.brandKitID = brandKitID
        self.aspectRatio = aspectRatio
        self.hookStyle = hookStyle
        self.ctaStyle = ctaStyle
        self.usageCount = usageCount
        self.createdAt = createdAt
    }

    static let aspectRatios = ["1:1", "4:5", "9:16", "16:9"]

    static let hookStyles = ["Question", "Bold Statement", "Statistic", "Story", "Controversy"]

    static let ctaStyles = ["Follow for more", "Link in bio", "Save this", "Share with a friend", "Comment below"]

    static let mockList: [ContentTemplate] = [
        ContentTemplate(
            name: "Instagram Reel Hook",
            category: .reel,
            captionTemplate: "{hook}\n\n{body}\n\n{cta}",
            hashtagSets: [["#reels", "#trending"], ["#viral", "#fyp"]],
            suggestedPlatforms: [.instagram, .tiktok],
            contentKind: "video",
            aspectRatio: "9:16",
            hookStyle: "Question",
            ctaStyle: "Follow for more",
            usageCount: 12
        ),
        ContentTemplate(
            name: "LinkedIn Thought Piece",
            category: .post,
            captionTemplate: "{hook}\n\n{body}\n\nThoughts? {cta}",
            hashtagSets: [["#leadership", "#growth"]],
            suggestedPlatforms: [.linkedin],
            contentKind: "textPost",
            aspectRatio: "1:1",
            hookStyle: "Bold Statement",
            usageCount: 5
        ),
        ContentTemplate(
            name: "Carousel Breakdown",
            category: .carousel,
            captionTemplate: "{hook}\n\nSwipe to learn more.\n\n{body}\n\n{cta}",
            hashtagSets: [["#carousel", "#tips"]],
            suggestedPlatforms: [.instagram],
            contentKind: "carousel",
            aspectRatio: "4:5",
            hookStyle: "Statistic",
            ctaStyle: "Save this",
            usageCount: 8
        ),
        ContentTemplate(
            name: "Story Poll",
            category: .story,
            captionTemplate: "{hook}\n\nWhich do you prefer?",
            hashtagSets: [],
            suggestedPlatforms: [.instagram],
            contentKind: "photo",
            aspectRatio: "9:16",
            usageCount: 3
        ),
    ]
}

// MARK: - Template Category

enum TemplateCategory: String, Codable, CaseIterable {
    case reel
    case story
    case carousel
    case post
    case thread
    case article
    case ad

    var displayName: String {
        rawValue.capitalized
    }

    var iconName: String {
        switch self {
        case .reel:     return "video"
        case .story:    return "rectangle.portrait"
        case .carousel: return "square.stack"
        case .post:     return "square.and.pencil"
        case .thread:   return "text.alignleft"
        case .article:  return "doc.text"
        case .ad:       return "megaphone"
        }
    }
}

// MARK: - Template Variation

struct TemplateVariation: Identifiable, Codable {
    let id: UUID
    let templateID: UUID
    var name: String
    var captionVariant: String
    var colorOverride: String?

    init(
        id: UUID = UUID(),
        templateID: UUID,
        name: String,
        captionVariant: String,
        colorOverride: String? = nil
    ) {
        self.id = id
        self.templateID = templateID
        self.name = name
        self.captionVariant = captionVariant
        self.colorOverride = colorOverride
    }
}

// MARK: - Caption Style Guide

struct CaptionStyleGuide: Codable {
    var maxLength: Int
    var emojiUsage: EmojiPolicy
    var hashtagCount: Int
    var ctaPosition: CTAPosition
    var voiceExamples: [String]

    enum EmojiPolicy: String, Codable, CaseIterable {
        case none
        case minimal
        case moderate
        case heavy

        var displayName: String { rawValue.capitalized }
    }

    enum CTAPosition: String, Codable, CaseIterable {
        case beginning
        case end
        case inline
        case none

        var displayName: String { rawValue.capitalized }
    }

    init(
        maxLength: Int = 2200,
        emojiUsage: EmojiPolicy = .minimal,
        hashtagCount: Int = 5,
        ctaPosition: CTAPosition = .end,
        voiceExamples: [String] = []
    ) {
        self.maxLength = maxLength
        self.emojiUsage = emojiUsage
        self.hashtagCount = hashtagCount
        self.ctaPosition = ctaPosition
        self.voiceExamples = voiceExamples
    }

    static let mock = CaptionStyleGuide(
        maxLength: 2200,
        emojiUsage: .minimal,
        hashtagCount: 5,
        ctaPosition: .end,
        voiceExamples: [
            "Here's what I learned building my brand from scratch.",
            "3 things nobody tells you about content creation.",
        ]
    )
}
