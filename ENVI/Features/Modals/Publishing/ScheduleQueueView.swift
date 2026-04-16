import SwiftUI

/// Queue dashboard showing pending, processing, completed, and failed scheduled posts.
struct ScheduleQueueView: View {
    @StateObject private var viewModel = SchedulingViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var showSchedulePost = false
    @State private var selectedPost: ScheduledPost?

    private let queueTabs: [ScheduledPostStatus] = [.pending, .processing, .completed, .failed]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Queue summary cards
                queueSummary

                // Tab selector
                tabSelector

                Divider()
                    .background(ENVITheme.border(for: colorScheme))

                // Content
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                } else if viewModel.filteredPosts.isEmpty {
                    emptyStateView
                } else {
                    postsList
                }
            }
            .background(ENVITheme.background(for: colorScheme))
            .navigationTitle("PUBLISH QUEUE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSchedulePost = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                    }
                }
            }
            .sheet(isPresented: $showSchedulePost) {
                SchedulePostView(viewModel: viewModel)
            }
            .sheet(item: $selectedPost) { post in
                PublishResultsView(viewModel: viewModel, post: post)
            }
            .refreshable {
                await viewModel.reload()
            }
        }
    }

    // MARK: - Queue Summary

    private var queueSummary: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ENVISpacing.sm) {
                queueCard(title: "PENDING", count: viewModel.publishQueue.pendingCount, color: ENVITheme.warning)
                queueCard(title: "PROCESSING", count: viewModel.publishQueue.processingCount, color: ENVITheme.info)
                queueCard(title: "COMPLETED", count: viewModel.publishQueue.completedCount, color: ENVITheme.success)
                queueCard(title: "FAILED", count: viewModel.publishQueue.failedCount, color: ENVITheme.error)
            }
            .padding(.horizontal, ENVISpacing.lg)
            .padding(.vertical, ENVISpacing.md)
        }
    }

    private func queueCard(title: String, count: Int, color: Color) -> some View {
        VStack(spacing: ENVISpacing.xs) {
            Text("\(count)")
                .font(.interBold(24))
                .foregroundColor(color)

            Text(title)
                .font(.spaceMono(9))
                .tracking(0.72)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .frame(width: 80, height: 64)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(queueTabs, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedQueueTab = tab
                    }
                } label: {
                    VStack(spacing: ENVISpacing.xs) {
                        Text(tab.displayName.uppercased())
                            .font(.spaceMono(10))
                            .tracking(0.8)
                            .foregroundColor(
                                viewModel.selectedQueueTab == tab
                                    ? ENVITheme.text(for: colorScheme)
                                    : ENVITheme.textSecondary(for: colorScheme)
                            )

                        Rectangle()
                            .fill(viewModel.selectedQueueTab == tab
                                  ? ENVITheme.text(for: colorScheme)
                                  : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, ENVISpacing.lg)
        .padding(.top, ENVISpacing.sm)
    }

    // MARK: - Posts List

    private var postsList: some View {
        ScrollView {
            LazyVStack(spacing: ENVISpacing.md) {
                ForEach(viewModel.filteredPosts) { post in
                    postRow(post)
                        .onTapGesture {
                            if post.status == .completed || post.status == .failed {
                                selectedPost = post
                            }
                        }
                }
            }
            .padding(ENVISpacing.lg)
        }
    }

    private func postRow(_ post: ScheduledPost) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            // Header: platforms + status
            HStack {
                HStack(spacing: ENVISpacing.xs) {
                    ForEach(post.platforms) { platform in
                        Image(systemName: platform.iconName)
                            .font(.system(size: 12))
                            .foregroundColor(platform.brandColor)
                    }
                }

                Spacer()

                statusBadge(post.status)
            }

            // Caption preview
            Text(post.caption)
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .lineLimit(2)

            // Footer: schedule time + actions
            HStack {
                Image(systemName: "clock")
                    .font(.system(size: 11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                Text(post.scheduledAt, style: .relative)
                    .font(.interRegular(12))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                if post.approvalStatus != .notRequired {
                    approvalBadge(post.approvalStatus)
                }

                Spacer()

                // Actions
                if post.status == .pending {
                    Button {
                        Task { await viewModel.cancelPost(post) }
                    } label: {
                        Text("CANCEL")
                            .font(.spaceMono(10))
                            .tracking(0.8)
                            .foregroundColor(ENVITheme.error)
                    }
                }

                if post.status == .failed {
                    Button {
                        Task { await viewModel.retryPost(post) }
                    } label: {
                        Text("RETRY")
                            .font(.spaceMono(10))
                            .tracking(0.8)
                            .foregroundColor(ENVITheme.info)
                    }
                }
            }
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
    }

    private func statusBadge(_ status: ScheduledPostStatus) -> some View {
        Text(status.displayName.uppercased())
            .font(.spaceMono(9))
            .tracking(0.72)
            .foregroundColor(.white)
            .padding(.horizontal, ENVISpacing.sm)
            .padding(.vertical, ENVISpacing.xs)
            .background(statusColor(status))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
    }

    private func approvalBadge(_ status: ApprovalStatus) -> some View {
        HStack(spacing: 2) {
            Circle()
                .fill(approvalColor(status))
                .frame(width: 6, height: 6)

            Text(status.displayName)
                .font(.interRegular(11))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
    }

    // MARK: - Empty / Error

    private var emptyStateView: some View {
        VStack(spacing: ENVISpacing.md) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Text("No \(viewModel.selectedQueueTab.displayName.lowercased()) posts")
                .font(.interMedium(16))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            Spacer()
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: ENVISpacing.md) {
            Spacer()
            Text(message)
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.error)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task { await viewModel.reload() }
            }
            .font(.interMedium(14))
            .foregroundColor(ENVITheme.text(for: colorScheme))
            Spacer()
        }
        .padding(ENVISpacing.lg)
    }

    // MARK: - Helpers

    private func statusColor(_ status: ScheduledPostStatus) -> Color {
        switch status {
        case .pending:    return ENVITheme.warning
        case .processing: return ENVITheme.info
        case .completed:  return ENVITheme.success
        case .failed:     return ENVITheme.error
        case .cancelled:  return ENVITheme.textSecondary(for: colorScheme)
        }
    }

    private func approvalColor(_ status: ApprovalStatus) -> Color {
        switch status {
        case .notRequired: return .clear
        case .pending:     return ENVITheme.warning
        case .approved:    return ENVITheme.success
        case .rejected:    return ENVITheme.error
        }
    }
}

#Preview {
    ScheduleQueueView()
        .preferredColorScheme(.dark)
}
