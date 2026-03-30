import SwiftUI

/// Step 2: Date of birth with wheel pickers.
struct OnboardingDOBView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
            Text("WHEN'S YOUR BIRTHDAY?")
                .font(.spaceMonoBold(32))
                .tracking(-2.0)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Pick your birth date on the wheel below.")
                .font(.interRegular(15))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            WheelPickerCard(title: "BIRTH DATE") {
                DatePicker(
                    "",
                    selection: $viewModel.dateOfBirth,
                    in: viewModel.birthDateRange,
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .clipped()
                .onChange(of: viewModel.dateOfBirth) { _, _ in
                    viewModel.hasEditedDOB = true
                }
            }

            Spacer()
        }
    }
}

struct WheelPickerCard<Content: View>: View {
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
