import SwiftUI

/// Step 2: Date of birth with MM/DD/YYYY segmented fields.
struct OnboardingDOBView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
            Text("When's your birthday?")
                .font(.interBlack(32))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("This helps personalize your experience.")
                .font(.interRegular(15))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            HStack(spacing: ENVISpacing.md) {
                DOBField(label: "MM", placeholder: "01", text: $viewModel.dobMonth, maxLength: 2)
                DOBField(label: "DD", placeholder: "15", text: $viewModel.dobDay, maxLength: 2)
                DOBField(label: "YYYY", placeholder: "1998", text: $viewModel.dobYear, maxLength: 4)
            }

            Spacer()
        }
    }
}

// MARK: - DOB Field
private struct DOBField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let maxLength: Int

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Text(label)
                .font(.spaceMono(11))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            TextField(placeholder, text: $text)
                .font(.interRegular(17))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .padding(.horizontal, ENVISpacing.md)
                .padding(.vertical, ENVISpacing.md)
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.md)
                        .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1.5)
                )
                .onChange(of: text) { _, newValue in
                    if newValue.count > maxLength {
                        text = String(newValue.prefix(maxLength))
                    }
                }
        }
    }
}
