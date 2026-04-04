import Foundation
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics

final class TelemetryManager {
    static let shared = TelemetryManager()

    private init() {}

    enum Event: String {
        case appLaunched = "app_launched"
        case authSignInStarted = "auth_sign_in_started"
        case authSignInSucceeded = "auth_sign_in_succeeded"
        case authSignInFailed = "auth_sign_in_failed"
        case authSignedOut = "auth_signed_out"
    }

    func track(_ event: Event, parameters: [String: Any]? = nil) {
        guard FirebaseApp.app() != nil else { return }
        Analytics.logEvent(event.rawValue, parameters: parameters)
    }

    func record(error: Error, context: String) {
        guard FirebaseApp.app() != nil else { return }
        Crashlytics.crashlytics().setCustomValue(context, forKey: "context")
        Crashlytics.crashlytics().record(error: error)
    }
}
