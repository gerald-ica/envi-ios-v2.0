import SwiftUI

/// Grid of campaign cards with status filtering and create action.
struct CampaignListView: View {
    @ObservedObject var viewModel: CampaignViewModel
    @Environment(\.colorScheme) private var colorScheme

    private let columns = [
        GridItem(.flexible(), spacing: ENVISpacing.md),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                header
                statusFilterBar

                if viewModel.isLoadingCampaigns {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else if viewModel.filteredCampaigns.isEmpty {
                    emptyState
                } else {
                    campaignList
                }

                if let error = viewModel.campaignError {
                    Text(error)
                        .font(.interRegular(13))
                        .foregroundColor(ENVITheme.error)
                        .padding(.horizontal, ENVISpacing.xl)
                }
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .sheet(isPresented: $viewModel.isShowingCampaignEditor) {
            if let campaign = viewModel.editingCampaign {
                CampaignEditorSheet(
                    campaign: campaign,
                    onSave: { updated in
                        Task { await viewModel.saveCampaign(updated) }
                    },
                    onCancel: {
                        viewModel.isShowingCampaignEditor = false
                        viewModel.editingCampaign = nil
                    }
                )
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                Text("CAMPAIGNS")
                    .font(.spaceMonoBold(17))
                    .tracking(-0.5)
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text("\(viewModel.campaigns.count) campaigns")
                    .font(.spaceMono(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            Spacer()

            Button(action: { viewModel.startCreatingCampaign() }) {
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

    // MARK: - Status Filter

    private var statusFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ENVISpacing.sm) {
                filterChip(label: "All", isSelected: viewModel.statusFilter == nil) {
                    viewModel.statusFilter = nil
                }

                ForEach(CampaignStatus.allCases) { status in
                    filterChip(label: status.displayName, isSelected: viewModel.statusFilter == status) {
                        viewModel.statusFilter = status
                    }
                }
            }
            .padding(.horizontal, ENVISpacing.xl)
        }
    }

    private func filterChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label.uppercased())
                .font(.spaceMono(11))
                .tracking(0.5)
                .foregroundColor(isSelected ? ENVITheme.text(for: colorScheme) : ENVITheme.textSecondary(for: colorScheme))
                .padding(.horizontal, ENVISpacing.md)
                .padding(.vertical, ENVISpacing.sm)
                .background(isSelected ? ENVITheme.surfaceHigh(for: colorScheme) : ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.sm)
                        .strokeBorder(isSelected ? ENVITheme.text(for: colorScheme).opacity(0.3) : Color.clear, lineWidth: 1)
                )
        }
    }

    // MARK: - Campaign List

    private var campaignList: some View {
        LazyVGrid(columns: columns, spacing: ENVISpacing.md) {
            ForEach(viewModel.filteredCampaigns) { campaign in
                NavigationLink(destination: CampaignDetailView(campaign: campaign, viewModel: viewModel)) {
                    CampaignCardView(campaign: campaign)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Edit") { viewModel.startEditingCampaign(campaign) }
                }
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: ENVISpacing.md) {
            Image(systemName: "megaphone")
                .font(.system(size: 32))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Text("No campaigns yet")
                .font(.interMedium(15))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Create a campaign to organize your content strategy, briefs, and deliverables.")
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)

            ENVIButton("Create Campaign", variant: .secondary, isFullWidth: false) {
                viewModel.startCreatingCampaign()
            }
        }
        .padding(ENVISpacing.xxxl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Campaign Card

private struct CampaignCardView: View {
    let campaign: Campaign
    @Environment(\.colorScheme) private var colorScheme

    private var deadlineColor: Color {
        if campaign.status == .completed || campaign.status == .archived {
            return ENVITheme.textSecondary(for: colorScheme)
        }
        return campaign.daysRemaining < 0 ? ENVITheme.error : (campaign.daysRemaining <= 7 ? ENVITheme.warning : ENVITheme.textSecondary(for: colorScheme))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            // Top row: status + deadline
            HStack {
                statusBadge
                Spacer()
                deadlineLabel
            }

            // Name
            Text(campaign.name)
                .font(.interSemiBold(17))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .lineLimit(2)

            // Objective
            if !campaign.objective.isEmpty {
                Text(campaign.objective)
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .lineLimit(2)
            }

            // Progress bar
            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(ENVITheme.surfaceHigh(for: colorScheme))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(ENVITheme.text(for: colorScheme))
                            .frame(width: geo.size.width * campaign.progress, height: 4)
                    }
                }
                .frame(height: 4)
            }

            // Bottom row: budget + deliverables count
            HStack {
                Text(campaign.formattedBudget)
                    .font(.spaceMono(11))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Spacer()

                Text("\(campaign.deliverables.count) deliverables")
                    .font(.spaceMono(11))
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

    private var statusBadge: some View {
        HStack(spacing: ENVISpacing.xs) {
            Image(systemName: campaign.status.iconName)
                .font(.system(size: 10))
            Text(campaign.status.displayName.uppercased())
                .font(.spaceMono(10))
                .tracking(0.5)
        }
        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
    }

    private var deadlineLabel: some View {
        HStack(spacing: ENVISpacing.xs) {
            Image(systemName: "calendar")
                .font(.system(size: 10))
            Text(campaign.deadline, style: .date)
                .font(.spaceMono(10))
        }
        .foregroundColor(deadlineColor)
    }
}

// MARK: - Campaign Editor Sheet

private struct CampaignEditorSheet: View {
    @State var campaign: Campaign
    let onSave: (Campaign) -> Void
    let onCancel: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: ENVISpacing.lg) {
                    editorField("Name", text: $campaign.name)
                    editorField("Objective", text: $campaign.objective)
                    editorField("Target Audience", text: $campaign.targetAudience)
                    editorField("Key Message", text: $campaign.keyMessage)
                    editorField("Call to Action", text: $campaign.cta)
                    editorField("Owner", text: $campaign.owner)

                    // Status picker
                    VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                        Text("STATUS")
                            .font(.spaceMono(10))
                            .tracking(1.0)
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                        Picker("Status", selection: $campaign.status) {
                            ForEach(CampaignStatus.allCases) { status in
                                Text(status.displayName).tag(status)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Budget
                    VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                        Text("BUDGET")
                            .font(.spaceMono(10))
                            .tracking(1.0)
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                        TextField("0", value: $campaign.budget, format: .number)
                            .font(.interRegular(15))
                            .keyboardType(.decimalPad)
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                            .padding(ENVISpacing.md)
                            .background(ENVITheme.surfaceLow(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: ENVIRadius.md)
                                    .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                            )
                    }

                    // Deadline
                    VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                        Text("DEADLINE")
                            .font(.spaceMono(10))
                            .tracking(1.0)
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                        DatePicker("", selection: $campaign.deadline, displayedComponents: .date)
                            .labelsHidden()
                    }
                }
                .padding(ENVISpacing.xl)
            }
            .background(ENVITheme.background(for: colorScheme))
            .navigationTitle(campaign.name.isEmpty ? "New Campaign" : "Edit Campaign")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(campaign) }
                        .disabled(campaign.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func editorField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xs) {
            Text(label.uppercased())
                .font(.spaceMono(10))
                .tracking(1.0)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            TextField(label, text: text)
                .font(.interRegular(15))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .padding(ENVISpacing.md)
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.md)
                        .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                )
        }
    }
}

#Preview {
    NavigationView {
        CampaignListView(viewModel: CampaignViewModel())
    }
    .preferredColorScheme(.dark)
}
