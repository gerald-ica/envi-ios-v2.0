import Foundation

// MARK: - Review Status

enum ReviewStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case inReview
    case approved
    case changesRequested
    case rejected

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pending:          return "Pending"
        case .inReview:         return "In Review"
        case .approved:         return "Approved"
        case .changesRequested: return "Changes Requested"
        case .rejected:         return "Rejected"
        }
    }

    var iconName: String {
        switch self {
        case .pending:          return "clock"
        case .inReview:         return "eye"
        case .approved:         return "checkmark.circle.fill"
        case .changesRequested: return "exclamationmark.triangle"
        case .rejected:         return "xmark.circle.fill"
        }
    }
}

// MARK: - Review Comment

struct ReviewComment: Identifiable, Codable {
    let id: UUID
    var authorName: String
    var text: String
    var timestamp: Date
    var attachmentURL: String?
    var resolved: Bool

    init(
        id: UUID = UUID(),
        authorName: String,
        text: String,
        timestamp: Date = Date(),
        attachmentURL: String? = nil,
        resolved: Bool = false
    ) {
        self.id = id
        self.authorName = authorName
        self.text = text
        self.timestamp = timestamp
        self.attachmentURL = attachmentURL
        self.resolved = resolved
    }

    static let mock = ReviewComment(
        authorName: "Sarah Chen",
        text: "The color grading looks great, but can we adjust the opening frame?"
    )

    static let mockList: [ReviewComment] = [
        ReviewComment(
            authorName: "Sarah Chen",
            text: "The color grading looks great, but can we adjust the opening frame?",
            timestamp: Date().addingTimeInterval(-3600)
        ),
        ReviewComment(
            authorName: "Marcus Rivera",
            text: "Approved the copy. Ready for final sign-off.",
            timestamp: Date().addingTimeInterval(-1800),
            resolved: true
        ),
        ReviewComment(
            authorName: "Alex Kim",
            text: "Can we swap the CTA to something more action-oriented?",
            timestamp: Date().addingTimeInterval(-600)
        ),
    ]
}

// MARK: - Review Request

struct ReviewRequest: Identifiable, Codable {
    let id: UUID
    var contentID: UUID
    var contentTitle: String
    var reviewerID: UUID
    var reviewerName: String
    var status: ReviewStatus
    var deadline: Date?
    var comments: [ReviewComment]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        contentID: UUID = UUID(),
        contentTitle: String,
        reviewerID: UUID = UUID(),
        reviewerName: String,
        status: ReviewStatus = .pending,
        deadline: Date? = nil,
        comments: [ReviewComment] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.contentID = contentID
        self.contentTitle = contentTitle
        self.reviewerID = reviewerID
        self.reviewerName = reviewerName
        self.status = status
        self.deadline = deadline
        self.comments = comments
        self.createdAt = createdAt
    }

    var commentCount: Int { comments.count }
    var unresolvedCount: Int { comments.filter { !$0.resolved }.count }

    var isOverdue: Bool {
        guard let deadline else { return false }
        return deadline < Date() && status != .approved && status != .rejected
    }

    static let mock = ReviewRequest(
        contentTitle: "Summer Campaign — Hero Video",
        reviewerName: "Sarah Chen",
        status: .inReview,
        deadline: Date().addingTimeInterval(86400 * 2),
        comments: ReviewComment.mockList
    )

    static let mockList: [ReviewRequest] = [
        ReviewRequest(
            contentTitle: "Summer Campaign — Hero Video",
            reviewerName: "Sarah Chen",
            status: .inReview,
            deadline: Date().addingTimeInterval(86400 * 2),
            comments: ReviewComment.mockList
        ),
        ReviewRequest(
            contentTitle: "Product Launch Carousel",
            reviewerName: "Marcus Rivera",
            status: .pending,
            deadline: Date().addingTimeInterval(86400 * 5),
            comments: []
        ),
        ReviewRequest(
            contentTitle: "Brand Story Reel",
            reviewerName: "Alex Kim",
            status: .approved,
            deadline: Date().addingTimeInterval(-86400),
            comments: [ReviewComment.mock]
        ),
        ReviewRequest(
            contentTitle: "Q3 Newsletter Header",
            reviewerName: "Jess Park",
            status: .changesRequested,
            deadline: Date().addingTimeInterval(86400),
            comments: ReviewComment.mockList
        ),
    ]
}

// MARK: - Approval Step

struct ApprovalStep: Identifiable, Codable {
    let id: UUID
    var role: String
    var status: ReviewStatus
    var approverName: String?
    var decidedAt: Date?

    init(
        id: UUID = UUID(),
        role: String,
        status: ReviewStatus = .pending,
        approverName: String? = nil,
        decidedAt: Date? = nil
    ) {
        self.id = id
        self.role = role
        self.status = status
        self.approverName = approverName
        self.decidedAt = decidedAt
    }
}

// MARK: - Approval Workflow

struct ApprovalWorkflow: Identifiable, Codable {
    let id: UUID
    var name: String
    var steps: [ApprovalStep]

    init(
        id: UUID = UUID(),
        name: String,
        steps: [ApprovalStep] = []
    ) {
        self.id = id
        self.name = name
        self.steps = steps
    }

    var completedSteps: Int { steps.filter { $0.status == .approved }.count }
    var progress: Double {
        guard !steps.isEmpty else { return 0 }
        return Double(completedSteps) / Double(steps.count)
    }

    static let mock = ApprovalWorkflow(
        name: "Standard Review",
        steps: [
            ApprovalStep(role: "Creative Director", status: .approved, approverName: "Sarah Chen", decidedAt: Date().addingTimeInterval(-7200)),
            ApprovalStep(role: "Brand Manager", status: .inReview, approverName: "Marcus Rivera"),
            ApprovalStep(role: "Legal", status: .pending),
        ]
    )
}

// MARK: - Share Permission

enum SharePermission: String, Codable, CaseIterable, Identifiable {
    case viewOnly
    case comment
    case edit

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .viewOnly: return "View Only"
        case .comment:  return "Comment"
        case .edit:     return "Edit"
        }
    }

    var iconName: String {
        switch self {
        case .viewOnly: return "eye"
        case .comment:  return "bubble.left"
        case .edit:     return "pencil"
        }
    }
}

// MARK: - Share Link

struct ShareLink: Identifiable, Codable {
    let id: UUID
    var contentID: UUID
    var url: String
    var expiresAt: Date?
    var permissions: SharePermission
    var viewCount: Int

    init(
        id: UUID = UUID(),
        contentID: UUID = UUID(),
        url: String = "",
        expiresAt: Date? = nil,
        permissions: SharePermission = .viewOnly,
        viewCount: Int = 0
    ) {
        self.id = id
        self.contentID = contentID
        self.url = url
        self.expiresAt = expiresAt
        self.permissions = permissions
        self.viewCount = viewCount
    }

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt < Date()
    }

    static let mock = ShareLink(
        url: "https://envi.app/share/abc123",
        expiresAt: Date().addingTimeInterval(86400 * 7),
        permissions: .viewOnly,
        viewCount: 42
    )
}
