import SwiftUI

/// Step 3: Where are you from? + city chip selection.
struct OnboardingWhereFromView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
            Text("Where are you from?")
                .font(.interBlack(32))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Helps us tailor content for your audience.")
                .font(.interRegular(15))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            ENVIInput(
                label: "City",
                placeholder: "Enter your city",
                text: $viewModel.location
            )

            // Chip grid
            VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                Text("POPULAR")
                    .font(.spaceMono(11))
                    .tracking(0.88)
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))

                FlowLayout(spacing: ENVISpacing.sm) {
                    ForEach(viewModel.locationChips, id: \.self) { city in
                        ENVIChip(
                            title: city,
                            isSelected: viewModel.selectedLocation == city
                        ) {
                            viewModel.selectedLocation = city
                            viewModel.location = city
                        }
                    }
                }
            }

            Spacer()
        }
    }
}

// MARK: - Flow Layout (chip wrapping)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }

        return (positions, CGSize(width: maxX, height: currentY + lineHeight))
    }
}
