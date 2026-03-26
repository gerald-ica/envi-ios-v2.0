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
                    .font(.interBlack(40))
                    .foregroundColor(ENVITheme.primary(for: colorScheme))

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
                .font(.interSemiBold(14))
                .foregroundColor(ENVITheme.primary(for: colorScheme))
            }
            .padding(.bottom, ENVISpacing.xxxl)
        }
        .background(ENVITheme.background(for: colorScheme))
    }

    private var isValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty
    }
}

#Preview {
    SignInView()
        .preferredColorScheme(.dark)
}
