import SwiftUI

/// Full campaign detail: objective, deliverables, brief, timeline, and content requests.
struct CampaignDetailView: View {
    let campaign: Campaign
    @ObservedObject var viewModel: CampaignViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
                headerSection
                objectiveSection
                deliverablesSection
                timelineSection
                briefSection
                requestsSection
                dependenciesSection
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .navigationTitle(campaign.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") { viewModel.startEditingCampaign(campaign) }
                    .font(.interMedium(15))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
            }
        }
        .task {
            await viewModel.loadBriefs(for: campaign.id)
        }
        .sheet(isPresented: $viewModel.isShowingBriefEditor) {
            if let brief = viewModel.editingBrief {
                BriefEditorView(
                    brief: brief,
                    onSave: { updated in
                        Task { await viewModel.saveBrief(updated) }
                    },
                    onCancel: {
                        viewModel.isShowingBriefEditor = false
                        viewModel.editingBrief = nil
                    }
                )
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            HStack {
                statusBadge
                Spacer()
                Text(campaign.formattedBudget)
                    .font(.spaceMonoBold(15))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
            }

            // Progress
            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                HStack {
                    Text("PROGRESS")
                        .font(.spaceMono(10))
                        .tracking(1.0)
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    Spacer()
                    Text("\(Int(campaign.progress * 100))%")
                        .font(.spaceMono(10))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(ENVITheme.surfaceHigh(for: colorScheme))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(ENVITheme.text(for: colorScheme))
                            .frame(width: geo.size.width * campaign.progress, height: 6)
                    }
                }
                .frame(height: 6)
            }

            // Owner + Deadline
            HStack {
                if !campaign.owner.isEmpty {
                    Label(campaign.owner, systemImage: "person")
                        .font(.interRegular(13))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }

                Spacer()

                Label {
                    Text(campaign.deadline, style: .date)
                        .font(.interRegular(13))
                } icon: {
                    Image(systemName: "calendar")
                }
                .foregroundColor(deadlineColor)
            }
        }
        .padding(ENVISpacing.lg)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Objective

    private var objectiveSection: some View {
        sectionCard(title: "OBJECTIVE") {
            VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                Text(campaign.objective)
                    .font(.interRegular(15))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                if !campaign.targetAudience.isEmpty {
                    DetailRow(label: "Audience", value: campaign.targetAudience)
                }
                if !campaign.keyMessage.isEmpty {
                    DetailRow(label: "Key Message", value: campaign.keyMessage)
                }
                if !campaign.cta.isEmpty {
                    DetailRow(label: "CTA", value: campaign.cta)
                }
            }
        }
    }

    // MARK: - Deliverables

    private var deliverablesSection: some View {
        sectionCard(title: "DELIVERABLES") {
            if campaign.deliverables.isEmpty {
                Text("No deliverables defined")
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            } else {
                VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                    ForEach(campaign.deliverables, id: \.self) { item in
                        HStack(spacing: ENVISpacing.sm) {
                            Image(systemName: "square")
                                .font(.system(size: 12))
                                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                            Text(item)
                                .font(.interRegular(14))
                                .foregroundColor(ENVITheme.text(for: colorScheme))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        sectionCard(title: "TIMELINE") {
            HStack(spacing: ENVISpacing.xl) {
                timelineItem(label: "Created", date: campaign.createdAt)
                timelineItem(label: "Deadline", date: campaign.deadline)

                Spacer()

                VStack(alignment: .trailing, spacing: ENVISpacing.xs) {
                    Text("DAYS LEFT")
                        .font(.spaceMono(10))
                        .tracking(0.5)
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    Text("\(max(0, campaign.daysRemaining))")
                        .font(.spaceMonoBold(24))
                        .foregroundColor(deadlineColor)
                }
            }
        }
    }

    private func timelineItem(label: String, date: Date) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xs) {
            Text(label.uppercased())
                .font(.spaceMono(10))
                .tracking(0.5)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            Text(date, style: .date)
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.text(for: colorScheme))
        }
    }

    // MARK: - Brief

    private var briefSection: some View {
        sectionCard(title: "CREATIVE BRIEF") {
            if let brief = viewModel.briefs.first(where: { $0.campaignID == campaign.id }) {
                VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                    HStack {
                        approvalBadge(brief.approvalStatus)
                        Spacer()
                        Button("Edit Brief") {
                            viewModel.startEditingBrief(brief)
                        }
                        .font(.interMedium(13))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                    }

                    Text(brief.template)
                        .font(.interRegular(13))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                        .lineLimit(6)

                    if !brief.clientNotes.isEmpty {
                        HStack(spacing: ENVISpacing.xs) {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 10))
                            Text(brief.clientNotes)
                                .font(.interRegular(12))
                        }
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    }
                }
            } else {
                VStack(spacing: ENVISpacing.md) {
                    Text("No brief attached")
                        .font(.interRegular(13))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                    ENVIButton("Create Brief", variant: .secondary, isFullWidth: false) {
                        viewModel.startCreatingBrief(for: campaign.id)
                    }
                }
            }
        }
    }

    // MARK: - Requests

    private var requestsSection: some View {
        sectionCard(title: "CONTENT REQUESTS") {
            if viewModel.requests.isEmpty {
                Text("No content requests")
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            } else {
                VStack(spacing: ENVISpacing.sm) {
                    ForEach(viewModel.requests.prefix(5)) { request in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(request.title)
                                    .font(.interMedium(14))
                                    .foregroundColor(ENVITheme.text(for: colorScheme))
                                    .lineLimit(1)
                                Text(request.assignee.isEmpty ? "Unassigned" : request.assignee)
                                    .font(.spaceMono(10))
                                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                            }

                            Spacer()

                            Text(request.priority.displayName.uppercased())
                                .font(.spaceMono(9))
                                .tracking(0.5)
                                .foregroundColor(priorityColor(request.priority))
                                .padding(.horizontal, ENVISpacing.sm)
                                .padding(.vertical, ENVISpacing.xs)
                                .background(priorityColor(request.priority).opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Dependencies

    private var dependenciesSection: some View {
        Group {
            if !campaign.dependencies.isEmpty {
                sectionCard(title: "DEPENDENCIES") {
                    VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                        ForEach(campaign.dependencies, id: \.self) { dep in
                            HStack(spacing: ENVISpacing.sm) {
                                Image(systemName: "link")
                                    .font(.system(size: 11))
                                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                                Text(dep)
                                    .font(.interRegular(13))
                                    .foregroundColor(ENVITheme.text(for: colorScheme))
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var statusBadge: some View {
        HStack(spacing: ENVISpacing.xs) {
            Image(systemName: campaign.status.iconName)
                .font(.system(size: 11))
            Text(campaign.status.displayName.uppercased())
                .font(.spaceMono(11))
                .tracking(0.5)
        }
        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
    }

    private var deadlineColor: Color {
        if campaign.status == .completed || campaign.status == .archived {
            return ENVITheme.textSecondary(for: colorScheme)
        }
        return campaign.daysRemaining < 0 ? ENVITheme.error : (campaign.daysRemaining <= 7 ? ENVITheme.warning : ENVITheme.textSecondary(for: colorScheme))
    }

    private func approvalBadge(_ status: BriefApprovalStatus) -> some View {
        let color: Color = {
            switch status {
            case .approved:          return ENVITheme.success
            case .pending:           return ENVITheme.warning
            case .revisionRequested: return ENVITheme.info
            case .rejected:          return ENVITheme.error
            }
        }()

        return Text(status.displayName.uppercased())
            .font(.spaceMono(9))
            .tracking(0.5)
            .foregroundColor(color)
            .padding(.horizontal, ENVISpacing.sm)
            .padding(.vertical, ENVISpacing.xs)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
    }

    private func priorityColor(_ priority: ContentRequestPriority) -> Color {
        switch priority {
        case .urgent: return ENVITheme.error
        case .high:   return ENVITheme.warning
        case .medium: return ENVITheme.info
        case .low:    return ENVITheme.textSecondary(for: colorScheme)
        }
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text(title)
                .font(.spaceMono(11))
                .tracking(1.0)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            content()
        }
        .padding(ENVISpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
        .padding(.horizontal, ENVISpacing.xl)
    }
}

// MARK: - Detail Row

private struct DetailRow: View {
    let label: String
    let value: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.spaceMono(10))
                .tracking(0.5)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            Text(value)
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.text(for: colorScheme))
        }
        .padding(.top, ENVISpacing.xs)
    }
}

#Preview {
    NavigationView {
        CampaignDetailView(campaign: .mock, viewModel: CampaignViewModel())
    }
    .preferredColorScheme(.dark)
}
