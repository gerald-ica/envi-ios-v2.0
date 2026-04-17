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
        if !UserDefaultsManager.shared.hasCompletedOnboarding {
            showOnboarding()
        } else if AuthManager.shared.restoreSession() {
            // ENVI-0007: Cross-device session restore — rehydrate Firebase Auth state
            syncPurchasesWithAuth()
            showMainApp()
        } else {
            showSignIn()
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
                self?.syncPurchasesWithAuth()
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
            try? AuthManager.shared.signOut()
            Task { await PurchaseManager.shared.logOut() }
            TelemetryManager.shared.track(.authSignedOut)
            // Phase 15-03: drop any stashed deep link on sign-out so
            // it doesn't fire after the next sign-in lands in a
            // different session.
            Task { @MainActor in PendingDeepLinkStore.shared.reset() }
            self?.showSignIn()
        }
        navigationController.setViewControllers([tabBar], animated: true)
        // Phase 15-03: main tab bar is now on screen — replay any
        // deep link that arrived while we were on Splash/SignIn.
        Task { @MainActor in PendingDeepLinkStore.shared.markMainAppReady() }
    }

    private func syncPurchasesWithAuth() {
        guard let userID = AuthManager.shared.currentUserID else { return }
        Task { await PurchaseManager.shared.logIn(appUserID: userID) }
    }
}
