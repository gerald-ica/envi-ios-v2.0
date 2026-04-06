import SwiftUI

/// Grid of experiment cards with status filtering and create action.
struct ExperimentListView: View {
    @ObservedObject var viewModel: ExperimentViewModel
    @Environment(\.colorScheme) private var colorScheme

    private let columns = [
        GridItem(.flexible(), spacing: ENVISpacing.md),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                header
                statusFilterBar

                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else if viewModel.filteredExperiments.isEmpty {
                    emptyState
                } else {
                    experimentList
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.interRegular(13))
                        .foregroundColor(ENVITheme.error)
                        .padding(.horizontal, ENVISpacing.xl)
                }
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .sheet(isPresented: $viewModel.isShowingEditor) {
            if let experiment = viewModel.editingExperiment {
                ExperimentEditorView(
                    experiment: experiment,
                    onSave: { updated in
                        Task { await viewModel.saveExperiment(updated) }
                    },
                    onCancel: {
                        viewModel.isShowingEditor = false
                        viewModel.editingExperiment = nil
                    }
                )
            }
        }
        .sheet(isPresented: $viewModel.isShowingResults) {
            if let experiment = viewModel.selectedExperiment {
                ExperimentResultsView(
                    experiment: experiment,
                    result: viewModel.currentResult,
                    isLoading: viewModel.isLoadingResults
                )
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                Text("EXPERIMENTS")
                    .font(.spaceMonoBold(17))
                    .tracking(-0.5)
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text("\(viewModel.experiments.count) experiments")
                    .font(.spaceMono(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            Spacer()

            Button(action: { viewModel.startCreatingExperiment() }) {
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

                ForEach(ExperimentStatus.allCases) { status in
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

    // MARK: - Experiment List

    private var experimentList: some View {
        LazyVGrid(columns: columns, spacing: ENVISpacing.md) {
            ForEach(viewModel.filteredExperiments) { experiment in
                ExperimentCardView(experiment: experiment)
                    .onTapGesture {
                        if experiment.status == .completed {
                            viewModel.showResults(for: experiment)
                        } else {
                            viewModel.startEditingExperiment(experiment)
                        }
                    }
                    .contextMenu {
                        if experiment.status == .draft {
                            Button("Start") { Task { await viewModel.startExperiment(experiment) } }
                            Button("Edit") { viewModel.startEditingExperiment(experiment) }
                        }
                        if experiment.status == .running {
                            Button("Stop") { Task { await viewModel.stopExperiment(experiment) } }
                        }
                        if experiment.status == .completed {
                            Button("View Results") { viewModel.showResults(for: experiment) }
                        }
                    }
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: ENVISpacing.md) {
            Image(systemName: "flask")
                .font(.system(size: 32))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Text("No experiments yet")
                .font(.interMedium(15))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Create an A/B test to compare content variants and discover what resonates with your audience.")
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)

            ENVIButton("New Experiment", variant: .secondary, isFullWidth: false) {
                viewModel.startCreatingExperiment()
            }
        }
        .padding(ENVISpacing.xxxl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Experiment Card

private struct ExperimentCardView: View {
    let experiment: Experiment
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            // Top row: status badge + date range
            HStack {
                statusBadge
                Spacer()
                dateRangeLabel
            }

            // Name
            Text(experiment.name)
                .font(.interSemiBold(17))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .lineLimit(2)

            // Hypothesis
            if !experiment.hypothesis.isEmpty {
                Text(experiment.hypothesis)
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .lineLimit(2)
            }

            // Bottom row: variant count + platform
            HStack {
                HStack(spacing: ENVISpacing.xs) {
                    Image(systemName: "rectangle.split.2x1")
                        .font(.system(size: 10))
                    Text("\(experiment.variants.count) variants")
                        .font(.spaceMono(11))
                }
                .foregroundColor(ENVITheme.text(for: colorScheme))

                Spacer()

                if let platform = experiment.variants.first?.platform {
                    HStack(spacing: ENVISpacing.xs) {
                        Image(systemName: platform.iconName)
                            .font(.system(size: 10))
                        Text(platform.rawValue)
                            .font(.spaceMono(10))
                    }
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
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
    }

    private var statusBadge: some View {
        HStack(spacing: ENVISpacing.xs) {
            Image(systemName: experiment.status.iconName)
                .font(.system(size: 10))
            Text(experiment.status.displayName.uppercased())
                .font(.spaceMono(10))
                .tracking(0.5)
        }
        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
    }

    private var dateRangeLabel: some View {
        HStack(spacing: ENVISpacing.xs) {
            Image(systemName: "calendar")
                .font(.system(size: 10))
            Text(experiment.dateRangeLabel)
                .font(.spaceMono(10))
        }
        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
    }
}

#Preview {
    NavigationView {
        ExperimentListView(viewModel: ExperimentViewModel())
    }
    .preferredColorScheme(.dark)
}
