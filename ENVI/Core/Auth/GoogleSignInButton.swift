import SwiftUI
import UIKit

/// ENVI-0004: Google Sign-In button matching the ENVI design system.
struct GoogleSignInButton: View {
    let onSuccess: () -> Void
    let onError: (Error) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isLoading = false

    var body: some View {
        Button(action: signInWithGoogle) {
            HStack(spacing: ENVISpacing.md) {
                Image(systemName: "g.circle.fill")
                    .font(.system(size: 20, weight: .medium))

                Text(isLoading ? "Signing in..." : "Continue with Google")
                    .font(.interSemiBold(15))
            }
            .foregroundColor(ENVITheme.text(for: colorScheme))
            .frame(maxWidth: .infinity)
            .padding(.vertical, ENVISpacing.lg)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.lg)
                    .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
            )
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.6 : 1.0)
    }

    private func signInWithGoogle() {
        guard !isLoading else { return }
        isLoading = true

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            isLoading = false
            onError(AuthManager.AuthError.googleSignInFailed)
            return
        }

        // Find the topmost presented view controller
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        Task {
            do {
                _ = try await AuthManager.shared.signInWithGoogle(presenting: topVC)
                await MainActor.run {
                    isLoading = false
                    onSuccess()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    onError(error)
                }
            }
        }
    }
}

// MARK: - ENVI-0017 Forgot Password Sheet

/// Bottom sheet for password reset flow.
struct ForgotPasswordSheet: View {
    let onResetSent: () -> Void
    let colorScheme: ColorScheme

    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: ENVISpacing.xxl) {
            // Handle indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(ENVITheme.border(for: colorScheme))
                .frame(width: 36, height: 4)
                .padding(.top, ENVISpacing.md)

            VStack(spacing: ENVISpacing.sm) {
                Text("RESET PASSWORD")
                    .font(.spaceMonoBold(18))
                    .tracking(1.5)
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text("Enter your email and we'll send you a reset link.")
                    .font(.interRegular(14))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .multilineTextAlignment(.center)
            }

            TextField("you@email.com", text: $email)
                .font(.interRegular(15))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .padding(ENVISpacing.lg)
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)

            if let errorMessage {
                Text(errorMessage)
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.error)
            }

            Button(action: sendReset) {
                Text(isLoading ? "Sending..." : "Send Reset Link")
                    .font(.interSemiBold(15))
                    .foregroundColor(colorScheme == .dark ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ENVISpacing.lg)
                    .background(ENVITheme.text(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            }
            .disabled(email.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            .opacity(email.trimmingCharacters(in: .whitespaces).isEmpty || isLoading ? 0.5 : 1.0)

            Spacer()
        }
        .padding(.horizontal, ENVISpacing.xl)
        .background(ENVITheme.background(for: colorScheme))
    }

    private func sendReset() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                try await AuthManager.shared.sendPasswordReset(email: normalizedEmail)
                await MainActor.run {
                    isLoading = false
                    dismiss()
                    onResetSent()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Unable to send reset email. Please check your email and try again."
                }
            }
        }
    }
}
