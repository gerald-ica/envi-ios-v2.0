import SwiftUI

/// Post-publish results: per-platform status, post URLs, error details, and retry.
struct PublishResultsView: View {
    @ObservedObject var viewModel: SchedulingViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let post: ScheduledPost

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
                    // Post summary
                    postSummary

                    // Overall status
                    overallStatus

                    // Per-platform results
                    platformResults

                    // Retry section for failed
                    if post.status == .failed {
                        retrySection
                    }
                }
                .padding(ENVISpacing.lg)
            }
            .background(ENVITheme.background(for: colorScheme))
            .navigationTitle("PUBLISH RESULTS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                    }
                }
            }
            .task {
                await viewModel.loadResults(for: post.id.uuidString)
            }
        }
    }

    // MARK: - Post Summary

    private var postSummary: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            sectionHeader("POST")

            VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                Text(post.caption)
                    .font(.interRegular(14))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .lineLimit(3)

                HStack(spacing: ENVISpacing.sm) {
                    ForEach(post.platforms) { platform in
                        HStack(spacing: 4) {
                            Image(systemName: platform.iconName)
                                .font(.system(size: 11))
                            Text(platform.rawValue)
                                .font(.interRegular(11))
                        }
                        .foregroundColor(platform.brandColor)
                    }
                }

                HStack(spacing: ENVISpacing.xs) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                    Text(post.scheduledAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(.interRegular(12))
                }
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }
            .padding(ENVISpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        }
    }

    // MARK: - Overall Status

    private var overallStatus: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            sectionHeader("STATUS")

            HStack(spacing: ENVISpacing.md) {
                let successCount = viewModel.publishResults.filter(\.isSuccess).count
                let failedCount = viewModel.publishResults.filter { !$0.isSuccess }.count
                let total = viewModel.publishResults.count

                statusSummaryItem(
                    icon: "checkmark.circle.fill",
                    label: "Success",
                    count: successCount,
                    color: ENVITheme.success
                )

                statusSummaryItem(
                    icon: "xmark.circle.fill",
                    label: "Failed",
                    count: failedCount,
                    color: ENVITheme.error
                )

                statusSummaryItem(
                    icon: "number",
                    label: "Total",
                    count: total,
                    color: ENVITheme.text(for: colorScheme)
                )

                Spacer()
            }
            .padding(ENVISpacing.md)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        }
    }

    private func statusSummaryItem(icon: String, label: String, count: Int, color: Color) -> some View {
        VStack(spacing: ENVISpacing.xs) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)

                Text("\(count)")
                    .font(.interBold(18))
                    .foregroundColor(color)
            }

            Text(label.uppercased())
                .font(.spaceMono(9))
                .tracking(0.72)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .frame(width: 80)
    }

    // MARK: - Platform Results

    private var platformResults: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            sectionHeader("PLATFORMS")

            if viewModel.publishResults.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(.vertical, ENVISpacing.xxl)
                    Spacer()
                }
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            } else {
                ForEach(viewModel.publishResults) { result in
                    resultRow(result)
                }
            }
        }
    }

    private func resultRow(_ result: PublishResult) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            // Platform header
            HStack {
                Image(systemName: result.platform.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(result.platform.brandColor)

                Text(result.platform.rawValue)
                    .font(.interSemiBold(14))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Spacer()

                Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(result.isSuccess ? ENVITheme.success : ENVITheme.error)
            }

            if result.isSuccess {
                // Success details
                if let publishedAt = result.publishedAt {
                    HStack(spacing: ENVISpacing.xs) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text("Published \(publishedAt, style: .relative) ago")
                            .font(.interRegular(12))
                    }
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }

                if let urlString = result.postURL, let url = URL(string: urlString) {
                    Button {
                        openURL(url)
                    } label: {
                        HStack(spacing: ENVISpacing.xs) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 12))

                            Text("View Post")
                                .font(.interMedium(13))

                            Spacer()

                            Text(urlString)
                                .font(.interRegular(11))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: 180)
                        }
                        .foregroundColor(ENVITheme.info)
                        .padding(ENVISpacing.sm)
                        .background(ENVITheme.info.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                    }
                }

                if let postID = result.postID {
                    HStack(spacing: ENVISpacing.xs) {
                        Text("Post ID:")
                            .font(.interRegular(11))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                        Text(postID)
                            .font(.spaceMono(11))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    }
                }
            } else {
                // Error details
                if let error = result.error {
                    HStack(alignment: .top, spacing: ENVISpacing.sm) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 12))
                            .foregroundColor(ENVITheme.error)

                        Text(error)
                            .font(.interRegular(13))
                            .foregroundColor(ENVITheme.error)
                    }
                    .padding(ENVISpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ENVITheme.error.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                }
            }
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
    }

    // MARK: - Retry

    private var retrySection: some View {
        VStack(spacing: ENVISpacing.md) {
            Button {
                Task { await viewModel.retryPost(post) }
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))

                    Text("RETRY ALL FAILED")
                        .font(.spaceMono(13))
                        .tracking(1.04)
                }
                .foregroundColor(colorScheme == .dark ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, ENVISpacing.md)
                .background(ENVITheme.text(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.spaceMono(11))
            .tracking(0.88)
            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
    }
}

#Preview {
    PublishResultsView(
        viewModel: SchedulingViewModel(),
        post: ScheduledPost.mockPosts[2]
    )
    .preferredColorScheme(.dark)
}
