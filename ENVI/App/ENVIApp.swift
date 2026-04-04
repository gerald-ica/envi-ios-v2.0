import UIKit
import RevenueCat
import FirebaseCore

/// App entry point using UIKit app delegate.
/// Uses SceneDelegate for scene lifecycle management.
@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Register fonts at app launch
        ENVITypography.registerFonts()

        // Configure Firebase SDK before any auth interaction.
        if FirebaseApp.app() == nil {
            if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
               let options = FirebaseOptions(contentsOfFile: path) {
                FirebaseApp.configure(options: options)
            } else {
                print("Firebase not configured: missing GoogleService-Info.plist")
            }
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
}
