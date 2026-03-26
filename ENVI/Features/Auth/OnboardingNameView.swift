import SwiftUI

/// Step 1: First + Last name entry.
struct OnboardingNameView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
            Text("What's your name?")
                .font(.interBlack(32))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("So we know how to greet you.")
                .font(.interRegular(15))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            HStack(spacing: ENVISpacing.md) {
                ENVIInput(
                    label: "First Name",
                    placeholder: "First",
                    text: $viewModel.firstName
                )

                ENVIInput(
                    label: "Last Name",
                    placeholder: "Last",
                    text: $viewModel.lastName
                )
            }

            Spacer()
        }
    }
}
