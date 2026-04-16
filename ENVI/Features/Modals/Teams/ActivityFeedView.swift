import SwiftUI

/// Team activity timeline showing recent workspace actions.
struct ActivityFeedView: View {
    @ObservedObject var viewModel: TeamViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                header
                activityList
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .refreshable { await viewModel.refreshActivity() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                Text("ACTIVITY")
                    .font(.spaceMonoBold(17))
                    .tracking(-0.5)
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text("\(viewModel.activities.count) events")
                    .font(.spaceMono(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            Spacer()
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Activity List

    private var activityList: some View {
        LazyVStack(spacing: 0) {
            if viewModel.isLoadingActivity {
                ENVILoadingState()
            } else if viewModel.activities.isEmpty {
                emptyState
            } else {
                ForEach(Array(viewModel.activities.enumerated()), id: \.element.id) { index, activity in
                    activityRow(activity, isLast: index == viewModel.activities.count - 1)
                }
            }

            if let error = viewModel.errorMessage {
                ENVIErrorBanner(message: error)
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Activity Row

    private func activityRow(_ activity: TeamActivity, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: ENVISpacing.md) {
            // Timeline indicator
            VStack(spacing: 0) {
                Circle()
                    .fill(ENVITheme.text(for: colorScheme))
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)

                if !isLast {
                    Rectangle()
                        .fill(ENVITheme.border(for: colorScheme))
                        .frame(width: 1)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                HStack(spacing: 0) {
                    Text(activity.memberName)
                        .font(.interSemiBold(13))
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    Text(" \(activity.action) ")
                        .font(.interRegular(13))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                    Text(activity.target)
                        .font(.interSemiBold(13))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                        .lineLimit(1)
                }

                Text(activity.timestamp, style: .relative)
                    .font(.spaceMono(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }
            .padding(.bottom, ENVISpacing.lg)

            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ENVIEmptyState(
            icon: "clock.arrow.circlepath",
            title: "No activity yet",
            subtitle: "Team actions will appear here as they happen."
        )
    }
}
