import Foundation
import FirebaseCore
import FirebaseAuth
import AuthenticationServices
import CryptoKit

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

    enum AuthError: Error {
        case firebaseNotConfigured
        case invalidCredential
    }

    // MARK: - Init

    private init() {
        startAuthStateListener()
    }

    // MARK: - Auth State Listener

    func startAuthStateListener() {
        guard FirebaseApp.app() != nil else { return }
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                if let user {
                    self?.authState = .signedIn(uid: user.uid)
                } else {
                    self?.authState = .signedOut
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
