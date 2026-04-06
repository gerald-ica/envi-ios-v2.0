import SwiftUI

/// Dashboard for creating and reviewing repurpose jobs.
/// Includes source format picker, multi-select target formats, generate button, and results preview.
struct RepurposeDashboardView: View {
    @ObservedObject var viewModel: RepurposingViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                header
                sourceFormatPicker
                targetFormatGrid
                generateButton
                jobsList
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xs) {
            Text("Repurpose Content")
                .font(.interSemiBold(22))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Transform one piece of content into multiple formats.")
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Source Format Picker

    private var sourceFormatPicker: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Text("Source Format")
                .font(.interMedium(13))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .padding(.horizontal, ENVISpacing.xl)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ENVISpacing.sm) {
                    ForEach(RepurposeFormat.allCases) { format in
                        formatChip(
                            format: format,
                            isSelected: viewModel.selectedSourceFormat == format
                        ) {
                            viewModel.selectedSourceFormat = format
                            viewModel.selectedTargetFormats.remove(format)
                        }
                    }
                }
                .padding(.horizontal, ENVISpacing.xl)
            }
        }
    }

    // MARK: - Target Format Grid

    private var targetFormatGrid: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Text("Target Formats")
                .font(.interMedium(13))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .padding(.horizontal, ENVISpacing.xl)

            let columns = [
                GridItem(.flexible(), spacing: ENVISpacing.sm),
                GridItem(.flexible(), spacing: ENVISpacing.sm),
            ]

            LazyVGrid(columns: columns, spacing: ENVISpacing.sm) {
                ForEach(viewModel.availableTargetFormats) { format in
                    targetFormatCard(format: format)
                }
            }
            .padding(.horizontal, ENVISpacing.xl)
        }
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        Button {
            Task { await viewModel.createJob(sourceAssetID: UUID()) }
        } label: {
            HStack(spacing: ENVISpacing.sm) {
                if viewModel.isCreatingJob {
                    ProgressView()
                        .tint(ENVITheme.background(for: colorScheme))
                }
                Text(viewModel.isCreatingJob ? "Generating..." : "Generate")
                    .font(.interSemiBold(15))
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundColor(ENVITheme.background(for: colorScheme))
            .background(
                viewModel.canCreateJob
                    ? ENVITheme.text(for: colorScheme)
                    : ENVITheme.textSecondary(for: colorScheme).opacity(0.4)
            )
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        }
        .disabled(!viewModel.canCreateJob)
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Jobs List

    private var jobsList: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            if viewModel.isLoadingJobs {
                ENVILoadingState(minHeight: 80)
            } else if viewModel.jobs.isEmpty {
                emptyState
            } else {
                Text("Recent Jobs")
                    .font(.interSemiBold(17))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .padding(.horizontal, ENVISpacing.xl)

                ForEach(viewModel.jobs) { job in
                    jobCard(job: job)
                }
            }

            if let error = viewModel.jobError {
                Text(error)
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.error)
                    .padding(.horizontal, ENVISpacing.xl)
            }
        }
    }

    // MARK: - Subviews

    private func formatChip(format: RepurposeFormat, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: ENVISpacing.xs) {
                Image(systemName: format.systemImage)
                    .font(.system(size: 12))
                Text(format.displayName)
                    .font(.interMedium(13))
            }
            .padding(.horizontal, ENVISpacing.md)
            .padding(.vertical, ENVISpacing.sm)
            .foregroundColor(isSelected ? ENVITheme.text(for: colorScheme) : ENVITheme.textSecondary(for: colorScheme))
            .background(isSelected ? ENVITheme.surfaceHigh(for: colorScheme) : ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.sm)
                    .strokeBorder(isSelected ? ENVITheme.text(for: colorScheme).opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
    }

    private func targetFormatCard(format: RepurposeFormat) -> some View {
        let isSelected = viewModel.selectedTargetFormats.contains(format)

        return Button {
            viewModel.toggleTargetFormat(format)
        } label: {
            HStack(spacing: ENVISpacing.sm) {
                Image(systemName: format.systemImage)
                    .font(.system(size: 14))
                Text(format.displayName)
                    .font(.interMedium(14))
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
            }
            .padding(ENVISpacing.md)
            .foregroundColor(ENVITheme.text(for: colorScheme))
            .background(isSelected ? ENVITheme.surfaceHigh(for: colorScheme) : ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.md)
                    .strokeBorder(isSelected ? ENVITheme.text(for: colorScheme).opacity(0.3) : ENVITheme.border(for: colorScheme), lineWidth: 1)
            )
        }
    }

    private func jobCard(job: RepurposeJob) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            HStack {
                Label(job.sourceFormat.displayName, systemImage: job.sourceFormat.systemImage)
                    .font(.interMedium(15))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Spacer()

                statusBadge(job.status)
            }

            Text("\(job.targetFormats.count) target format\(job.targetFormats.count == 1 ? "" : "s")")
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            if !job.results.isEmpty {
                Divider()

                ForEach(job.results) { result in
                    HStack(spacing: ENVISpacing.sm) {
                        Image(systemName: result.format.systemImage)
                            .font(.system(size: 12))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                        Text(result.caption)
                            .font(.interRegular(13))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                            .lineLimit(2)

                        Spacer()

                        if !result.platform.isEmpty {
                            Text(result.platform)
                                .font(.interRegular(11))
                                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                        }
                    }
                }
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

    private func statusBadge(_ status: RepurposeJobStatus) -> some View {
        ENVIStatusBadge(text: status.displayName, color: statusColor(status))
    }

    private func statusColor(_ status: RepurposeJobStatus) -> Color {
        switch status {
        case .queued:      return ENVITheme.info
        case .processing:  return ENVITheme.warning
        case .completed:   return ENVITheme.success
        case .failed:      return ENVITheme.error
        }
    }

    private var emptyState: some View {
        ENVIEmptyState(
            icon: "arrow.triangle.2.circlepath",
            title: "No repurpose jobs yet",
            subtitle: "Select a source format and target formats to get started."
        )
    }
}

// MARK: - Preview

#Preview {
    RepurposeDashboardView(viewModel: RepurposingViewModel())
}
