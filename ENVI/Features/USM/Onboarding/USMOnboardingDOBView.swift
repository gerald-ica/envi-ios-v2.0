import SwiftUI

/// Step 2: Date of birth + optional time of birth for USM onboarding.
struct USMOnboardingDOBView: View {
    @Bindable var viewModel: USMOnboardingViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
            Text("WHEN WERE YOU BORN?")
                .font(.spaceMonoBold(32))
                .tracking(-2.0)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("We need your birth date and, if known, the exact time.")
                .font(.interRegular(15))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            // Birth Date Picker
            USMWheelPickerCard(title: "BIRTH DATE") {
                DatePicker(
                    "",
                    selection: $viewModel.dateOfBirth,
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .clipped()
            }

            // Time of Birth Toggle
            Toggle("I know my exact birth time", isOn: $viewModel.hasKnownBirthTime)
                .font(.interRegular(15))
                .tint(ENVITheme.primary(for: colorScheme))

            // Time of Birth Picker (conditional)
            if viewModel.hasKnownBirthTime {
                USMWheelPickerCard(title: "BIRTH TIME") {
                    DatePicker(
                        "",
                        selection: $viewModel.timeOfBirth,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .clipped()
                }
            }

            Spacer()
        }
    }
}

// MARK: - Wheel Picker Card

struct USMWheelPickerCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text(title)
                .font(.spaceMono(11))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            content
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.lg)
                        .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1.5)
                )
        }
    }
}
