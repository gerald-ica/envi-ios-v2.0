import SwiftUI

/// Kanban board with backlog / in-progress / review / done columns.
/// Items can be moved between columns via context menu or long-press actions.
struct SprintBoardView: View {
    @ObservedObject var viewModel: CampaignViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.lg) {
            header

            if viewModel.isLoadingSprint {
                ENVILoadingState(minHeight: 200)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: ENVISpacing.md) {
                        ForEach(SprintColumn.allCases) { column in
                            sprintColumnView(column)
                        }
                    }
                    .padding(.horizontal, ENVISpacing.xl)
                    .padding(.bottom, ENVISpacing.xl)
                }
            }

            if let error = viewModel.campaignError {
                Text(error)
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.error)
                    .padding(.horizontal, ENVISpacing.xl)
            }
        }
        .background(ENVITheme.background(for: colorScheme))
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                    Text("SPRINT BOARD")
                        .font(.spaceMonoBold(17))
                        .tracking(-0.5)
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    Text("\(viewModel.sprintItems.count) items")
                        .font(.spaceMono(11))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }

                Spacer()

                // Sprint progress
                VStack(alignment: .trailing, spacing: ENVISpacing.xs) {
                    Text("\(Int(viewModel.sprintProgress * 100))%")
                        .font(.spaceMonoBold(15))
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    Text("COMPLETE")
                        .font(.spaceMono(9))
                        .tracking(0.5)
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ENVITheme.surfaceHigh(for: colorScheme))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(ENVITheme.text(for: colorScheme))
                        .frame(width: geo.size.width * viewModel.sprintProgress, height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, ENVISpacing.xl)
        .padding(.top, ENVISpacing.xl)
    }

    // MARK: - Column

    private func sprintColumnView(_ column: SprintColumn) -> some View {
        let items = viewModel.sprintItems(for: column)

        return VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            // Column header
            HStack {
                Text(column.displayName.uppercased())
                    .font(.spaceMono(11))
                    .tracking(0.5)
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                Spacer()

                Text("\(items.count)")
                    .font(.spaceMono(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .frame(width: 22, height: 22)
                    .background(ENVITheme.surfaceHigh(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
            }

            // Items
            if items.isEmpty {
                emptyColumnPlaceholder
            } else {
                ForEach(items) { item in
                    SprintItemCard(item: item, colorScheme: colorScheme) { targetColumn in
                        Task { await viewModel.moveSprintItem(item, to: targetColumn) }
                    }
                }
            }
        }
        .frame(width: 220)
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    private var emptyColumnPlaceholder: some View {
        Text("No items")
            .font(.interRegular(12))
            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            .frame(maxWidth: .infinity, minHeight: 60)
    }
}

// MARK: - Sprint Item Card

private struct SprintItemCard: View {
    let item: SprintItem
    let colorScheme: ColorScheme
    let onMove: (SprintColumn) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Text(item.title)
                .font(.interMedium(13))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .lineLimit(2)

            if !item.assignee.isEmpty {
                HStack(spacing: ENVISpacing.xs) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 10))
                    Text(item.assignee)
                        .font(.spaceMono(10))
                }
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }
        }
        .padding(ENVISpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ENVITheme.surfaceHigh(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.md)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
        .contextMenu {
            ForEach(SprintColumn.allCases) { column in
                if column != item.column {
                    Button("Move to \(column.displayName)") {
                        onMove(column)
                    }
                }
            }
        }
    }
}

#Preview {
    SprintBoardView(viewModel: CampaignViewModel())
        .preferredColorScheme(.dark)
}
