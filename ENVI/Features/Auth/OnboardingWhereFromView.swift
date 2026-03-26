import SwiftUI

/// Step 3: Where are you from? + city chip selection.
struct OnboardingWhereFromView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
            Text("WHERE ARE YOU FROM?")
                .font(.spaceMonoBold(32))
                .tracking(-2.0)
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
