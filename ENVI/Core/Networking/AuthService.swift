import Foundation

/// Authentication service for managing user sessions.
/// Currently provides a mock implementation; replace with real Firebase/Auth0/custom auth.
actor AuthService {
    static let shared = AuthService()

    @Published private(set) var isAuthenticated = false
    private(set) var currentUserId: String?

    private let keychain = KeychainHelper.shared

    private init() {}

    // MARK: - Sign In
    func signIn(email: String, password: String) async throws -> User {
        // TODO: Replace with real auth provider (Firebase, Auth0, etc.)
        // For now, simulate successful sign-in
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay

        let token = "mock_token_\(UUID().uuidString)"
        try keychain.save(token, forKey: "auth_token")
        await APIClient.shared.setAuthToken(token)

        currentUserId = User.mock.id.uuidString
        isAuthenticated = true
        return User.mock
    }

    // MARK: - Sign Out
    func signOut() {
        try? keychain.delete(forKey: "auth_token")
        Task { await APIClient.shared.setAuthToken(nil) }
        currentUserId = nil
        isAuthenticated = false
    }

    // MARK: - Restore Session
    func restoreSession() async -> Bool {
        guard let token = try? keychain.read(forKey: "auth_token") else {
            return false
        }
        await APIClient.shared.setAuthToken(token)
        isAuthenticated = true
        return true
    }
}

// MARK: - Simple Keychain Helper
final class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}

    func save(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: "KeychainError", code: Int(status))
        }
    }

    func read(forKey key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
