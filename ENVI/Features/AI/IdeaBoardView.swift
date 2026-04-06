import SwiftUI

/// Kanban-style idea board with columns for New, In Progress, and Published.
/// Cards can be moved between columns via context menu actions.
struct IdeaBoardView: View {
    let board: IdeaBoard
    let onMoveIdea: (ContentIdea, IdeaBoardColumn) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.lg) {
            // Board header
            HStack {
                Text(board.name.uppercased())
                    .font(.spaceMonoBold(13))
                    .tracking(-0.3)
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Spacer()

                Text("\(board.ideas.count) ideas")
                    .font(.spaceMono(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            // Columns
            ForEach(IdeaBoardColumn.allCases, id: \.self) { column in
                columnView(column: column, ideas: ideas(for: column))
            }
        }
    }

    // MARK: - Column

    private func columnView(column: IdeaBoardColumn, ideas: [ContentIdea]) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            // Column header
            HStack(spacing: ENVISpacing.sm) {
                Circle()
                    .fill(columnColor(column))
                    .frame(width: 8, height: 8)

                Text(column.displayName.uppercased())
                    .font(.spaceMono(10))
                    .tracking(0.5)
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                Text("\(ideas.count)")
                    .font(.spaceMono(10))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .padding(.horizontal, ENVISpacing.xs)
                    .padding(.vertical, 1)
                    .background(ENVITheme.surfaceLow(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Spacer()
            }

            if ideas.isEmpty {
                emptyColumn
            } else {
                ForEach(ideas) { idea in
                    ideaCard(idea, currentColumn: column)
                }
            }
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.background(for: colorScheme).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme).opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - Idea Card

    private func ideaCard(_ idea: ContentIdea, currentColumn: IdeaBoardColumn) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xs) {
            HStack {
                Text(idea.title)
                    .font(.interSemiBold(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .lineLimit(2)

                Spacer()

                Image(systemName: idea.source.iconName)
                    .font(.system(size: 10))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            if !idea.description.isEmpty {
                Text(idea.description)
                    .font(.interRegular(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .lineLimit(2)
            }

            HStack(spacing: ENVISpacing.sm) {
                // Platform badge
                HStack(spacing: 2) {
                    Image(systemName: idea.platform.iconName)
                        .font(.system(size: 8))
                    Text(idea.platform.rawValue)
                        .font(.spaceMono(8))
                }
                .padding(.horizontal, ENVISpacing.xs)
                .padding(.vertical, 1)
                .foregroundColor(idea.platform.brandColor)
                .background(idea.platform.brandColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))

                // Format badge
                Text(idea.format.displayName.uppercased())
                    .font(.spaceMono(8))
                    .tracking(0.3)
                    .padding(.horizontal, ENVISpacing.xs)
                    .padding(.vertical, 1)
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .background(ENVITheme.surfaceLow(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Spacer()

                // Trend score
                if idea.trendScore > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 8))
                        Text("\(Int(idea.trendScore))")
                            .font(.spaceMono(9))
                    }
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
            }
        }
        .padding(ENVISpacing.sm)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.sm)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
        .contextMenu {
            ForEach(IdeaBoardColumn.allCases.filter { $0 != currentColumn }, id: \.self) { targetColumn in
                Button(action: { onMoveIdea(idea, targetColumn) }) {
                    Label("Move to \(targetColumn.displayName)", systemImage: moveIcon(for: targetColumn))
                }
            }
        }
    }

    // MARK: - Empty Column

    private var emptyColumn: some View {
        Text("No ideas")
            .font(.interRegular(12))
            .foregroundColor(ENVITheme.textSecondary(for: colorScheme).opacity(0.6))
            .frame(maxWidth: .infinity, minHeight: 40)
    }

    // MARK: - Helpers

    private func ideas(for column: IdeaBoardColumn) -> [ContentIdea] {
        switch column {
        case .new:        return board.newIdeas
        case .inProgress: return board.inProgressIdeas
        case .published:  return board.publishedIdeas
        }
    }

    private func columnColor(_ column: IdeaBoardColumn) -> Color {
        switch column {
        case .new:        return .blue
        case .inProgress: return .orange
        case .published:  return .green
        }
    }

    private func moveIcon(for column: IdeaBoardColumn) -> String {
        switch column {
        case .new:        return "tray"
        case .inProgress: return "arrow.forward.circle"
        case .published:  return "checkmark.circle"
        }
    }
}

#Preview {
    ScrollView {
        IdeaBoardView(board: IdeaBoard.mock) { _, _ in }
            .padding()
    }
    .preferredColorScheme(.dark)
}
