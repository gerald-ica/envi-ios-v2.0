import SwiftUI

/// Sign in screen with email + password fields.
struct SignInView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
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

            if let errorMessage {
                Text(errorMessage)
                    .font(.interRegular(13))
                    .foregroundColor(.red.opacity(0.9))
                    .padding(.horizontal, ENVISpacing.xl)
                    .padding(.top, ENVISpacing.md)
            }

            // Sign In button
            ENVIButton(isLoading ? "Signing in..." : "Sign In", isEnabled: isValid && !isLoading) {
                signIn()
            }
            .padding(.horizontal, ENVISpacing.xl)
            .padding(.top, ENVISpacing.xxl)

            // Divider
            HStack {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(ENVITheme.textLight(for: colorScheme).opacity(0.3))
                Text("or")
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(ENVITheme.textLight(for: colorScheme).opacity(0.3))
            }
            .padding(.horizontal, ENVISpacing.xl)
            .padding(.top, ENVISpacing.lg)

            // Apple Sign In
            AppleSignInButton { payload in
                TelemetryManager.shared.track(.authSignInSucceeded)
                onSignIn?()
            } onError: { error in
                errorMessage = "Apple Sign In failed. Please try again."
                TelemetryManager.shared.track(.authSignInFailed)
                TelemetryManager.shared.record(error: error, context: "apple_sign_in")
            }
            .padding(.horizontal, ENVISpacing.xl)
            .padding(.top, ENVISpacing.md)

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
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty
    }

    private func signIn() {
        guard !isLoading else { return }
        errorMessage = nil
        isLoading = true
        TelemetryManager.shared.track(.authSignInStarted)

        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                _ = try await AuthManager.shared.signIn(email: normalizedEmail, password: password)
                await MainActor.run {
                    isLoading = false
                    TelemetryManager.shared.track(.authSignInSucceeded)
                    onSignIn?()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Sign in failed. Check your credentials and try again."
                    TelemetryManager.shared.track(.authSignInFailed)
                    TelemetryManager.shared.record(error: error, context: "sign_in")
                }
            }
        }
    }
}

#Preview {
    SignInView()
        .preferredColorScheme(.dark)
}
