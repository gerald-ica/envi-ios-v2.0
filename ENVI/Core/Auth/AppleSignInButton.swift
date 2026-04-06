import SwiftUI
import AuthenticationServices

struct AppleSignInButton: View {
    let onSuccess: (UserAuthPayload) -> Void
    let onError: (Error) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            let nonce = AuthManager.shared.generateNonce()
            request.requestedScopes = [.fullName, .email]
            request.nonce = AuthManager.shared.sha256(nonce)
        } onCompletion: { result in
            switch result {
            case .success(let auth):
                guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                    onError(AuthManager.AuthError.invalidCredential)
                    return
                }
                Task {
                    do {
                        let payload = try await AuthManager.shared.signInWithApple(credential: credential)
                        await MainActor.run { onSuccess(payload) }
                    } catch {
                        await MainActor.run { onError(error) }
                    }
                }
            case .failure(let error):
                onError(error)
            }
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: 50)
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
    }
}
