import Foundation

// MARK: - ENVI-0401 Repurpose Format

/// Target output format when repurposing source content.
enum RepurposeFormat: String, Codable, CaseIterable, Identifiable {
    case reel
    case story
    case carousel
    case post
    case thread
    case blogExcerpt
    case newsletter
    case podcast

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .reel:         return "Reel"
        case .story:        return "Story"
        case .carousel:     return "Carousel"
        case .post:         return "Post"
        case .thread:       return "Thread"
        case .blogExcerpt:  return "Blog Excerpt"
        case .newsletter:   return "Newsletter"
        case .podcast:      return "Podcast"
        }
    }

    var systemImage: String {
        switch self {
        case .reel:         return "film"
        case .story:        return "rectangle.portrait"
        case .carousel:     return "square.stack"
        case .post:         return "square.and.pencil"
        case .thread:       return "text.bubble"
        case .blogExcerpt:  return "doc.richtext"
        case .newsletter:   return "envelope"
        case .podcast:      return "mic"
        }
    }
}

// MARK: - ENVI-0402 Repurpose Job Status

/// Lifecycle status of a repurposing job.
enum RepurposeJobStatus: String, Codable, CaseIterable, Identifiable {
    case queued
    case processing
    case completed
    case failed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .queued:      return "Queued"
        case .processing:  return "Processing"
        case .completed:   return "Completed"
        case .failed:      return "Failed"
        }
    }
}

// MARK: - ENVI-0403 Repurpose Result Status

/// Status of an individual format result within a repurpose job.
enum RepurposeResultStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case ready
    case failed

    var id: String { rawValue }
}

// MARK: - ENVI-0404 Repurpose Result

/// A single output produced by a repurpose job for one target format.
struct RepurposeResult: Identifiable, Codable, Hashable {
    let id: UUID
    let format: RepurposeFormat
    let caption: String
    let mediaURL: String?
    let platform: String
    let status: RepurposeResultStatus

    init(
        id: UUID = UUID(),
        format: RepurposeFormat,
        caption: String,
        mediaURL: String? = nil,
        platform: String = "",
        status: RepurposeResultStatus = .pending
    ) {
        self.id = id
        self.format = format
        self.caption = caption
        self.mediaURL = mediaURL
        self.platform = platform
        self.status = status
    }
}

// MARK: - ENVI-0405 Repurpose Job

/// A job that transforms source content into multiple target formats.
struct RepurposeJob: Identifiable, Codable, Hashable {
    let id: UUID
    let sourceAssetID: UUID
    let sourceFormat: RepurposeFormat
    let targetFormats: [RepurposeFormat]
    var status: RepurposeJobStatus
    var results: [RepurposeResult]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        sourceAssetID: UUID,
        sourceFormat: RepurposeFormat,
        targetFormats: [RepurposeFormat],
        status: RepurposeJobStatus = .queued,
        results: [RepurposeResult] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceAssetID = sourceAssetID
        self.sourceFormat = sourceFormat
        self.targetFormats = targetFormats
        self.status = status
        self.results = results
        self.createdAt = createdAt
    }
}

// MARK: - ENVI-0410 Repurpose Suggestion

/// AI-generated recommendation to repurpose a high-performing piece of content.
struct RepurposeSuggestion: Identifiable, Codable, Hashable {
    var id: UUID { sourceAssetID }
    let sourceAssetID: UUID
    let targetFormat: RepurposeFormat
    let reason: String
    let estimatedEngagement: Double

    init(
        sourceAssetID: UUID,
        targetFormat: RepurposeFormat,
        reason: String,
        estimatedEngagement: Double = 0
    ) {
        self.sourceAssetID = sourceAssetID
        self.targetFormat = targetFormat
        self.reason = reason
        self.estimatedEngagement = estimatedEngagement
    }
}

// MARK: - ENVI-0415 Derivative Post

/// A single derivative piece of content produced from cross-posting.
struct DerivativePost: Identifiable, Codable, Hashable {
    let id: UUID
    let platform: String
    let format: RepurposeFormat
    let caption: String
    let scheduledAt: Date?

    init(
        id: UUID = UUID(),
        platform: String,
        format: RepurposeFormat,
        caption: String,
        scheduledAt: Date? = nil
    ) {
        self.id = id
        self.platform = platform
        self.format = format
        self.caption = caption
        self.scheduledAt = scheduledAt
    }
}

// MARK: - ENVI-0416 Cross-Post Mapping

/// Maps a source post to all its derived outputs across platforms and formats.
struct CrossPostMapping: Identifiable, Codable, Hashable {
    let id: UUID
    let sourcePostID: UUID
    let sourceTitle: String
    let derivatives: [DerivativePost]

    init(
        id: UUID = UUID(),
        sourcePostID: UUID,
        sourceTitle: String = "",
        derivatives: [DerivativePost] = []
    ) {
        self.id = id
        self.sourcePostID = sourcePostID
        self.sourceTitle = sourceTitle
        self.derivatives = derivatives
    }
}

// MARK: - Mock Data

extension RepurposeJob {
    static let mockList: [RepurposeJob] = {
        let assetA = UUID()
        let assetB = UUID()
        return [
            RepurposeJob(
                sourceAssetID: assetA,
                sourceFormat: .reel,
                targetFormats: [.carousel, .thread, .newsletter],
                status: .completed,
                results: [
                    RepurposeResult(format: .carousel, caption: "Swipe through the 5 key takeaways from our latest reel.", platform: "Instagram", status: .ready),
                    RepurposeResult(format: .thread, caption: "1/ Here's why this reel blew up and what you can learn from it...", platform: "X", status: .ready),
                    RepurposeResult(format: .newsletter, caption: "This week: how a 30-second reel drove 12K new followers.", platform: "Email", status: .ready),
                ],
                createdAt: Date().addingTimeInterval(-86400)
            ),
            RepurposeJob(
                sourceAssetID: assetB,
                sourceFormat: .post,
                targetFormats: [.story, .reel],
                status: .processing,
                results: [
                    RepurposeResult(format: .story, caption: "Quick story version of yesterday's post.", platform: "Instagram", status: .pending),
                ],
                createdAt: Date()
            ),
        ]
    }()
}

extension RepurposeSuggestion {
    static let mockList: [RepurposeSuggestion] = [
        RepurposeSuggestion(
            sourceAssetID: UUID(),
            targetFormat: .carousel,
            reason: "This reel had 4x average engagement — a carousel breakdown could extend its reach.",
            estimatedEngagement: 8500
        ),
        RepurposeSuggestion(
            sourceAssetID: UUID(),
            targetFormat: .thread,
            reason: "Long-form captions perform well in your niche. Turn this post into a thread.",
            estimatedEngagement: 4200
        ),
        RepurposeSuggestion(
            sourceAssetID: UUID(),
            targetFormat: .newsletter,
            reason: "Your audience has high email open rates. Repurpose this blog excerpt.",
            estimatedEngagement: 3100
        ),
    ]
}

extension CrossPostMapping {
    static let mockList: [CrossPostMapping] = [
        CrossPostMapping(
            sourcePostID: UUID(),
            sourceTitle: "5 Tips for Better Content",
            derivatives: [
                DerivativePost(platform: "Instagram", format: .carousel, caption: "Swipe for 5 content tips..."),
                DerivativePost(platform: "X", format: .thread, caption: "1/ Five tips I wish I knew earlier..."),
                DerivativePost(platform: "TikTok", format: .reel, caption: "Content tips that actually work"),
                DerivativePost(platform: "Email", format: .newsletter, caption: "This week: 5 content tips you need"),
            ]
        ),
        CrossPostMapping(
            sourcePostID: UUID(),
            sourceTitle: "Behind the Scenes: Brand Shoot",
            derivatives: [
                DerivativePost(platform: "Instagram", format: .story, caption: "BTS from today's shoot"),
                DerivativePost(platform: "TikTok", format: .reel, caption: "POV: brand shoot day"),
            ]
        ),
    ]
}
