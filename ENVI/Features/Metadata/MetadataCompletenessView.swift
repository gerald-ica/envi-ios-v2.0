import SwiftUI

/// Completeness score gauge with missing fields list for a content asset.
struct MetadataCompletenessView: View {
    @ObservedObject var viewModel: MetadataViewModel
    let assetID: UUID
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                header

                if viewModel.isLoadingCompleteness {
                    ENVILoadingState(minHeight: 200)
                } else if let metadata = viewModel.contentMetadata {
                    gaugeSection(metadata)
                    tagsSummary(metadata)
                    missingFieldsList(metadata)
                    clusterSection
                } else {
                    emptyState
                }
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .task {
            await viewModel.loadCompleteness(for: assetID)
            await viewModel.loadTopicClusters()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xs) {
            Text("METADATA COMPLETENESS")
                .font(.spaceMonoBold(17))
                .tracking(-0.5)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("How well your content is tagged and categorized")
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Gauge

    private func gaugeSection(_ metadata: ContentMetadata) -> some View {
        VStack(spacing: ENVISpacing.lg) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(ENVITheme.surfaceHigh(for: colorScheme), lineWidth: 12)

                // Progress ring
                Circle()
                    .trim(from: 0, to: metadata.completenessScore)
                    .stroke(
                        scoreColor(metadata.completenessScore),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.8), value: metadata.completenessScore)

                // Center label
                VStack(spacing: ENVISpacing.xs) {
                    Text("\(metadata.completenessPercent)%")
                        .font(.interBold(32))
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    Text("Complete")
                        .font(.interRegular(13))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
            }
            .frame(width: 160, height: 160)

            Text(scoreLabel(metadata.completenessScore))
                .font(.interSemiBold(14))
                .foregroundColor(scoreColor(metadata.completenessScore))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ENVISpacing.lg)
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 0.8 { return ENVITheme.success }
        if score >= 0.5 { return ENVITheme.warning }
        return ENVITheme.error
    }

    private func scoreLabel(_ score: Double) -> String {
        if score >= 0.8 { return "Well tagged" }
        if score >= 0.5 { return "Needs improvement" }
        return "Incomplete metadata"
    }

    // MARK: - Tags Summary

    private func tagsSummary(_ metadata: ContentMetadata) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("APPLIED TAGS")
                .font(.spaceMonoBold(12))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            if metadata.tags.isEmpty {
                Text("No tags applied yet.")
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            } else {
                FlowLayout(spacing: ENVISpacing.sm) {
                    ForEach(metadata.tags) { tag in
                        HStack(spacing: ENVISpacing.xs) {
                            Circle()
                                .fill(Color(hex: tag.color))
                                .frame(width: 8, height: 8)

                            Text(tag.name)
                                .font(.interRegular(12))
                                .foregroundColor(ENVITheme.text(for: colorScheme))
                        }
                        .padding(.horizontal, ENVISpacing.sm)
                        .padding(.vertical, ENVISpacing.xs)
                        .background(ENVITheme.surfaceLow(for: colorScheme))
                        .cornerRadius(ENVIRadius.sm)
                    }
                }
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Missing Fields

    private func missingFieldsList(_ metadata: ContentMetadata) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("MISSING FIELDS")
                .font(.spaceMonoBold(12))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            if metadata.missingFields.isEmpty {
                HStack(spacing: ENVISpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(ENVITheme.success)
                    Text("All key fields are covered")
                        .font(.interRegular(13))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                }
            } else {
                ForEach(metadata.missingFields, id: \.self) { field in
                    HStack(spacing: ENVISpacing.md) {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundColor(ENVITheme.warning)
                            .font(.system(size: 14))

                        Text(field)
                            .font(.interRegular(14))
                            .foregroundColor(ENVITheme.text(for: colorScheme))

                        Spacer()

                        Image(systemName: "plus.circle")
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                            .font(.system(size: 14))
                    }
                    .padding(ENVISpacing.md)
                    .background(ENVITheme.surfaceLow(for: colorScheme))
                    .cornerRadius(ENVIRadius.sm)
                }
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Clusters

    private var clusterSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("TOPIC CLUSTERS")
                .font(.spaceMonoBold(12))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            if viewModel.isLoadingClusters {
                ENVILoadingState(minHeight: 60)
            } else {
                ForEach(viewModel.topicClusters) { cluster in
                    clusterCard(cluster)
                }
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    private func clusterCard(_ cluster: TopicCluster) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            HStack {
                Text(cluster.name)
                    .font(.interSemiBold(14))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Spacer()

                Text("\(cluster.contentCount) items")
                    .font(.interRegular(12))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            HStack(spacing: ENVISpacing.xs) {
                ForEach(cluster.relatedTags.prefix(5)) { tag in
                    Text(tag.name)
                        .font(.interRegular(11))
                        .foregroundColor(Color(hex: tag.color))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: tag.color).opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .cornerRadius(ENVIRadius.md)
    }

    // MARK: - Empty

    private var emptyState: some View {
        ENVIEmptyState(
            icon: "chart.bar.doc.horizontal",
            title: "No metadata available"
        )
    }
}

// MARK: - Flow Layout

/// Horizontal wrapping layout for tags in the completeness view.
private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalWidth = max(totalWidth, x)
        }

        return (CGSize(width: totalWidth, height: y + rowHeight), positions)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    MetadataCompletenessView(
        viewModel: MetadataViewModel(repository: MockMetadataRepository()),
        assetID: UUID()
    )
}
#endif
