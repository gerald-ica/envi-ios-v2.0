import UIKit
import SwiftUI

/// Root coordinator that manages the app's navigation flow.
/// Auth flow: Splash → Onboarding → Sign In
/// Main flow: MainTabBarController with 5 tabs
final class AppCoordinator: ParentCoordinator {
    var navigationController: UINavigationController
    var childCoordinators: [Coordinator] = []

    private var window: UIWindow?

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
        coordinator.onComplete = { [weak self] in
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
        hostingController.view.backgroundColor = ENVITheme.UIKit.backgroundDark
        navigationController.setViewControllers([hostingController], animated: true)
    }

    // MARK: - Main App
    private func showMainApp() {
        let tabBar = MainTabBarController()
        tabBar.onSignOut = { [weak self] in
            UserDefaultsManager.shared.resetAll()
            self?.showSplash()
        }
        navigationController.setViewControllers([tabBar], animated: true)
    }
}
