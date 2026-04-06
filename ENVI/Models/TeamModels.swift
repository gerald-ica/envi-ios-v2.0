import Foundation

// MARK: - Team Role

enum TeamRole: String, Codable, CaseIterable, Identifiable {
    case owner
    case admin
    case editor
    case viewer

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    var iconName: String {
        switch self {
        case .owner:  return "crown.fill"
        case .admin:  return "shield.checkered"
        case .editor: return "pencil.circle.fill"
        case .viewer: return "eye.fill"
        }
    }

    /// Roles that can be assigned by an admin (excludes owner).
    static var assignable: [TeamRole] {
        [.admin, .editor, .viewer]
    }
}

// MARK: - Workspace

struct Workspace: Identifiable, Codable {
    let id: UUID
    var name: String
    var ownerID: UUID
    var plan: WorkspacePlan
    var members: [TeamMember]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        ownerID: UUID = UUID(),
        plan: WorkspacePlan = .free,
        members: [TeamMember] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.ownerID = ownerID
        self.plan = plan
        self.members = members
        self.createdAt = createdAt
    }

    var memberCount: Int { members.count }

    static let mock = Workspace(
        name: "Envi Creative Studio",
        plan: .pro,
        members: TeamMember.mockList,
        createdAt: Date().addingTimeInterval(-86400 * 90)
    )

    static let mockList: [Workspace] = [
        Workspace(
            name: "Envi Creative Studio",
            plan: .pro,
            members: TeamMember.mockList,
            createdAt: Date().addingTimeInterval(-86400 * 90)
        ),
        Workspace(
            name: "Side Project",
            plan: .free,
            members: Array(TeamMember.mockList.prefix(2)),
            createdAt: Date().addingTimeInterval(-86400 * 30)
        ),
        Workspace(
            name: "Agency Partners",
            plan: .business,
            members: TeamMember.mockList,
            createdAt: Date().addingTimeInterval(-86400 * 180)
        ),
    ]
}

// MARK: - Workspace Plan

enum WorkspacePlan: String, Codable, CaseIterable, Identifiable {
    case free
    case pro
    case business

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }
}

// MARK: - Team Member

struct TeamMember: Identifiable, Codable {
    let id: UUID
    var name: String
    var email: String
    var role: TeamRole
    var avatarURL: String?
    let joinedAt: Date
    var status: MemberStatus

    init(
        id: UUID = UUID(),
        name: String,
        email: String,
        role: TeamRole = .viewer,
        avatarURL: String? = nil,
        joinedAt: Date = Date(),
        status: MemberStatus = .active
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.role = role
        self.avatarURL = avatarURL
        self.joinedAt = joinedAt
        self.status = status
    }

    static let mock = TeamMember(
        name: "Sarah Chen",
        email: "sarah@envi.app",
        role: .admin,
        joinedAt: Date().addingTimeInterval(-86400 * 60),
        status: .active
    )

    static let mockList: [TeamMember] = [
        TeamMember(
            name: "Sarah Chen",
            email: "sarah@envi.app",
            role: .owner,
            joinedAt: Date().addingTimeInterval(-86400 * 90),
            status: .active
        ),
        TeamMember(
            name: "Marcus Rivera",
            email: "marcus@envi.app",
            role: .admin,
            joinedAt: Date().addingTimeInterval(-86400 * 60),
            status: .active
        ),
        TeamMember(
            name: "Alex Kim",
            email: "alex@envi.app",
            role: .editor,
            joinedAt: Date().addingTimeInterval(-86400 * 30),
            status: .active
        ),
        TeamMember(
            name: "Jess Park",
            email: "jess@envi.app",
            role: .viewer,
            joinedAt: Date().addingTimeInterval(-86400 * 7),
            status: .invited
        ),
    ]
}

// MARK: - Member Status

enum MemberStatus: String, Codable, CaseIterable, Identifiable {
    case active
    case invited
    case deactivated

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }
}

// MARK: - Workspace Invite

struct WorkspaceInvite: Identifiable, Codable {
    let id: UUID
    var email: String
    var role: TeamRole
    var invitedBy: String
    var expiresAt: Date
    var status: InviteStatus

    init(
        id: UUID = UUID(),
        email: String,
        role: TeamRole = .viewer,
        invitedBy: String,
        expiresAt: Date = Date().addingTimeInterval(86400 * 7),
        status: InviteStatus = .pending
    ) {
        self.id = id
        self.email = email
        self.role = role
        self.invitedBy = invitedBy
        self.expiresAt = expiresAt
        self.status = status
    }

    var isExpired: Bool { expiresAt < Date() }

    static let mock = WorkspaceInvite(
        email: "newuser@example.com",
        role: .editor,
        invitedBy: "Sarah Chen"
    )

    static let mockList: [WorkspaceInvite] = [
        WorkspaceInvite(email: "newuser@example.com", role: .editor, invitedBy: "Sarah Chen"),
        WorkspaceInvite(email: "designer@studio.io", role: .viewer, invitedBy: "Marcus Rivera"),
    ]
}

// MARK: - Invite Status

enum InviteStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case accepted
    case expired
    case revoked

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pending:  return "Pending"
        case .accepted: return "Accepted"
        case .expired:  return "Expired"
        case .revoked:  return "Revoked"
        }
    }
}

// MARK: - Team Activity

struct TeamActivity: Identifiable, Codable {
    let id: UUID
    var memberName: String
    var action: String
    var target: String
    let timestamp: Date

    init(
        id: UUID = UUID(),
        memberName: String,
        action: String,
        target: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.memberName = memberName
        self.action = action
        self.target = target
        self.timestamp = timestamp
    }

    static let mock = TeamActivity(
        memberName: "Sarah Chen",
        action: "invited",
        target: "jess@envi.app",
        timestamp: Date().addingTimeInterval(-600)
    )

    static let mockList: [TeamActivity] = [
        TeamActivity(
            memberName: "Sarah Chen",
            action: "invited",
            target: "jess@envi.app",
            timestamp: Date().addingTimeInterval(-600)
        ),
        TeamActivity(
            memberName: "Marcus Rivera",
            action: "changed role to Editor for",
            target: "Alex Kim",
            timestamp: Date().addingTimeInterval(-3600)
        ),
        TeamActivity(
            memberName: "Sarah Chen",
            action: "created workspace",
            target: "Envi Creative Studio",
            timestamp: Date().addingTimeInterval(-86400)
        ),
        TeamActivity(
            memberName: "Alex Kim",
            action: "removed",
            target: "old-member@test.com",
            timestamp: Date().addingTimeInterval(-86400 * 2)
        ),
        TeamActivity(
            memberName: "Marcus Rivera",
            action: "upgraded plan to",
            target: "Pro",
            timestamp: Date().addingTimeInterval(-86400 * 3)
        ),
    ]
}
