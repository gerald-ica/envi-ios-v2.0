import SwiftUI

/// Step 1: First + Last name entry for USM onboarding.
struct USMOnboardingNameView: View {
    @Bindable var viewModel: USMOnboardingViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
            Text("WHAT'S YOUR NAME?")
                .font(.spaceMonoBold(32))
                .tracking(-2.0)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("First and last name help us personalize your experience.")
                .font(.interRegular(15))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            VStack(alignment: .leading, spacing: ENVISpacing.md) {
                Text("FIRST NAME")
                    .font(.spaceMono(11))
                    .tracking(0.88)
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))

                TextField("First Name", text: $viewModel.firstName)
                    .font(.interRegular(16))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(.horizontal, ENVISpacing.md)
                    .padding(.vertical, ENVISpacing.md)
                    .background(ENVITheme.surfaceLow(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: ENVIRadius.md)
                            .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1.5)
                    )
            }

            VStack(alignment: .leading, spacing: ENVISpacing.md) {
                Text("LAST NAME (OPTIONAL)")
                    .font(.spaceMono(11))
                    .tracking(0.88)
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))

                TextField("Last Name", text: $viewModel.lastName)
                    .font(.interRegular(16))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(.horizontal, ENVISpacing.md)
                    .padding(.vertical, ENVISpacing.md)
                    .background(ENVITheme.surfaceLow(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: ENVIRadius.md)
                            .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1.5)
                    )
            }

            Spacer()
        }
    }
}
