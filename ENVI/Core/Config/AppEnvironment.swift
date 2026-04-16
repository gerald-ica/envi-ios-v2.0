import Foundation
import FirebaseCore

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
    static let oracleEnabledKey = "ENVI_ORACLE_ENABLED"

    // MARK: - API base URL

    static var apiBaseURL: URL {
        if let override = ProcessInfo.processInfo.environment[AppEnvironment.apiBaseURLKey],
           let url = URL(string: override),
           !override.isEmpty {
            return url
        }
        return AppEnvironment.current.defaultAPIBaseURL
    }

    static var isOracleEnabled: Bool {
        guard let value = ProcessInfo.processInfo.environment[oracleEnabledKey]?.lowercased() else {
            return false
        }
        return value == "1" || value == "true" || value == "yes"
    }

    // MARK: - Phase 06-05: connector environment

    /// Env key read from the app process environment (set via xcconfig /
    /// xcodebuild -environment). Mirrors `ENVI_CONNECTOR_ENV` in
    /// `functions/.env.staging`.
    static let connectorEnvKey = "ENVI_CONNECTOR_ENV"

    /// Optional override for the Cloud Functions base URL. Useful for
    /// pointing at a local emulator (`http://127.0.0.1:5001/...`) during
    /// Phase 7 integration tests.
    static let connectorFunctionsBaseURLKey = "ENVI_CONNECTOR_BASE_URL"

    /// Distinct from `AppEnvironment` on purpose — the app can run in a
    /// `dev`/`staging` build against either a sandbox or prod Cloud
    /// Functions deployment. We flip them independently.
    enum ConnectorEnvironment: String {
        case sandbox
        case prod
    }

    /// Current connector environment. Falls back to `.sandbox` when the
    /// env var is absent, empty, or malformed — matches the server-side
    /// default in `functions/src/lib/config.ts`.
    static var currentConnector: ConnectorEnvironment {
        guard let raw = ProcessInfo.processInfo.environment[connectorEnvKey]?.lowercased(),
              let env = ConnectorEnvironment(rawValue: raw) else {
            return .sandbox
        }
        return env
    }

    /// Base URL for the ENVI Cloud Functions broker. Resolution order:
    ///   1. `ENVI_CONNECTOR_BASE_URL` env override (emulator / tests).
    ///   2. Derived `https://<region>-<projectID>.cloudfunctions.net`
    ///      from the configured FirebaseApp instance.
    ///   3. A well-known staging default so DEBUG builds without Firebase
    ///      configured still resolve to _something_ addressable.
    static var connectorFunctionsBaseURL: URL {
        if let override = ProcessInfo.processInfo.environment[connectorFunctionsBaseURLKey],
           !override.isEmpty,
           let url = URL(string: override) {
            return url
        }

        let region = "us-central1"
        let projectID = firebaseProjectID
        if let url = URL(string: "https://\(region)-\(projectID).cloudfunctions.net") {
            return url
        }

        return URL(string: "https://us-central1-envi-by-informal-staging.cloudfunctions.net")!
    }

    /// Resolves Firebase project ID from the configured app; falls back to
    /// the known staging project id so preview/test code paths still work
    /// without a live Firebase config.
    private static var firebaseProjectID: String {
        FirebaseApp.app()?.options.projectID ?? "envi-by-informal-staging"
    }
}
