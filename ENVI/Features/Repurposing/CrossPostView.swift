import SwiftUI

/// Derivative tree view showing source content mapped to its cross-posted format outputs.
struct CrossPostView: View {
    @ObservedObject var viewModel: RepurposingViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                header

                if viewModel.isLoadingMappings {
                    ENVILoadingState()
                } else if viewModel.mappings.isEmpty {
                    emptyState
                } else {
                    mappingsList
                }
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xs) {
            Text("Cross-Post Map")
                .font(.interSemiBold(22))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("See how each source post branches into derivatives across platforms.")
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Mappings List

    private var mappingsList: some View {
        VStack(spacing: ENVISpacing.lg) {
            ForEach(viewModel.mappings) { mapping in
                mappingCard(mapping)
            }
        }
    }

    // MARK: - Mapping Card

    private func mappingCard(_ mapping: CrossPostMapping) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            // Source header
            HStack(spacing: ENVISpacing.sm) {
                Image(systemName: "doc.text")
                    .font(.system(size: 14))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .frame(width: 28, height: 28)
                    .background(ENVITheme.surfaceHigh(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))

                VStack(alignment: .leading, spacing: 2) {
                    Text(mapping.sourceTitle.isEmpty ? "Source Post" : mapping.sourceTitle)
                        .font(.interSemiBold(15))
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    Text("\(mapping.derivatives.count) derivative\(mapping.derivatives.count == 1 ? "" : "s")")
                        .font(.interRegular(12))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }

                Spacer()
            }

            Divider()

            // Derivative tree
            ForEach(Array(mapping.derivatives.enumerated()), id: \.element.id) { index, derivative in
                derivativeRow(derivative: derivative, isLast: index == mapping.derivatives.count - 1)
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

    // MARK: - Derivative Row

    private func derivativeRow(derivative: DerivativePost, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: ENVISpacing.sm) {
            // Tree connector
            VStack(spacing: 0) {
                Rectangle()
                    .fill(ENVITheme.border(for: colorScheme))
                    .frame(width: 1, height: 12)

                Circle()
                    .fill(ENVITheme.textSecondary(for: colorScheme))
                    .frame(width: 6, height: 6)

                if !isLast {
                    Rectangle()
                        .fill(ENVITheme.border(for: colorScheme))
                        .frame(width: 1)
                }
            }
            .frame(width: 12)

            // Content
            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                HStack(spacing: ENVISpacing.sm) {
                    Image(systemName: derivative.format.systemImage)
                        .font(.system(size: 11))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                    Text(derivative.platform)
                        .font(.interMedium(13))
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    Text(derivative.format.displayName)
                        .font(.interRegular(11))
                        .padding(.horizontal, ENVISpacing.sm)
                        .padding(.vertical, 2)
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                        .background(ENVITheme.surfaceHigh(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))

                    Spacer()
                }

                Text(derivative.caption)
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .lineLimit(2)

                if let date = derivative.scheduledAt {
                    HStack(spacing: ENVISpacing.xs) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(date, style: .date)
                            .font(.interRegular(11))
                    }
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
            }
            .padding(.vertical, ENVISpacing.xs)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ENVIEmptyState(
            icon: "arrow.triangle.branch",
            title: "No cross-post mappings",
            subtitle: "Repurpose content to see how it branches across platforms and formats."
        )
    }
}

// MARK: - Preview

#Preview {
    CrossPostView(viewModel: RepurposingViewModel())
}
