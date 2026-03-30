import SwiftUI

/// Step 6: Where were you born? + city chip selection.
struct OnboardingWhereBornView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
            Text("WHERE WERE YOU BORN?")
                .font(.spaceMonoBold(32))
                .tracking(-2.0)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Your roots shape your perspective.")
                .font(.interRegular(15))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            ENVIInput(
                label: "City",
                placeholder: "Enter your birthplace",
                text: $viewModel.birthplace
            )

            // Chip grid
            VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                Text("POPULAR")
                    .font(.spaceMono(11))
                    .tracking(0.88)
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))

                FlowLayout(spacing: ENVISpacing.sm) {
                    ForEach(viewModel.birthplaceChips, id: \.self) { city in
                        ENVIChip(
                            title: city,
                            isSelected: viewModel.selectedBirthplace == city
                        ) {
                            viewModel.selectedBirthplace = city
                            viewModel.birthplace = city
                        }
                    }
                }
            }

            Spacer()
        }
    }
}
