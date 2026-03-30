import SwiftUI

/// Step 3: Optional birth time on its own screen.
struct OnboardingBirthTimeView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var colorScheme
    private let defaultBirthTime = Calendar(identifier: .gregorian).date(
        from: DateComponents(year: 2000, month: 1, day: 1, hour: 12, minute: 0)
    ) ?? Date()

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
                .onChange(of: viewModel.birthTime) { _, newValue in
                    viewModel.includeBirthTime = newValue != defaultBirthTime
                }
            }

            Spacer()
        }
    }
}
