import SwiftUI

/// List of review request cards with status, deadline, and comment count.
struct ReviewListView: View {
    @ObservedObject var viewModel: CollaborationViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                header
                statusFilterBar
                reviewList
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .refreshable { await viewModel.loadReviews() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                Text("REVIEWS")
                    .font(.spaceMonoBold(17))
                    .tracking(-0.5)
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text("\(viewModel.filteredReviews.count) requests")
                    .font(.spaceMono(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            Spacer()
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Status Filter

    private var statusFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ENVISpacing.sm) {
                filterChip(title: "All", isSelected: viewModel.statusFilter == nil) {
                    viewModel.statusFilter = nil
                }
                ForEach(ReviewStatus.allCases) { status in
                    filterChip(title: status.displayName, isSelected: viewModel.statusFilter == status) {
                        viewModel.statusFilter = status
                    }
                }
            }
            .padding(.horizontal, ENVISpacing.xl)
        }
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.interMedium(13))
                .foregroundColor(isSelected ? ENVITheme.background(for: colorScheme) : ENVITheme.text(for: colorScheme))
                .padding(.horizontal, ENVISpacing.md)
                .padding(.vertical, ENVISpacing.sm)
                .background(isSelected ? ENVITheme.text(for: colorScheme) : ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.sm)
                        .strokeBorder(isSelected ? Color.clear : ENVITheme.border(for: colorScheme), lineWidth: 1)
                )
        }
    }

    // MARK: - Review List

    private var reviewList: some View {
        LazyVStack(spacing: ENVISpacing.md) {
            if viewModel.isLoadingReviews {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if viewModel.filteredReviews.isEmpty {
                emptyState
            } else {
                ForEach(viewModel.filteredReviews) { review in
                    NavigationLink(value: review.id) {
                        reviewCard(review)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let error = viewModel.reviewError {
                Text(error)
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.error)
                    .padding(.horizontal, ENVISpacing.xl)
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Review Card

    private func reviewCard(_ review: ReviewRequest) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            // Title & Status
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                    Text(review.contentTitle)
                        .font(.interSemiBold(15))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                        .lineLimit(2)

                    Text("Reviewer: \(review.reviewerName)")
                        .font(.interRegular(13))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }

                Spacer()

                statusBadge(review.status)
            }

            // Metadata row
            HStack(spacing: ENVISpacing.lg) {
                if let deadline = review.deadline {
                    Label {
                        Text(deadline, style: .date)
                            .font(.spaceMono(11))
                    } icon: {
                        Image(systemName: review.isOverdue ? "exclamationmark.circle" : "calendar")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(review.isOverdue ? ENVITheme.error : ENVITheme.textSecondary(for: colorScheme))
                }

                Label {
                    Text("\(review.commentCount)")
                        .font(.spaceMono(11))
                } icon: {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 11))
                }
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                if review.unresolvedCount > 0 {
                    Text("\(review.unresolvedCount) open")
                        .font(.spaceMono(11))
                        .foregroundColor(ENVITheme.warning)
                }

                Spacer()
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

    // MARK: - Status Badge

    private func statusBadge(_ status: ReviewStatus) -> some View {
        HStack(spacing: ENVISpacing.xs) {
            Image(systemName: status.iconName)
                .font(.system(size: 10))
            Text(status.displayName)
                .font(.spaceMono(10))
        }
        .foregroundColor(statusColor(status))
        .padding(.horizontal, ENVISpacing.sm)
        .padding(.vertical, ENVISpacing.xs)
        .background(statusColor(status).opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
    }

    private func statusColor(_ status: ReviewStatus) -> Color {
        switch status {
        case .pending:          return ENVITheme.textSecondary(for: colorScheme)
        case .inReview:         return ENVITheme.info
        case .approved:         return ENVITheme.success
        case .changesRequested: return ENVITheme.warning
        case .rejected:         return ENVITheme.error
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: ENVISpacing.md) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 36))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Text("No review requests")
                .font(.interMedium(15))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Create a review to start collaborating.")
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}
