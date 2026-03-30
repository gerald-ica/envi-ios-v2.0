import SwiftUI

/// Step 3: Optional birth time on its own screen.
struct OnboardingBirthTimeView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
            Text("WHAT TIME WERE YOU BORN?")
                .font(.spaceMonoBold(32))
                .tracking(-2.0)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Including your birth time is optional, but it helps personalize and enhance your ENVI experience.")
                .font(.interRegular(15))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            Text("If you don't know it, you can just continue.")
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            WheelPickerCard(title: "TIME OF BIRTH") {
                DatePicker(
                    "",
                    selection: $viewModel.birthTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .clipped()
                .onChange(of: viewModel.birthTime) { _, _ in
                    viewModel.hasEditedBirthTime = true
                }
            }

            Spacer()
        }
    }
}
