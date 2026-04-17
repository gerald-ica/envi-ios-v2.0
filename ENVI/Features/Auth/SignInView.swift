import SwiftUI

/// Sign in screen with email + password fields.
struct SignInView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showForgotPassword = false
    @State private var resetEmailSent = false
    @State private var linkOnlyPlatform: SocialPlatform?
    @Environment(\.colorScheme) private var colorScheme

    var onSignIn: (() -> Void)?
    var onCreateAccount: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo area
            VStack(spacing: ENVISpacing.lg) {
                ENVIWordmark(size: .heading, color: ENVITheme.text(for: colorScheme))

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

            // ENVI-0004 Google Sign In
            GoogleSignInButton {
                TelemetryManager.shared.track(.authSignInSucceeded)
                onSignIn?()
            } onError: { error in
                errorMessage = "Google Sign In failed. Please try again."
                TelemetryManager.shared.track(.authSignInFailed)
                TelemetryManager.shared.record(error: error, context: "google_sign_in")
            }
            .padding(.horizontal, ENVISpacing.xl)
            .padding(.top, ENVISpacing.sm)

            // Social identity providers — Meta & X sign in directly,
            // Instagram & TikTok open an explainer sheet because they
            // can only be linked (not used as identity) for now.
            Text("OR CONTINUE WITH")
                .font(.spaceMono(10))
                .tracking(1.4)
                .foregroundColor(ENVITheme.textLight(for: colorScheme))
                .padding(.top, ENVISpacing.lg)

            HStack(spacing: ENVISpacing.lg) {
                SocialSignInButton(platform: .facebook) { signInWithOAuth(.facebook) }
                SocialSignInButton(platform: .x)        { signInWithOAuth(.x) }
                SocialSignInButton(platform: .instagram) { linkOnlyPlatform = .instagram }
                SocialSignInButton(platform: .tiktok)    { linkOnlyPlatform = .tiktok }
            }
            .padding(.top, ENVISpacing.md)

            // ENVI-0017 Forgot Password
            Button(action: { showForgotPassword = true }) {
                Text("Forgot password?")
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))
            }
            .padding(.top, ENVISpacing.lg)

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
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordSheet(
                onResetSent: { resetEmailSent = true },
                colorScheme: colorScheme
            )
            .presentationDetents([.medium])
        }
        .sheet(item: $linkOnlyPlatform) { platform in
            LinkOnlyPlatformSheet(platform: platform)
                .presentationDetents([.medium])
        }
        .alert("Reset Email Sent", isPresented: $resetEmailSent) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Check your inbox for a password reset link.")
        }
    }

    private func signInWithOAuth(_ platform: SocialPlatform) {
        guard !isLoading else { return }
        errorMessage = nil
        isLoading = true
        TelemetryManager.shared.track(.authSignInStarted)

        Task {
            do {
                switch platform {
                case .facebook:
                    _ = try await AuthManager.shared.signInWithFacebook()
                case .x:
                    _ = try await AuthManager.shared.signInWithX()
                default:
                    throw AuthManager.AuthError.invalidCredential
                }
                await MainActor.run {
                    isLoading = false
                    TelemetryManager.shared.track(.authSignInSucceeded)
                    onSignIn?()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "\(platform.rawValue) sign in failed. Please try again."
                    TelemetryManager.shared.track(.authSignInFailed)
                    TelemetryManager.shared.record(error: error, context: "\(platform.apiSlug)_sign_in")
                }
            }
        }
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
