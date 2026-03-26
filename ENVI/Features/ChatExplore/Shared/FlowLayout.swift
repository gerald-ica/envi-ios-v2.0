import SwiftUI

/// A reusable flow / wrap layout that arranges children left-to-right,
/// wrapping to a new line when the available width is exceeded.
/// Ideal for quick-action chips in the chat home view.
///
/// Usage:
/// ```
/// FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
///     ForEach(items) { item in
///         ChipView(item)
///     }
/// }
/// ```
struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat

    init(horizontalSpacing: CGFloat = ENVISpacing.sm,
         verticalSpacing: CGFloat = ENVISpacing.sm) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    /// Convenience initializer using a single spacing value for both axes.
    init(spacing: CGFloat) {
        self.horizontalSpacing = spacing
        self.verticalSpacing = spacing
    }

    // MARK: - Layout Protocol

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.totalSize
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, subview) in subviews.enumerated() {
            guard index < result.positions.count else { break }
            let position = result.positions[index]
            subview.place(
                at: CGPoint(
                    x: bounds.minX + position.x,
                    y: bounds.minY + position.y
                ),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }

    // MARK: - Internal arrangement

    private struct ArrangementResult {
        var positions: [CGPoint]
        var sizes: [CGSize]
        var totalSize: CGSize
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> ArrangementResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []

        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            sizes.append(size)

            // Wrap to next line if this subview exceeds available width
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + verticalSpacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + horizontalSpacing
        }

        let totalWidth = maxWidth
        let totalHeight = currentY + lineHeight

        return ArrangementResult(
            positions: positions,
            sizes: sizes,
            totalSize: CGSize(width: totalWidth, height: totalHeight)
        )
    }
}

// MARK: - Preview

#if DEBUG
struct FlowLayout_Previews: PreviewProvider {
    static let sampleChips = [
        "Climate Change", "AI Ethics", "Space", "Quantum Computing",
        "Health", "Ocean", "Economy", "Art", "History", "Music"
    ]

    static var previews: some View {
        FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(sampleChips, id: \.self) { chip in
                Text(chip.uppercased())
                    .font(.spaceMono(11))
                    .tracking(1.5)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: ENVIRadius.sm)
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ENVIRadius.sm)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    )
            }
        }
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}
#endif
