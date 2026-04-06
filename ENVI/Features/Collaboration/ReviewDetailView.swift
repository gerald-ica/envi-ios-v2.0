import SwiftUI

/// Detail view for a review request: content preview, comment thread,
/// action buttons (approve/request changes/reject), and approval workflow progress.
struct ReviewDetailView: View {
    @ObservedObject var viewModel: CollaborationViewModel
    let review: ReviewRequest

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isCommentFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
                contentPreview
                statusSection
                if !viewModel.workflows.isEmpty {
                    approvalWorkflowSection
                }
                actionButtons
                commentThread
                commentInput
            }
            .padding(ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadWorkflows() }
    }

    // MARK: - Content Preview

    private var contentPreview: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            // Placeholder thumbnail
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .fill(ENVITheme.surfaceHigh(for: colorScheme))
                .frame(height: 180)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 32))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                )

            Text(review.contentTitle)
                .font(.interSemiBold(17))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            HStack(spacing: ENVISpacing.lg) {
                Label(review.reviewerName, systemImage: "person")
                if let deadline = review.deadline {
                    Label {
                        Text(deadline, style: .date)
                    } icon: {
                        Image(systemName: "calendar")
                    }
                }
            }
            .font(.interRegular(13))
            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        HStack(spacing: ENVISpacing.sm) {
            Image(systemName: review.status.iconName)
                .font(.system(size: 14))
            Text(review.status.displayName)
                .font(.interSemiBold(14))
        }
        .foregroundColor(statusColor(review.status))
        .padding(.horizontal, ENVISpacing.md)
        .padding(.vertical, ENVISpacing.sm)
        .background(statusColor(review.status).opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
    }

    // MARK: - Approval Workflow

    private var approvalWorkflowSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("APPROVAL WORKFLOW")
                .font(.spaceMonoBold(13))
                .tracking(-0.3)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            ForEach(viewModel.workflows) { workflow in
                VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                    Text(workflow.name)
                        .font(.interMedium(14))
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(ENVITheme.surfaceHigh(for: colorScheme))
                                .frame(height: 6)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(ENVITheme.success)
                                .frame(width: geo.size.width * workflow.progress, height: 6)
                        }
                    }
                    .frame(height: 6)

                    Text("\(workflow.completedSteps)/\(workflow.steps.count) steps complete")
                        .font(.spaceMono(11))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                    // Step list
                    ForEach(workflow.steps) { step in
                        HStack(spacing: ENVISpacing.sm) {
                            Image(systemName: step.status == .approved ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 14))
                                .foregroundColor(step.status == .approved ? ENVITheme.success : ENVITheme.textSecondary(for: colorScheme))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.role)
                                    .font(.interMedium(13))
                                    .foregroundColor(ENVITheme.text(for: colorScheme))
                                if let name = step.approverName {
                                    Text(name)
                                        .font(.interRegular(12))
                                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                                }
                            }

                            Spacer()

                            Text(step.status.displayName)
                                .font(.spaceMono(10))
                                .foregroundColor(statusColor(step.status))
                        }
                        .padding(.vertical, ENVISpacing.xs)
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
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: ENVISpacing.sm) {
            actionButton(title: "Approve", icon: "checkmark", color: ENVITheme.success) {
                Task { await viewModel.updateStatus(.approved, for: review) }
            }
            actionButton(title: "Changes", icon: "exclamationmark.triangle", color: ENVITheme.warning) {
                Task { await viewModel.updateStatus(.changesRequested, for: review) }
            }
            actionButton(title: "Reject", icon: "xmark", color: ENVITheme.error) {
                Task { await viewModel.updateStatus(.rejected, for: review) }
            }
        }
    }

    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: ENVISpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.interSemiBold(13))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, ENVISpacing.md)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.lg)
                    .strokeBorder(color.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Comment Thread

    private var commentThread: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("COMMENTS (\(review.commentCount))")
                .font(.spaceMonoBold(13))
                .tracking(-0.3)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            if review.comments.isEmpty {
                Text("No comments yet.")
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .padding(.vertical, ENVISpacing.lg)
            } else {
                ForEach(review.comments) { comment in
                    commentRow(comment)
                }
            }
        }
    }

    private func commentRow(_ comment: ReviewComment) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            HStack {
                Text(comment.authorName)
                    .font(.interSemiBold(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Spacer()

                Text(comment.timestamp, style: .relative)
                    .font(.spaceMono(10))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            Text(comment.text)
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            if comment.resolved {
                HStack(spacing: ENVISpacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                    Text("Resolved")
                        .font(.spaceMono(10))
                }
                .foregroundColor(ENVITheme.success)
            } else {
                Button {
                    Task { await viewModel.resolveComment(comment, in: review) }
                } label: {
                    Text("Resolve")
                        .font(.interMedium(12))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
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

    // MARK: - Comment Input

    private var commentInput: some View {
        HStack(spacing: ENVISpacing.sm) {
            TextField("Add a comment...", text: $viewModel.newCommentText, axis: .vertical)
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .focused($isCommentFocused)
                .lineLimit(1...4)
                .padding(ENVISpacing.md)
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.md)
                        .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                )

            Button {
                Task { await viewModel.addComment(to: review) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(
                        viewModel.newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? ENVITheme.textSecondary(for: colorScheme)
                            : ENVITheme.text(for: colorScheme)
                    )
            }
            .disabled(viewModel.newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSendingComment)
        }
    }

    // MARK: - Helpers

    private func statusColor(_ status: ReviewStatus) -> Color {
        switch status {
        case .pending:          return ENVITheme.textSecondary(for: colorScheme)
        case .inReview:         return ENVITheme.info
        case .approved:         return ENVITheme.success
        case .changesRequested: return ENVITheme.warning
        case .rejected:         return ENVITheme.error
        }
    }
}
