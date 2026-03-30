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
        case userBirthTime
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

    var userDOB: String? {
        get { defaults.string(forKey: Key.userDOB.rawValue) }
        set { defaults.set(newValue, forKey: Key.userDOB.rawValue) }
    }

    var userBirthTime: String? {
        get { defaults.string(forKey: Key.userBirthTime.rawValue) }
        set { defaults.set(newValue, forKey: Key.userBirthTime.rawValue) }
    }

    var userLocation: String? {
        get { defaults.string(forKey: Key.userLocation.rawValue) }
        set { defaults.set(newValue, forKey: Key.userLocation.rawValue) }
    }

    var userBirthplace: String? {
        get { defaults.string(forKey: Key.userBirthplace.rawValue) }
        set { defaults.set(newValue, forKey: Key.userBirthplace.rawValue) }
    }

    var connectedPlatforms: [String] {
        get { defaults.stringArray(forKey: Key.connectedPlatforms.rawValue) ?? [] }
        set { defaults.set(newValue, forKey: Key.connectedPlatforms.rawValue) }
    }

    // MARK: - Reset (for testing)
    func resetAll() {
        let domain = Bundle.main.bundleIdentifier!
        defaults.removePersistentDomain(forName: domain)
    }
}
