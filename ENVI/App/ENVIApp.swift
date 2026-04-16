import UIKit
import RevenueCat
import FirebaseCore
import GoogleSignIn

/// App entry point using UIKit app delegate.
/// Uses SceneDelegate for scene lifecycle management.
@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Register fonts at app launch
        ENVITypography.registerFonts()

        // Phase 06-07 — MUST come before FirebaseApp.configure() so the
        // App Check provider factory is in place before any Firebase
        // service initialises.
        AuthManager.configureAppCheck()

        // Configure Firebase SDK before any auth interaction.
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
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

    // MARK: - URL Handling (OAuth callback + Google Sign-In)
    //
    // Phase 06-04 — incoming `enviapp://oauth-callback/{provider}?...` URLs
    // are dispatched to `OAuthCallbackHandler.handle(_:)` first. Anything
    // that doesn't match the OAuth callback shape falls through to Google
    // Sign-In's existing handler. This mirrors the pattern a SwiftUI app
    // would express via `.onOpenURL { OAuthCallbackHandler.handle($0) }`.
    func application(_ app: UIApplication, open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        switch OAuthCallbackHandler.handle(url) {
        case .handled, .invalid:
            // `.handled` — payload parsed + posted via NotificationCenter.
            // `.invalid` — scheme matched but payload malformed; still
            // consume so we don't hand a partial OAuth URL to another SDK.
            return true
        case .unrelated:
            break
        }
        return GIDSignIn.sharedInstance.handle(url)
    }
}
