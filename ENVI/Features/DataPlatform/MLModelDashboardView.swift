import SwiftUI

/// ML model dashboard with accuracy metrics, evaluation results, and data quality (ENVI-0961..0975).
struct MLModelDashboardView: View {

    @State private var models: [MLModel] = []
    @State private var evaluations: [EvaluationResult] = []
    @State private var qualityChecks: [DataQualityCheck] = []
    @State private var isLoading = true
    @State private var selectedModelID: UUID?
    @Environment(\.colorScheme) private var colorScheme

    private let repository = DataPlatformRepositoryProvider.shared.repository

    var body: some View {
        ScrollView {
            VStack(spacing: ENVISpacing.xxl) {
                header
                if isLoading {
                    ProgressView()
                        .padding(.top, ENVISpacing.xxl)
                } else {
                    summaryRow
                    modelsSection
                    evaluationsSection
                    dataQualitySection
                }
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .task { await loadData() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: ENVISpacing.sm) {
            Text("ML MODELS")
                .font(.spaceMonoBold(22))
                .tracking(-1)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Model performance and data quality")
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Summary Row

    private var summaryRow: some View {
        HStack(spacing: ENVISpacing.md) {
            summaryPill(
                value: "\(models.filter { $0.status == .deployed }.count)",
                label: "Deployed"
            )
            summaryPill(
                value: "\(models.filter { $0.status == .training }.count)",
                label: "Training"
            )
            summaryPill(
                value: "\(evaluations.filter(\.passed).count)/\(evaluations.count)",
                label: "Evals Pass"
            )
            summaryPill(
                value: "\(qualityChecks.filter { $0.status == .passed }.count)/\(qualityChecks.count)",
                label: "DQ Pass"
            )
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    private func summaryPill(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.spaceMonoBold(18))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text(label)
                .font(.interRegular(10))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
    }

    // MARK: - Models Section

    private var modelsSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionHeader("MODELS")

            ForEach(models) { model in
                modelCard(model)
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    private func modelCard(_ model: MLModel) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name)
                        .font(.spaceMonoBold(14))
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    Text("v\(model.version)")
                        .font(.interRegular(11))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }

                Spacer()

                Label(model.status.displayName, systemImage: model.status.iconName)
                    .font(.interRegular(11))
                    .foregroundColor(modelStatusColor(for: model.status))
                    .padding(.horizontal, ENVISpacing.sm)
                    .padding(.vertical, 2)
                    .background(modelStatusColor(for: model.status).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
            }

            HStack(spacing: ENVISpacing.lg) {
                // Accuracy
                VStack(alignment: .leading, spacing: 2) {
                    Text("Accuracy")
                        .font(.interRegular(10))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                    Text(model.formattedAccuracy)
                        .font(.spaceMonoBold(16))
                        .foregroundColor(accuracyColor(model.accuracy))
                }

                // Accuracy bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(ENVITheme.surfaceHigh(for: colorScheme))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(accuracyColor(model.accuracy))
                            .frame(width: geo.size.width * model.accuracy, height: 6)
                    }
                }
                .frame(height: 6)
            }

            Text("Last trained: \(model.lastTrained, style: .relative) ago")
                .font(.interRegular(10))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
    }

    // MARK: - Evaluations Section

    private var evaluationsSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionHeader("EVALUATION RESULTS")

            ForEach(evaluations) { eval in
                HStack {
                    Image(systemName: eval.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(eval.passed ? .green : .red)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(eval.metric)
                            .font(.spaceMonoBold(13))
                            .foregroundColor(ENVITheme.text(for: colorScheme))

                        Text(eval.modelID)
                            .font(.interRegular(10))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(eval.formattedScore)
                            .font(.spaceMonoBold(14))
                            .foregroundColor(eval.passed ? .green : .red)

                        Text("/ \(String(format: "%.2f", eval.threshold))")
                            .font(.interRegular(10))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    }
                }
                .padding(ENVISpacing.md)
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Data Quality Section

    private var dataQualitySection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionHeader("DATA QUALITY")

            ForEach(qualityChecks) { check in
                HStack {
                    Image(systemName: check.status.iconName)
                        .font(.system(size: 14))
                        .foregroundColor(dqStatusColor(for: check.status))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(check.checkType)
                            .font(.spaceMonoBold(13))
                            .foregroundColor(ENVITheme.text(for: colorScheme))

                        Text(check.table)
                            .font(.interRegular(10))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(check.status.displayName.uppercased())
                            .font(.spaceMonoBold(10))
                            .foregroundColor(dqStatusColor(for: check.status))

                        Text(check.lastRun, style: .relative)
                            .font(.interRegular(10))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    }
                }
                .padding(ENVISpacing.md)
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.spaceMonoBold(12))
            .tracking(1)
            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
    }

    // MARK: - Helpers

    private func modelStatusColor(for status: MLModelStatus) -> Color {
        switch status {
        case .training:   return .blue
        case .deployed:   return .green
        case .deprecated: return .orange
        case .failed:     return .red
        }
    }

    private func accuracyColor(_ accuracy: Double) -> Color {
        switch accuracy {
        case 0.9...1.0: return .green
        case 0.8..<0.9: return .orange
        default:        return .red
        }
    }

    private func dqStatusColor(for status: DataQualityStatus) -> Color {
        switch status {
        case .passed:  return .green
        case .warning: return .orange
        case .failed:  return .red
        case .pending: return .gray
        }
    }

    // MARK: - Actions

    private func loadData() async {
        defer { isLoading = false }
        async let m = repository.fetchMLModels()
        async let e = repository.fetchEvaluations()
        async let q = repository.fetchDataQuality()
        models = (try? await m) ?? []
        evaluations = (try? await e) ?? []
        qualityChecks = (try? await q) ?? []
    }
}

#Preview {
    MLModelDashboardView()
}
