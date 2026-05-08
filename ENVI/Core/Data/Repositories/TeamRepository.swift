import Foundation

// MARK: - Protocol

protocol TeamRepository {
    // Workspaces
    func fetchWorkspaces() async throws -> [Workspace]
    func createWorkspace(name: String, plan: WorkspacePlan) async throws -> Workspace

    // Members
    func fetchMembers(workspaceID: UUID) async throws -> [TeamMember]
    func inviteMember(email: String, role: TeamRole, to workspaceID: UUID) async throws -> WorkspaceInvite
    func updateMemberRole(memberID: UUID, role: TeamRole, in workspaceID: UUID) async throws
    func removeMember(memberID: UUID, from workspaceID: UUID) async throws

    // Activity
    func fetchActivity(workspaceID: UUID) async throws -> [TeamActivity]
}

// MARK: - Mock Implementation

final class MockTeamRepository: TeamRepository {
    private var workspaces: [Workspace] = Workspace.mockList
    private var activities: [TeamActivity] = TeamActivity.mockList

    func fetchWorkspaces() async throws -> [Workspace] {
        workspaces
    }

    func createWorkspace(name: String, plan: WorkspacePlan) async throws -> Workspace {
        let workspace = Workspace(name: name, plan: plan)
        workspaces.insert(workspace, at: 0)
        return workspace
    }

    func fetchMembers(workspaceID: UUID) async throws -> [TeamMember] {
        guard let workspace = workspaces.first(where: { $0.id == workspaceID }) else {
            throw TeamError.notFound
        }
        return workspace.members
    }

    func inviteMember(email: String, role: TeamRole, to workspaceID: UUID) async throws -> WorkspaceInvite {
        guard let index = workspaces.firstIndex(where: { $0.id == workspaceID }) else {
            throw TeamError.notFound
        }
        let member = TeamMember(name: email.components(separatedBy: "@").first ?? email, email: email, role: role, status: .invited)
        workspaces[index].members.append(member)

        let invite = WorkspaceInvite(email: email, role: role, invitedBy: "You")
        activities.insert(
            TeamActivity(memberName: "You", action: "invited", target: email),
            at: 0
        )
        return invite
    }

    func updateMemberRole(memberID: UUID, role: TeamRole, in workspaceID: UUID) async throws {
        guard let wIndex = workspaces.firstIndex(where: { $0.id == workspaceID }) else {
            throw TeamError.notFound
        }
        guard let mIndex = workspaces[wIndex].members.firstIndex(where: { $0.id == memberID }) else {
            throw TeamError.notFound
        }
        let memberName = workspaces[wIndex].members[mIndex].name
        workspaces[wIndex].members[mIndex].role = role
        activities.insert(
            TeamActivity(memberName: "You", action: "changed role to \(role.displayName) for", target: memberName),
            at: 0
        )
    }

    func removeMember(memberID: UUID, from workspaceID: UUID) async throws {
        guard let wIndex = workspaces.firstIndex(where: { $0.id == workspaceID }) else {
            throw TeamError.notFound
        }
        guard let mIndex = workspaces[wIndex].members.firstIndex(where: { $0.id == memberID }) else {
            throw TeamError.notFound
        }
        let memberName = workspaces[wIndex].members[mIndex].name
        workspaces[wIndex].members.remove(at: mIndex)
        activities.insert(
            TeamActivity(memberName: "You", action: "removed", target: memberName),
            at: 0
        )
    }

    func fetchActivity(workspaceID: UUID) async throws -> [TeamActivity] {
        activities
    }
}

// MARK: - API Implementation

final class APITeamRepository: TeamRepository {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchWorkspaces() async throws -> [Workspace] {
        try await apiClient.request(
            endpoint: "teams/workspaces",
            method: .get,
            requiresAuth: true
        )
    }

    func createWorkspace(name: String, plan: WorkspacePlan) async throws -> Workspace {
        try await apiClient.request(
            endpoint: "teams/workspaces",
            method: .post,
            body: CreateWorkspaceBody(name: name, plan: plan),
            requiresAuth: true
        )
    }

    func fetchMembers(workspaceID: UUID) async throws -> [TeamMember] {
        try await apiClient.request(
            endpoint: "teams/workspaces/\(workspaceID.uuidString)/members",
            method: .get,
            requiresAuth: true
        )
    }

    func inviteMember(email: String, role: TeamRole, to workspaceID: UUID) async throws -> WorkspaceInvite {
        try await apiClient.request(
            endpoint: "teams/invites",
            method: .post,
            body: InviteMemberBody(workspaceID: workspaceID, email: email, role: role),
            requiresAuth: true
        )
    }

    func updateMemberRole(memberID: UUID, role: TeamRole, in workspaceID: UUID) async throws {
        try await apiClient.requestVoid(
            endpoint: "teams/members/\(memberID.uuidString)/role",
            method: .put,
            body: UpdateRoleBody(role: role),
            requiresAuth: true
        )
    }

    func removeMember(memberID: UUID, from workspaceID: UUID) async throws {
        try await apiClient.requestVoid(
            endpoint: "teams/members/\(memberID.uuidString)",
            method: .delete,
            body: EmptyTeamBody(),
            requiresAuth: true
        )
    }

    func fetchActivity(workspaceID: UUID) async throws -> [TeamActivity] {
        try await apiClient.request(
            endpoint: "teams/activity/\(workspaceID.uuidString)",
            method: .get,
            requiresAuth: true
        )
    }
}

// MARK: - Request Bodies

private struct CreateWorkspaceBody: Encodable {
    let name: String
    let plan: WorkspacePlan
}

private struct InviteMemberBody: Encodable {
    let workspaceID: UUID
    let email: String
    let role: TeamRole
}

private struct UpdateRoleBody: Encodable {
    let role: TeamRole
}

// Uses shared EmptyBody from RepositoryProvider.swift
private typealias EmptyTeamBody = EmptyBody

// MARK: - Error

enum TeamError: LocalizedError {
    case notFound

    var errorDescription: String? {
        switch self {
        case .notFound: return "The requested team resource was not found."
        }
    }
}

// MARK: - Provider

enum TeamRepositoryProvider {
    nonisolated(unsafe) static var shared = RepositoryProvider<TeamRepository>(
        dev: MockTeamRepository(),
        api: APITeamRepository()
    )
}
