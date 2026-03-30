import SwiftUI

/// Sign in screen with email + password fields.
struct SignInView: View {
    @State private var email = ""
    @State private var password = ""
    @Environment(\.colorScheme) private var colorScheme

    var onSignIn: (() -> Void)?
    var onCreateAccount: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo area
            VStack(spacing: ENVISpacing.lg) {
                Text("ENVI")
                    .font(.spaceMonoBold(40))
                    .tracking(-2.0)
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text("Welcome back")
                    .font(.interRegular(15))
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))
            }
            .padding(.bottom, ENVISpacing.xxxxl)

            // Fields
            VStack(spacing: ENVISpacing.lg) {
                ENVIInput(
                    label: "Email",
                    placeholder: "you@email.com",
                    text: $email
                )

                ENVIInput(
                    label: "Password",
                    placeholder: "••••••••",
                    text: $password,
                    isSecure: true
                )
            }
            .padding(.horizontal, ENVISpacing.xl)

            // Sign In button
            ENVIButton("Sign In", isEnabled: isValid) {
                onSignIn?()
            }
            .padding(.horizontal, ENVISpacing.xl)
            .padding(.top, ENVISpacing.xxl)

            Spacer()

            // Create account
            HStack(spacing: 4) {
                Text("Don't have an account?")
                    .font(.interRegular(14))
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))

                Button("Sign Up") {
                    onCreateAccount?()
                }
                .font(.spaceMonoBold(14))
                .tracking(1.0)
                .foregroundColor(ENVITheme.text(for: colorScheme))
            }
            .padding(.bottom, ENVISpacing.xxxl)
        }
        .background(ENVITheme.background(for: colorScheme))
    }

    private var isValid: Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        return !trimmedEmail.isEmpty &&
               trimmedEmail.contains("@") &&
               trimmedEmail.contains(".") &&
               !password.isEmpty
    }
}

#Preview {
    SignInView()
        .preferredColorScheme(.dark)
}
