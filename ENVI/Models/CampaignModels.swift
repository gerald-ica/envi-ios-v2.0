import Foundation

// MARK: - Campaign Status

enum CampaignStatus: String, Codable, CaseIterable, Identifiable {
    case draft
    case active
    case completed
    case archived

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    var iconName: String {
        switch self {
        case .draft:     return "doc"
        case .active:    return "bolt.fill"
        case .completed: return "checkmark.circle.fill"
        case .archived:  return "archivebox"
        }
    }
}

// MARK: - Sprint Column

enum SprintColumn: String, Codable, CaseIterable, Identifiable {
    case backlog
    case inProgress
    case review
    case done

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .backlog:    return "Backlog"
        case .inProgress: return "In Progress"
        case .review:     return "Review"
        case .done:       return "Done"
        }
    }
}

// MARK: - Approval Status

enum ApprovalStatus: String, Codable, CaseIterable {
    case pending
    case approved
    case revisionRequested
    case rejected

    var displayName: String {
        switch self {
        case .pending:           return "Pending"
        case .approved:          return "Approved"
        case .revisionRequested: return "Revision Requested"
        case .rejected:          return "Rejected"
        }
    }
}

// MARK: - Content Request Status

enum ContentRequestStatus: String, Codable, CaseIterable {
    case open
    case inProgress
    case completed

    var displayName: String {
        switch self {
        case .open:       return "Open"
        case .inProgress: return "In Progress"
        case .completed:  return "Completed"
        }
    }
}

// MARK: - Content Request Priority

enum ContentRequestPriority: String, Codable, CaseIterable {
    case low
    case medium
    case high
    case urgent

    var displayName: String { rawValue.capitalized }

    var sortOrder: Int {
        switch self {
        case .urgent: return 0
        case .high:   return 1
        case .medium: return 2
        case .low:    return 3
        }
    }
}

// MARK: - Campaign

struct Campaign: Identifiable, Codable {
    let id: UUID
    var name: String
    var objective: String
    var targetAudience: String
    var keyMessage: String
    var cta: String
    var deliverables: [String]
    var budget: Double
    var owner: String
    var deadline: Date
    var status: CampaignStatus
    var dependencies: [String]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        objective: String = "",
        targetAudience: String = "",
        keyMessage: String = "",
        cta: String = "",
        deliverables: [String] = [],
        budget: Double = 0,
        owner: String = "",
        deadline: Date = Date().addingTimeInterval(30 * 86400),
        status: CampaignStatus = .draft,
        dependencies: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.objective = objective
        self.targetAudience = targetAudience
        self.keyMessage = keyMessage
        self.cta = cta
        self.deliverables = deliverables
        self.budget = budget
        self.owner = owner
        self.deadline = deadline
        self.status = status
        self.dependencies = dependencies
        self.createdAt = createdAt
    }

    var progress: Double {
        guard !deliverables.isEmpty else { return 0 }
        // Progress derived from status as a simple heuristic
        switch status {
        case .draft:     return 0.0
        case .active:    return 0.5
        case .completed: return 1.0
        case .archived:  return 1.0
        }
    }

    var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: deadline).day ?? 0
    }

    static let budgetFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        return f
    }()

    var formattedBudget: String {
        Self.budgetFormatter.string(from: NSNumber(value: budget)) ?? "$\(Int(budget))"
    }

    static let mock = Campaign(
        name: "Summer Product Launch",
        objective: "Drive awareness for new product line",
        targetAudience: "18-35 creators and entrepreneurs",
        keyMessage: "Create without limits",
        cta: "Shop now",
        deliverables: ["Hero video", "5 social posts", "Email sequence", "Landing page"],
        budget: 12000,
        owner: "Marketing Team",
        deadline: Date().addingTimeInterval(45 * 86400),
        status: .active,
        dependencies: ["Brand kit approval", "Product photography"]
    )

    static let mockList: [Campaign] = [
        .mock,
        Campaign(
            name: "Creator Spotlight Series",
            objective: "Showcase top creators using ENVI",
            targetAudience: "Content creators",
            keyMessage: "Your content, amplified",
            cta: "Join ENVI",
            deliverables: ["Interview video", "Blog post", "Social clips"],
            budget: 5000,
            owner: "Content Lead",
            deadline: Date().addingTimeInterval(20 * 86400),
            status: .draft,
            dependencies: ["Creator outreach"]
        ),
        Campaign(
            name: "Q1 Brand Refresh",
            objective: "Update brand assets across all channels",
            targetAudience: "Existing customers",
            keyMessage: "Same mission, fresh look",
            cta: "Explore the new look",
            deliverables: ["Updated logo", "Social templates", "Email header"],
            budget: 8000,
            owner: "Design Lead",
            deadline: Date().addingTimeInterval(-5 * 86400),
            status: .completed,
            dependencies: []
        ),
    ]
}

// MARK: - Creative Brief

struct CreativeBrief: Identifiable, Codable {
    let id: UUID
    var campaignID: UUID
    var template: String
    var approvalStatus: ApprovalStatus
    var clientNotes: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        campaignID: UUID,
        template: String = "",
        approvalStatus: ApprovalStatus = .pending,
        clientNotes: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.campaignID = campaignID
        self.template = template
        self.approvalStatus = approvalStatus
        self.clientNotes = clientNotes
        self.createdAt = createdAt
    }

    static let mock = CreativeBrief(
        campaignID: Campaign.mock.id,
        template: "## Campaign Brief\n\n**Objective:** Drive summer launch awareness\n\n**Target Audience:** 18-35 creators\n\n**Key Deliverables:**\n- Hero video (60s)\n- 5 social posts\n- Email sequence\n\n**Timeline:** 6 weeks\n\n**Brand Guidelines:** Follow brand kit v2",
        approvalStatus: .pending,
        clientNotes: "Please ensure all visuals match the new palette."
    )

    static let mockList: [CreativeBrief] = [.mock]
}

// MARK: - Content Request

struct ContentRequest: Identifiable, Codable {
    let id: UUID
    var title: String
    var priority: ContentRequestPriority
    var assignee: String
    var dueDate: Date
    var status: ContentRequestStatus
    let createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        priority: ContentRequestPriority = .medium,
        assignee: String = "",
        dueDate: Date = Date().addingTimeInterval(7 * 86400),
        status: ContentRequestStatus = .open,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.priority = priority
        self.assignee = assignee
        self.dueDate = dueDate
        self.status = status
        self.createdAt = createdAt
    }

    static let mockList: [ContentRequest] = [
        ContentRequest(title: "Hero video storyboard", priority: .high, assignee: "Alex", status: .inProgress),
        ContentRequest(title: "Instagram carousel copy", priority: .medium, assignee: "Jordan"),
        ContentRequest(title: "Email subject lines", priority: .low, assignee: "Sam", status: .completed),
        ContentRequest(title: "Landing page wireframe", priority: .urgent, assignee: "Casey"),
    ]
}

// MARK: - Sprint Item

struct SprintItem: Identifiable, Codable {
    let id: UUID
    var title: String
    var column: SprintColumn
    var assignee: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        column: SprintColumn = .backlog,
        assignee: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.column = column
        self.assignee = assignee
        self.createdAt = createdAt
    }

    static let mockList: [SprintItem] = [
        SprintItem(title: "Draft hero script", column: .done, assignee: "Alex"),
        SprintItem(title: "Film B-roll", column: .inProgress, assignee: "Jordan"),
        SprintItem(title: "Design carousel slides", column: .inProgress, assignee: "Casey"),
        SprintItem(title: "Write email sequence", column: .review, assignee: "Sam"),
        SprintItem(title: "Set up tracking pixels", column: .backlog, assignee: ""),
        SprintItem(title: "Schedule social posts", column: .backlog, assignee: "Jordan"),
        SprintItem(title: "QA landing page", column: .backlog, assignee: ""),
    ]
}
