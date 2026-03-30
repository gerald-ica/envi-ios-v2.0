import UIKit
import SwiftUI

/// Root coordinator that manages the app's navigation flow.
/// First-run flow: Splash → Onboarding → Main app
/// Signed-out flow: Splash → Sign In → Main app
final class AppCoordinator: ParentCoordinator {
    var navigationController: UINavigationController
    var childCoordinators: [Coordinator] = []

    private var window: UIWindow?
    private var onboardingCoordinator: OnboardingCoordinator?

    init(window: UIWindow?) {
        self.window = window
        self.navigationController = UINavigationController()
        self.navigationController.setNavigationBarHidden(true, animated: false)
    }

    func start() {
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()

        showSplash()
    }

    // MARK: - Splash
    private func showSplash() {
        let splash = SplashViewController()
        splash.onComplete = { [weak self] in
            self?.handlePostSplash()
        }
        navigationController.setViewControllers([splash], animated: false)
    }

    // MARK: - Post-Splash Routing
    private func handlePostSplash() {
        if UserDefaultsManager.shared.hasCompletedOnboarding {
            showMainApp()
        } else {
            showOnboarding()
        }
    }

    // MARK: - Onboarding
    private func showOnboarding() {
        let coordinator = OnboardingCoordinator(navigationController: navigationController)
        onboardingCoordinator = coordinator
        coordinator.onComplete = { [weak self, weak coordinator] in
            if self?.onboardingCoordinator === coordinator {
                self?.onboardingCoordinator = nil
            }
            self?.showMainApp()
        }
        coordinator.start()
    }

    // MARK: - Sign In
    private func showSignIn() {
        let signInView = SignInView(
            onSignIn: { [weak self] in
                self?.showMainApp()
            },
            onCreateAccount: { [weak self] in
                self?.showOnboarding()
            }
        )
        let hostingController = UIHostingController(rootView: signInView)
        hostingController.view.backgroundColor = ENVITheme.UIKit.background
        navigationController.setViewControllers([hostingController], animated: true)
    }

    // MARK: - Main App
    private func showMainApp() {
        let tabBar = MainTabBarController()
        tabBar.onSignOut = { [weak self] in
            UserDefaultsManager.shared.resetAll()
            self?.showSignIn()
        }
        navigationController.setViewControllers([tabBar], animated: true)
    }

    // MARK: - Scene Lifecycle Helpers

    /// The currently selected tab index, if the main tab bar is visible.
    var selectedTabIndex: Int? {
        guard let tabBar = navigationController.viewControllers.first as? MainTabBarController else {
            return nil
        }
        return tabBar.selectedIndex
    }

    /// Called when the scene enters the foreground — refresh visible data.
    func refreshData() {
        NotificationCenter.default.post(name: .enviAppDidEnterForeground, object: nil)
    }

    /// Called when the scene becomes active — resume any paused work.
    func resumeActiveWork() {
        NotificationCenter.default.post(name: .enviAppDidBecomeActive, object: nil)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let enviAppDidEnterForeground = Notification.Name("enviAppDidEnterForeground")
    static let enviAppDidBecomeActive = Notification.Name("enviAppDidBecomeActive")
}
