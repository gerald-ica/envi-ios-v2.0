import SwiftUI

/// Grid of workspace cards with member count and plan badge.
struct WorkspaceListView: View {
    @ObservedObject var viewModel: TeamViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                header
                workspaceList
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .refreshable { await viewModel.loadWorkspaces() }
        .sheet(isPresented: $viewModel.isShowingCreateSheet) { createWorkspaceSheet }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                Text("WORKSPACES")
                    .font(.spaceMonoBold(17))
                    .tracking(-0.5)
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text("\(viewModel.workspaces.count) workspaces")
                    .font(.spaceMono(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            Spacer()

            Button {
                viewModel.isShowingCreateSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .frame(width: 36, height: 36)
                    .background(ENVITheme.surfaceLow(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: ENVIRadius.sm)
                            .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Workspace List

    private var workspaceList: some View {
        LazyVStack(spacing: ENVISpacing.md) {
            if viewModel.isLoadingWorkspaces {
                ENVILoadingState()
            } else if viewModel.workspaces.isEmpty {
                emptyState
            } else {
                ForEach(viewModel.workspaces) { workspace in
                    Button {
                        Task { await viewModel.selectWorkspace(workspace) }
                    } label: {
                        workspaceCard(workspace)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let error = viewModel.errorMessage {
                ENVIErrorBanner(message: error)
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Workspace Card

    private func workspaceCard(_ workspace: Workspace) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                    Text(workspace.name)
                        .font(.interSemiBold(15))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                        .lineLimit(1)

                    Text("Created \(workspace.createdAt, style: .date)")
                        .font(.spaceMono(11))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }

                Spacer()

                planBadge(workspace.plan)
            }

            HStack(spacing: ENVISpacing.lg) {
                Label {
                    Text("\(workspace.memberCount) members")
                        .font(.spaceMono(11))
                } icon: {
                    Image(systemName: "person.2")
                        .font(.system(size: 11))
                }
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }
        }
        .padding(ENVISpacing.lg)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Plan Badge

    private func planBadge(_ plan: WorkspacePlan) -> some View {
        Text(plan.displayName)
            .font(.spaceMono(10))
            .foregroundColor(planColor(plan))
            .padding(.horizontal, ENVISpacing.sm)
            .padding(.vertical, ENVISpacing.xs)
            .background(planColor(plan).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
    }

    private func planColor(_ plan: WorkspacePlan) -> Color {
        switch plan {
        case .free:     return ENVITheme.textSecondary(for: colorScheme)
        case .pro:      return ENVITheme.info
        case .business: return ENVITheme.success
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ENVIEmptyState(
            icon: "building.2",
            title: "No workspaces yet",
            subtitle: "Create a workspace to start collaborating with your team."
        )
    }

    // MARK: - Create Workspace Sheet

    private var createWorkspaceSheet: some View {
        NavigationStack {
            Form {
                Section("Workspace Name") {
                    TextField("e.g. My Team", text: $viewModel.newWorkspaceName)
                        .font(.interRegular(15))
                }

                Section("Plan") {
                    Picker("Plan", selection: $viewModel.newWorkspacePlan) {
                        ForEach(WorkspacePlan.allCases) { plan in
                            Text(plan.displayName).tag(plan)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("New Workspace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.isShowingCreateSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await viewModel.createWorkspace() }
                    }
                    .disabled(viewModel.newWorkspaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isCreatingWorkspace)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
