import UIKit

/// UIKit scene delegate that bootstraps the app coordinator.
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    var appCoordinator: AppCoordinator?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)
        self.window = window

        // Dark mode default
        window.overrideUserInterfaceStyle = .dark

        // Start coordinator
        let coordinator = AppCoordinator(window: window)
        self.appCoordinator = coordinator
        coordinator.start()
    }

    func sceneDidDisconnect(_ scene: UIScene) {}

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Resume any paused work when the app becomes active
        appCoordinator?.resumeActiveWork()
    }

    func sceneWillResignActive(_ scene: UIScene) {}

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Refresh data when returning to the foreground
        appCoordinator?.refreshData()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Save critical state to UserDefaults
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastBackgroundTimestamp")
        if let selectedTab = appCoordinator?.selectedTabIndex {
            UserDefaults.standard.set(selectedTab, forKey: "selectedTabIndex")
        }
        UserDefaults.standard.synchronize()
    }

    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        let activity = NSUserActivity(activityType: "com.envi.stateRestoration")
        activity.userInfo = [
            "selectedTabIndex": appCoordinator?.selectedTabIndex ?? 0
        ]
        return activity
    }

    // MARK: - Deep Link Handling

    /// Handle URL scheme deep links (e.g., envi://path)
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        handleDeepLink(url)
    }

    // TODO: Add universal link handling via associated domains.
    // Configure apple-app-site-association on the server and add
    // Associated Domains capability (applinks:yourdomain.com).

    /// Handle universal links via NSUserActivity
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else { return }
        handleDeepLink(url)
    }

    // MARK: - Private

    private func handleDeepLink(_ url: URL) {
        // Route deep links to the app coordinator for navigation
        // Example paths: envi://post/123, envi://profile/username
        print("[DeepLink] Received URL: \(url)")
        // appCoordinator?.handleDeepLink(url)
    }
}
