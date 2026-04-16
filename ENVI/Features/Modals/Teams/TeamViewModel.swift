import SwiftUI
import Combine

/// ViewModel for Teams, Roles, and Workspaces (Domain D24).
final class TeamViewModel: ObservableObject {
    // MARK: - Workspaces
    @Published var workspaces: [Workspace] = []
    @Published var selectedWorkspace: Workspace?
    @Published var isLoadingWorkspaces = false

    // MARK: - Members
    @Published var members: [TeamMember] = []
    @Published var isLoadingMembers = false

    // MARK: - Activity
    @Published var activities: [TeamActivity] = []
    @Published var isLoadingActivity = false

    // MARK: - Invite
    @Published var inviteEmail = ""
    @Published var inviteRole: TeamRole = .viewer
    @Published var isShowingInviteSheet = false
    @Published var isSendingInvite = false

    // MARK: - Role Change
    @Published var memberForRoleChange: TeamMember?
    @Published var isShowingRolePicker = false

    // MARK: - Create Workspace
    @Published var newWorkspaceName = ""
    @Published var newWorkspacePlan: WorkspacePlan = .free
    @Published var isShowingCreateSheet = false
    @Published var isCreatingWorkspace = false

    // MARK: - Error
    @Published var errorMessage: String?

    private let repository: TeamRepository

    init(repository: TeamRepository = TeamRepositoryProvider.shared.repository) {
        self.repository = repository
        Task { await loadWorkspaces() }
    }

    // MARK: - Load Workspaces

    @MainActor
    func loadWorkspaces() async {
        isLoadingWorkspaces = true
        errorMessage = nil
        do {
            workspaces = try await repository.fetchWorkspaces()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingWorkspaces = false
    }

    // MARK: - Create Workspace

    @MainActor
    func createWorkspace() async {
        let name = newWorkspaceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        isCreatingWorkspace = true
        do {
            let workspace = try await repository.createWorkspace(name: name, plan: newWorkspacePlan)
            workspaces.insert(workspace, at: 0)
            newWorkspaceName = ""
            isShowingCreateSheet = false
        } catch {
            errorMessage = error.localizedDescription
        }
        isCreatingWorkspace = false
    }

    // MARK: - Select Workspace & Load Members

    @MainActor
    func selectWorkspace(_ workspace: Workspace) async {
        selectedWorkspace = workspace
        isLoadingMembers = true
        isLoadingActivity = true
        errorMessage = nil
        do {
            members = try await repository.fetchMembers(workspaceID: workspace.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingMembers = false
        do {
            activities = try await repository.fetchActivity(workspaceID: workspace.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingActivity = false
    }

    // MARK: - Invite Member

    @MainActor
    func inviteMember() async {
        let email = inviteEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, let workspace = selectedWorkspace else { return }

        isSendingInvite = true
        do {
            _ = try await repository.inviteMember(email: email, role: inviteRole, to: workspace.id)
            members = try await repository.fetchMembers(workspaceID: workspace.id)
            activities = try await repository.fetchActivity(workspaceID: workspace.id)
            inviteEmail = ""
            isShowingInviteSheet = false
        } catch {
            errorMessage = error.localizedDescription
        }
        isSendingInvite = false
    }

    // MARK: - Update Member Role

    @MainActor
    func updateMemberRole(_ member: TeamMember, to role: TeamRole) async {
        guard let workspace = selectedWorkspace else { return }
        do {
            try await repository.updateMemberRole(memberID: member.id, role: role, in: workspace.id)
            if let index = members.firstIndex(where: { $0.id == member.id }) {
                members[index].role = role
            }
            activities = try await repository.fetchActivity(workspaceID: workspace.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isShowingRolePicker = false
        memberForRoleChange = nil
    }

    // MARK: - Remove Member

    @MainActor
    func removeMember(_ member: TeamMember) async {
        guard let workspace = selectedWorkspace else { return }
        do {
            try await repository.removeMember(memberID: member.id, from: workspace.id)
            members.removeAll { $0.id == member.id }
            activities = try await repository.fetchActivity(workspaceID: workspace.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Refresh Activity

    @MainActor
    func refreshActivity() async {
        guard let workspace = selectedWorkspace else { return }
        isLoadingActivity = true
        do {
            activities = try await repository.fetchActivity(workspaceID: workspace.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingActivity = false
    }
}
