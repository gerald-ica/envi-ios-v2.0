import Foundation

enum AppEnvironment: String, CaseIterable {
    case dev
    case staging
    case prod

    static let envKey = "ENVI_APP_ENV"
    static let apiBaseURLKey = "ENVI_API_BASE_URL"

    static var current: AppEnvironment {
        if let raw = ProcessInfo.processInfo.environment[envKey]?.lowercased(),
           let value = AppEnvironment(rawValue: raw) {
            return value
        }

        #if DEBUG
        return .dev
        #else
        return .prod
        #endif
    }

    var defaultAPIBaseURL: URL {
        switch self {
        case .dev:
            return URL(string: "https://api-dev.envi.app/v1")!
        case .staging:
            return URL(string: "https://api-staging.envi.app/v1")!
        case .prod:
            return URL(string: "https://api.envi.app/v1")!
        }
    }
}

enum AppConfig {
    static var apiBaseURL: URL {
        if let override = ProcessInfo.processInfo.environment[AppEnvironment.apiBaseURLKey],
           let url = URL(string: override),
           !override.isEmpty {
            return url
        }
        return AppEnvironment.current.defaultAPIBaseURL
    }
}
