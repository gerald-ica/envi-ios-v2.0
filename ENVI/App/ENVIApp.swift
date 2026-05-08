import UIKit
import RevenueCat
import FirebaseCore
import GoogleSignIn
import os

private let appLaunchLogger = Logger(subsystem: "com.weareinformal.ENVI", category: "AppLaunch")

/// App entry point using UIKit app delegate.
/// Uses SceneDelegate for scene lifecycle management.
@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Fonts are auto-registered via Info.plist UIAppFonts — no programmatic registration needed.

        // Phase 06-07 — MUST come before FirebaseApp.configure() so the
        // App Check provider factory is in place before any Firebase
        // service initialises.
        AuthManager.configureAppCheck()

        // Configure Firebase SDK before any auth interaction.
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        // FirebaseApp.configure() returns silently when the bundle ID
        // doesn't match GoogleService-Info.plist — every Firebase call
        // afterwards no-ops. Surface the failure loudly so a config drift
        // can't masquerade as a "RevenueCat is broken" report.
        if FirebaseApp.app() == nil {
            let bundleID = Bundle.main.bundleIdentifier ?? "<unknown>"
            appLaunchLogger.error("FirebaseApp.configure() did not register a default app. Likely a bundle-ID mismatch with GoogleService-Info.plist. Running bundle: \(bundleID, privacy: .public)")
            #if DEBUG
            assertionFailure("Firebase failed to configure — see log above. Fix the bundle ID / GoogleService-Info.plist mismatch.")
            #endif
        }

        // Configure RevenueCat SDK
        PurchaseManager.shared.configure()

        // Baseline analytics heartbeat for app lifecycle.
        TelemetryManager.shared.track(.appLaunched)

        return true
    }

    // MARK: UISceneSession Lifecycle
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }

    func application(_ application: UIApplication,
                     didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {}

    // MARK: - URL Handling (OAuth callback + DeepLinkRouter + Google Sign-In)
    //
    // Scene-based URL delivery is handled in `SceneDelegate`. This shared
    // helper keeps the routing logic in one place for both cold-launch
    // `connectionOptions.urlContexts` and `scene(_:openURLContexts:)`.
    static func handleIncomingURL(_ url: URL) -> Bool {
        switch OAuthCallbackHandler.handle(url) {
        case .handled, .invalid:
            // `.handled` — payload parsed + posted via NotificationCenter.
            // `.invalid` — scheme matched but payload malformed; still
            // consume so we don't hand a partial OAuth URL to another SDK.
            return true
        case .unrelated:
            break
        }

        // Phase 15-03: router-aware destination URLs.
        if let destination = DeepLinkRouter.destination(from: url) {
            TelemetryManager.shared.track(.deepLinkRouted, parameters: [
                "destination": destination.id
            ])
            PendingDeepLinkStore.shared.dispatchOrStore(destination)
            return true
        }

        return GIDSignIn.sharedInstance.handle(url)
    }
}
