import Foundation

// MARK: - Scheduled Post

struct ScheduledPost: Identifiable, Codable {
    let id: UUID
    var caption: String
    var platforms: [SocialPlatform]
    var scheduledAt: Date
    var status: ScheduledPostStatus
    var mediaAssetIDs: [String]
    var campaignID: UUID?
    var approvalStatus: ApprovalStatus

    init(
        id: UUID = UUID(),
        caption: String,
        platforms: [SocialPlatform],
        scheduledAt: Date,
        status: ScheduledPostStatus = .pending,
        mediaAssetIDs: [String] = [],
        campaignID: UUID? = nil,
        approvalStatus: ApprovalStatus = .notRequired
    ) {
        self.id = id
        self.caption = caption
        self.platforms = platforms
        self.scheduledAt = scheduledAt
        self.status = status
        self.mediaAssetIDs = mediaAssetIDs
        self.campaignID = campaignID
        self.approvalStatus = approvalStatus
    }
}

enum ScheduledPostStatus: String, Codable, CaseIterable {
    case pending
    case processing
    case completed
    case failed
    case cancelled

    var displayName: String {
        switch self {
        case .pending:    return "Pending"
        case .processing: return "Processing"
        case .completed:  return "Completed"
        case .failed:     return "Failed"
        case .cancelled:  return "Cancelled"
        }
    }
}

enum ApprovalStatus: String, Codable, CaseIterable {
    case notRequired = "not_required"
    case pending
    case approved
    case rejected

    var displayName: String {
        switch self {
        case .notRequired: return "Not Required"
        case .pending:     return "Pending"
        case .approved:    return "Approved"
        case .rejected:    return "Rejected"
        }
    }
}

// MARK: - Publish Queue

struct PublishQueue: Codable {
    let pendingCount: Int
    let processingCount: Int
    let completedCount: Int
    let failedCount: Int

    var totalCount: Int { pendingCount + processingCount + completedCount + failedCount }

    static let empty = PublishQueue(pendingCount: 0, processingCount: 0, completedCount: 0, failedCount: 0)
}

// MARK: - Publish Result

struct PublishResult: Identifiable, Codable {
    let id: UUID
    let platform: SocialPlatform
    let postID: String?
    let postURL: String?
    let publishedAt: Date?
    let error: String?

    var isSuccess: Bool { error == nil && postID != nil }

    init(
        id: UUID = UUID(),
        platform: SocialPlatform,
        postID: String? = nil,
        postURL: String? = nil,
        publishedAt: Date? = nil,
        error: String? = nil
    ) {
        self.id = id
        self.platform = platform
        self.postID = postID
        self.postURL = postURL
        self.publishedAt = publishedAt
        self.error = error
    }
}

// MARK: - Recurring Schedule

struct RecurringSchedule: Identifiable, Codable {
    let id: UUID
    var frequency: RecurringFrequency
    var dayOfWeek: Int
    var hour: Int
    var platforms: [SocialPlatform]
    var isActive: Bool

    init(
        id: UUID = UUID(),
        frequency: RecurringFrequency = .weekly,
        dayOfWeek: Int = 1,
        hour: Int = 9,
        platforms: [SocialPlatform] = [],
        isActive: Bool = true
    ) {
        self.id = id
        self.frequency = frequency
        self.dayOfWeek = dayOfWeek
        self.hour = hour
        self.platforms = platforms
        self.isActive = isActive
    }
}

enum RecurringFrequency: String, Codable, CaseIterable {
    case daily
    case weekly
    case biweekly
    case monthly

    var displayName: String {
        switch self {
        case .daily:    return "Daily"
        case .weekly:   return "Weekly"
        case .biweekly: return "Bi-Weekly"
        case .monthly:  return "Monthly"
        }
    }
}

// MARK: - Distribution Rule

struct DistributionRule: Identifiable, Codable {
    let id: UUID
    var platform: SocialPlatform
    var autoCaption: Bool
    var autoHashtags: Bool
    var autoFormat: Bool

    init(
        id: UUID = UUID(),
        platform: SocialPlatform,
        autoCaption: Bool = false,
        autoHashtags: Bool = false,
        autoFormat: Bool = true
    ) {
        self.id = id
        self.platform = platform
        self.autoCaption = autoCaption
        self.autoHashtags = autoHashtags
        self.autoFormat = autoFormat
    }
}

// MARK: - Mock Data

extension ScheduledPost {
    static var mockPosts: [ScheduledPost] {
        let calendar = Calendar.current
        let now = Date()
        return [
            ScheduledPost(
                caption: "Exciting product launch coming soon! Stay tuned for something amazing.",
                platforms: [.instagram, .tiktok],
                scheduledAt: calendar.date(byAdding: .hour, value: 4, to: now) ?? now,
                status: .pending,
                mediaAssetIDs: ["asset_001"],
                approvalStatus: .approved
            ),
            ScheduledPost(
                caption: "Behind the scenes of our creative process. Thread incoming.",
                platforms: [.x, .threads],
                scheduledAt: calendar.date(byAdding: .day, value: 1, to: now) ?? now,
                status: .pending,
                mediaAssetIDs: ["asset_002", "asset_003"],
                approvalStatus: .pending
            ),
            ScheduledPost(
                caption: "Weekly industry insights and what they mean for creators.",
                platforms: [.linkedin],
                scheduledAt: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
                status: .completed,
                mediaAssetIDs: [],
                approvalStatus: .notRequired
            ),
            ScheduledPost(
                caption: "New tutorial dropping this weekend!",
                platforms: [.youtube, .instagram],
                scheduledAt: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
                status: .failed,
                mediaAssetIDs: ["asset_004"],
                approvalStatus: .approved
            ),
            ScheduledPost(
                caption: "Quick tip for growing your audience organically.",
                platforms: [.tiktok],
                scheduledAt: calendar.date(byAdding: .hour, value: 2, to: now) ?? now,
                status: .processing,
                mediaAssetIDs: ["asset_005"],
                approvalStatus: .notRequired
            ),
        ]
    }
}

extension PublishQueue {
    static let mock = PublishQueue(pendingCount: 3, processingCount: 1, completedCount: 12, failedCount: 2)
}

extension PublishResult {
    static var mock: [PublishResult] {
        let now = Date()
        return [
            PublishResult(
                platform: .instagram,
                postID: "ig_12345",
                postURL: "https://instagram.com/p/12345",
                publishedAt: now.addingTimeInterval(-3600)
            ),
            PublishResult(
                platform: .tiktok,
                postID: "tt_67890",
                postURL: "https://tiktok.com/@user/video/67890",
                publishedAt: now.addingTimeInterval(-3500)
            ),
            PublishResult(
                platform: .x,
                postID: nil,
                postURL: nil,
                publishedAt: nil,
                error: "Rate limit exceeded. Try again in 15 minutes."
            ),
        ]
    }
}

extension RecurringSchedule {
    static var mock: [RecurringSchedule] {
        [
            RecurringSchedule(
                frequency: .weekly,
                dayOfWeek: 2,
                hour: 10,
                platforms: [.instagram, .tiktok]
            ),
            RecurringSchedule(
                frequency: .daily,
                dayOfWeek: 0,
                hour: 9,
                platforms: [.x]
            ),
        ]
    }
}

extension DistributionRule {
    static var mock: [DistributionRule] {
        SocialPlatform.allCases.map { platform in
            DistributionRule(
                platform: platform,
                autoCaption: platform != .linkedin,
                autoHashtags: platform == .instagram || platform == .tiktok,
                autoFormat: true
            )
        }
    }
}
