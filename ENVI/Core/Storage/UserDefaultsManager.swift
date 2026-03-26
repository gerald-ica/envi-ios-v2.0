import Foundation

/// Manages persistent user preferences via UserDefaults.
final class UserDefaultsManager {
    static let shared = UserDefaultsManager()
    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Keys
    private enum Key: String {
        case hasCompletedOnboarding
        case userName
        case userDOB
        case userLocation
        case userBirthplace
        case connectedPlatforms
        case appearanceMode
    }

    // MARK: - Onboarding
    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Key.hasCompletedOnboarding.rawValue) }
        set { defaults.set(newValue, forKey: Key.hasCompletedOnboarding.rawValue) }
    }

    var userName: String? {
        get { defaults.string(forKey: Key.userName.rawValue) }
        set { defaults.set(newValue, forKey: Key.userName.rawValue) }
    }

    // MARK: - Reset (for testing)
    func resetAll() {
        let domain = Bundle.main.bundleIdentifier!
        defaults.removePersistentDomain(forName: domain)
    }
}
