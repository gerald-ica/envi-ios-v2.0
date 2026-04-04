import Foundation
import FirebaseCore
import FirebaseAuth

final class AuthManager {
    static let shared = AuthManager()

    private init() {}

    enum AuthError: Error {
        case firebaseNotConfigured
    }

    var isSignedIn: Bool {
        guard FirebaseApp.app() != nil else { return false }
        Auth.auth().currentUser != nil
    }

    var currentUserID: String? {
        guard FirebaseApp.app() != nil else { return nil }
        Auth.auth().currentUser?.uid
    }

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
}

struct UserAuthPayload {
    let uid: String
    let email: String?
}
