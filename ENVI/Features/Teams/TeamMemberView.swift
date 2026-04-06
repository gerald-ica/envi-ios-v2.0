import SwiftUI

/// Member list with role badges, invite, remove, and role-change actions.
struct TeamMemberView: View {
    @ObservedObject var viewModel: TeamViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                header
                memberList
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .sheet(isPresented: $viewModel.isShowingInviteSheet) { inviteSheet }
        .confirmationDialog(
            "Change Role",
            isPresented: $viewModel.isShowingRolePicker,
            titleVisibility: .visible
        ) {
            rolePickerActions
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                Text("MEMBERS")
                    .font(.spaceMonoBold(17))
                    .tracking(-0.5)
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                if let workspace = viewModel.selectedWorkspace {
                    Text("\(viewModel.members.count) in \(workspace.name)")
                        .font(.spaceMono(11))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
            }

            Spacer()

            Button {
                viewModel.isShowingInviteSheet = true
            } label: {
                HStack(spacing: ENVISpacing.xs) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 13, weight: .medium))
                    Text("Invite")
                        .font(.interMedium(13))
                }
                .foregroundColor(ENVITheme.background(for: colorScheme))
                .padding(.horizontal, ENVISpacing.md)
                .padding(.vertical, ENVISpacing.sm)
                .background(ENVITheme.text(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Member List

    private var memberList: some View {
        LazyVStack(spacing: ENVISpacing.sm) {
            if viewModel.isLoadingMembers {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if viewModel.members.isEmpty {
                emptyState
            } else {
                ForEach(viewModel.members) { member in
                    memberRow(member)
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.error)
                    .padding(.horizontal, ENVISpacing.xl)
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Member Row

    private func memberRow(_ member: TeamMember) -> some View {
        HStack(spacing: ENVISpacing.md) {
            // Avatar
            avatarView(member)

            // Name & Email
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: ENVISpacing.sm) {
                    Text(member.name)
                        .font(.interSemiBold(14))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                        .lineLimit(1)

                    if member.status == .invited {
                        Text("Invited")
                            .font(.spaceMono(9))
                            .foregroundColor(ENVITheme.warning)
                            .padding(.horizontal, ENVISpacing.xs)
                            .padding(.vertical, 2)
                            .background(ENVITheme.warning.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.xs))
                    }
                }

                Text(member.email)
                    .font(.interRegular(12))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .lineLimit(1)
            }

            Spacer()

            // Role Badge
            roleBadge(member.role)

            // Actions Menu (not for owner)
            if member.role != .owner {
                Menu {
                    Button {
                        viewModel.memberForRoleChange = member
                        viewModel.isShowingRolePicker = true
                    } label: {
                        Label("Change Role", systemImage: "arrow.triangle.2.circlepath")
                    }

                    Button(role: .destructive) {
                        Task { await viewModel.removeMember(member) }
                    } label: {
                        Label("Remove", systemImage: "person.badge.minus")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                        .frame(width: 32, height: 32)
                }
            }
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.md)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Avatar

    private func avatarView(_ member: TeamMember) -> some View {
        ZStack {
            Circle()
                .fill(ENVITheme.surfaceLow(for: colorScheme))
            Text(String(member.name.prefix(1)).uppercased())
                .font(.interSemiBold(14))
                .foregroundColor(ENVITheme.text(for: colorScheme))
        }
        .frame(width: 36, height: 36)
        .overlay(
            Circle()
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Role Badge

    private func roleBadge(_ role: TeamRole) -> some View {
        HStack(spacing: ENVISpacing.xs) {
            Image(systemName: role.iconName)
                .font(.system(size: 9))
            Text(role.displayName)
                .font(.spaceMono(10))
        }
        .foregroundColor(roleColor(role))
        .padding(.horizontal, ENVISpacing.sm)
        .padding(.vertical, ENVISpacing.xs)
        .background(roleColor(role).opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
    }

    private func roleColor(_ role: TeamRole) -> Color {
        switch role {
        case .owner:  return ENVITheme.warning
        case .admin:  return ENVITheme.info
        case .editor: return ENVITheme.success
        case .viewer: return ENVITheme.textSecondary(for: colorScheme)
        }
    }

    // MARK: - Role Picker Actions

    @ViewBuilder
    private var rolePickerActions: some View {
        ForEach(TeamRole.assignable) { role in
            Button(role.displayName) {
                guard let member = viewModel.memberForRoleChange else { return }
                Task { await viewModel.updateMemberRole(member, to: role) }
            }
        }
        Button("Cancel", role: .cancel) {
            viewModel.isShowingRolePicker = false
            viewModel.memberForRoleChange = nil
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: ENVISpacing.md) {
            Image(systemName: "person.3")
                .font(.system(size: 36))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Text("No members yet")
                .font(.interMedium(15))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Invite teammates to collaborate in this workspace.")
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - Invite Sheet

    private var inviteSheet: some View {
        NavigationStack {
            Form {
                Section("Email Address") {
                    TextField("teammate@example.com", text: $viewModel.inviteEmail)
                        .font(.interRegular(15))
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                }

                Section("Role") {
                    Picker("Role", selection: $viewModel.inviteRole) {
                        ForEach(TeamRole.assignable) { role in
                            Text(role.displayName).tag(role)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Invite Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.isShowingInviteSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        Task { await viewModel.inviteMember() }
                    }
                    .disabled(viewModel.inviteEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSendingInvite)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
