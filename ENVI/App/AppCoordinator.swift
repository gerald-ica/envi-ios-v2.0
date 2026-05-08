import UIKit
import SwiftUI

/// Root coordinator that manages the app's navigation flow.
/// First-run flow: Splash → Onboarding → Main app
/// Signed-out flow: Splash → Sign In → Main app
@MainActor
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
    //
    // Sign-in-first flow (changed from onboarding-first 2026-05-08):
    //
    //   restored session ──► main app
    //   no session, finished onboarding ──► sign-in (returning user)
    //   no session, never onboarded ──► sign-in (new user can sign in OR
    //                                              tap Sign Up → onboarding)
    //
    // The previous design dropped first-time users straight into
    // onboarding and bootstrapped an anonymous Firebase identity in the
    // background. That meant the OAuth screen was effectively
    // unreachable for fresh installs in DEBUG (USM onboarding has no
    // social-sign-in step), and users who wanted to sign in had no way
    // to do so without first sending themselves through the full
    // onboarding flow. Flipping the gate to "is there a real user?"
    // instead of "have they been here before?" makes the OAuth screen
    // the canonical entry point.
    private func handlePostSplash() {
        if AuthManager.shared.restoreSession() {
            // ENVI-0007: cross-device session restore.
            syncPurchasesWithAuth()
            showMainApp()
        } else {
            showSignIn()
        }
    }

    // MARK: - Onboarding
    @MainActor
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
                guard let self else { return }
                self.syncPurchasesWithAuth()
                // After OAuth/email sign-in, route by whether the user
                // has ever finished onboarding. A fresh install signing
                // in for the first time still needs to capture USM
                // inputs; a returning user (e.g. cross-device) skips
                // straight to the main app.
                if UserDefaultsManager.shared.hasCompletedOnboarding {
                    self.showMainApp()
                } else {
                    self.showOnboarding()
                }
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
