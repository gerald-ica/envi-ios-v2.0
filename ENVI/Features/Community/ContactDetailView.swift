import SwiftUI

/// Contact profile with engagement metrics, platform presence, segment tags, and interaction history.
struct ContactDetailView: View {
    let contact: AudienceContact
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                header
                metricsRow
                platformsSection
                segmentsSection
                interactionTimeline
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: ENVISpacing.lg) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                }
                Spacer()
            }

            // Avatar + name
            VStack(spacing: ENVISpacing.md) {
                ZStack {
                    Circle()
                        .fill(ENVITheme.surfaceHigh(for: colorScheme))
                        .frame(width: 64, height: 64)
                    Text(String(contact.name.prefix(1)).uppercased())
                        .font(.spaceMonoBold(24))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                }

                Text(contact.name)
                    .font(.spaceMonoBold(17))
                    .tracking(-0.5)
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                if let email = contact.email {
                    Text(email)
                        .font(.spaceMono(12))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Metrics

    private var metricsRow: some View {
        HStack(spacing: ENVISpacing.md) {
            metricCard(title: "Engagement", value: "\(contact.engagementScore)", color: engagementColor)
            metricCard(title: "Lifetime Value", value: String(format: "$%.0f", contact.lifetimeValue), color: ENVITheme.text(for: colorScheme))
            metricCard(title: "Last Active", value: relativeDate(contact.lastInteraction), color: ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    private func metricCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: ENVISpacing.sm) {
            Text(value)
                .font(.spaceMonoBold(17))
                .foregroundColor(color)
            Text(title)
                .font(.spaceMono(10))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ENVISpacing.lg)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    private var engagementColor: Color {
        if contact.engagementScore >= 80 { return ENVITheme.success }
        if contact.engagementScore >= 50 { return ENVITheme.warning }
        return ENVITheme.error
    }

    // MARK: - Platforms

    private var platformsSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("PLATFORMS")
                .font(.spaceMono(11))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            HStack(spacing: ENVISpacing.md) {
                ForEach(contact.platforms) { platform in
                    HStack(spacing: ENVISpacing.sm) {
                        Image(systemName: platform.iconName)
                            .font(.system(size: 14))
                        Text(platform.displayName)
                            .font(.interMedium(13))
                    }
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .padding(.horizontal, ENVISpacing.md)
                    .padding(.vertical, ENVISpacing.sm)
                    .background(ENVITheme.surfaceLow(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: ENVIRadius.sm)
                            .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                    )
                }
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Segments

    private var segmentsSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("SEGMENTS")
                .font(.spaceMono(11))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            if contact.segments.isEmpty {
                Text("No segments assigned")
                    .font(.spaceMono(12))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            } else {
                FlowLayout(spacing: ENVISpacing.sm) {
                    ForEach(contact.segments, id: \.self) { segment in
                        Text(segment)
                            .font(.spaceMono(11))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                            .padding(.horizontal, ENVISpacing.md)
                            .padding(.vertical, ENVISpacing.sm)
                            .background(ENVITheme.surfaceHigh(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                    }
                }
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Interaction Timeline

    private var interactionTimeline: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("RECENT ACTIVITY")
                .font(.spaceMono(11))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            ForEach(mockInteractions, id: \.label) { interaction in
                HStack(spacing: ENVISpacing.md) {
                    // Timeline dot + line
                    VStack(spacing: 0) {
                        Circle()
                            .fill(ENVITheme.text(for: colorScheme))
                            .frame(width: 8, height: 8)
                        Rectangle()
                            .fill(ENVITheme.border(for: colorScheme))
                            .frame(width: 1, height: 28)
                    }

                    VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                        Text(interaction.label)
                            .font(.interMedium(13))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                        Text(interaction.detail)
                            .font(.spaceMono(11))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    }

                    Spacer()

                    Text(interaction.time)
                        .font(.spaceMono(10))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Helpers

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private var mockInteractions: [(label: String, detail: String, time: String)] {
        [
            ("Commented on post", "\"Love the new design!\"", "2h ago"),
            ("Liked 3 posts", "Via Instagram", "1d ago"),
            ("Shared story", "Mentioned @you", "3d ago"),
            ("Joined segment", "Added to Top Fans", "1w ago"),
        ]
    }
}

// MARK: - Flow Layout

/// Simple horizontal flow layout for tags.
private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

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
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}
