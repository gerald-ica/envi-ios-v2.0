import Foundation
import UIKit
import FirebaseCore
import FirebaseAuth
import AuthenticationServices
import CryptoKit
import GoogleSignIn

final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    // MARK: - Auth State Observation

    enum AuthState {
        case unknown
        case signedIn(uid: String)
        case signedOut
    }

    @Published private(set) var authState: AuthState = .unknown
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    // MARK: - Apple Sign-In

    private var currentNonce: String?

    enum AuthError: Error, LocalizedError {
        case firebaseNotConfigured
        case invalidCredential
        case googleSignInFailed
        case mfaEnrollmentFailed
        case mfaVerificationFailed
        case reauthenticationRequired
        case noCurrentUser

        var errorDescription: String? {
            switch self {
            case .firebaseNotConfigured: return "Firebase is not configured."
            case .invalidCredential: return "Invalid credential provided."
            case .googleSignInFailed: return "Google Sign-In failed."
            case .mfaEnrollmentFailed: return "MFA enrollment failed."
            case .mfaVerificationFailed: return "MFA verification failed."
            case .reauthenticationRequired: return "Please sign in again to continue."
            case .noCurrentUser: return "No signed-in user."
            }
        }
    }

    // MARK: - Init

    private init() {
        startAuthStateListener()
    }

    // MARK: - Auth State Listener

    func startAuthStateListener() {
        guard FirebaseApp.app() != nil else { return }
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            let uid = user?.uid
            Task {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.authState = uid.map { .signedIn(uid: $0) } ?? .signedOut
                }
            }
        }
    }

    // MARK: - Computed Properties

    var isSignedIn: Bool {
        guard FirebaseApp.app() != nil else { return false }
        return Auth.auth().currentUser != nil
    }

    var currentUserID: String? {
        guard FirebaseApp.app() != nil else { return nil }
        return Auth.auth().currentUser?.uid
    }

    // MARK: - Email / Password Auth

    @discardableResult
    func signIn(email: String, password: String) async throws -> UserAuthPayload {
        guard FirebaseApp.app() != nil else { throw AuthError.firebaseNotConfigured }
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        return UserAuthPayload(uid: result.user.uid, email: result.user.email)
    }

    @discardableResult
    func createAccount(email: String, password: String) async throws -> UserAuthPayload {
        guard FirebaseApp.app() != nil else { throw AuthError.firebaseNotConfigured }
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        return UserAuthPayload(uid: result.user.uid, email: result.user.email)
    }

    func signOut() throws {
        guard FirebaseApp.app() != nil else { throw AuthError.firebaseNotConfigured }
        try Auth.auth().signOut()
    }

    // MARK: - Apple Sign-In

    @discardableResult
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws -> UserAuthPayload {
        guard FirebaseApp.app() != nil else { throw AuthError.firebaseNotConfigured }
        guard let appleIDToken = credential.identityToken,
              let tokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.invalidCredential
        }
        let firebaseCredential = OAuthProvider.credential(
            providerID: AuthProviderID.apple,
            idToken: tokenString,
            rawNonce: currentNonce ?? ""
        )
        let result = try await Auth.auth().signIn(with: firebaseCredential)
        return UserAuthPayload(
            uid: result.user.uid,
            email: result.user.email,
            displayName: result.user.displayName
        )
    }

    // MARK: - Nonce Helpers

    func generateNonce() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return nonce
    }

    func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    // MARK: - ENVI-0004 Sign in with Google

    @discardableResult
    func signInWithGoogle(presenting viewController: UIViewController) async throws -> UserAuthPayload {
        guard FirebaseApp.app() != nil else { throw AuthError.firebaseNotConfigured }
        // NOTE: clientID comes from GoogleService-Info.plist CLIENT_ID field.
        // Google Sign-In must be enabled in Firebase Console for this to work.
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.googleSignInFailed
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.googleSignInFailed
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        let authResult = try await Auth.auth().signIn(with: credential)
        return UserAuthPayload(
            uid: authResult.user.uid,
            email: authResult.user.email,
            displayName: authResult.user.displayName
        )
    }

    // MARK: - ENVI-0009 Multi-Factor Authentication

    /// Enroll a phone number for SMS-based MFA.
    func enrollMFA(phoneNumber: String) async throws {
        guard FirebaseApp.app() != nil else { throw AuthError.firebaseNotConfigured }
        guard let user = Auth.auth().currentUser else { throw AuthError.noCurrentUser }

        let session = try await user.multiFactor.session()
        let verificationID = try await PhoneAuthProvider.provider().verifyPhoneNumber(
            phoneNumber,
            uiDelegate: nil,
            multiFactorSession: session
        )
        // Store verification ID for the verify step
        UserDefaults.standard.set(verificationID, forKey: "envi_mfa_verification_id")
    }

    /// Verify the MFA enrollment with the SMS code.
    func verifyMFA(code: String) async throws {
        guard FirebaseApp.app() != nil else { throw AuthError.firebaseNotConfigured }
        guard let user = Auth.auth().currentUser else { throw AuthError.noCurrentUser }
        guard let verificationID = UserDefaults.standard.string(forKey: "envi_mfa_verification_id") else {
            throw AuthError.mfaVerificationFailed
        }

        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: code
        )
        let assertion = PhoneMultiFactorGenerator.assertion(with: credential)
        try await user.multiFactor.enroll(with: assertion, displayName: "Phone")
        UserDefaults.standard.removeObject(forKey: "envi_mfa_verification_id")
    }

    // MARK: - ENVI-0007 Cross-Device Session Restore

    /// Check for existing Firebase Auth state on launch and restore session.
    func restoreSession() -> Bool {
        guard FirebaseApp.app() != nil else { return false }
        if let user = Auth.auth().currentUser {
            let uid = user.uid
            Task {
                await MainActor.run { [weak self] in
                    self?.authState = .signedIn(uid: uid)
                }
            }
            return true
        }
        Task {
            await MainActor.run { [weak self] in
                self?.authState = .signedOut
            }
        }
        return false
    }

    // MARK: - ENVI-0017 Account Recovery

    /// Send a password reset email.
    func sendPasswordReset(email: String) async throws {
        guard FirebaseApp.app() != nil else { throw AuthError.firebaseNotConfigured }
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    // MARK: - ENVI-0018 Delete Account

    /// Delete the current user account. Requires recent authentication.
    func deleteAccount() async throws {
        guard FirebaseApp.app() != nil else { throw AuthError.firebaseNotConfigured }
        guard let user = Auth.auth().currentUser else { throw AuthError.noCurrentUser }

        do {
            try await user.delete()
            Task {
                await MainActor.run { [weak self] in
                    self?.authState = .signedOut
                }
            }
        } catch let error as NSError {
            if error.code == AuthErrorCode.requiresRecentLogin.rawValue {
                throw AuthError.reauthenticationRequired
            }
            throw error
        }
    }
}

struct UserAuthPayload {
    let uid: String
    let email: String?
    let displayName: String?

    init(uid: String, email: String?, displayName: String? = nil) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
    }
}
