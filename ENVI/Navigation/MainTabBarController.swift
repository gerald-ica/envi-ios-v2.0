import UIKit
import SwiftUI

/// Custom tab bar controller with 5 tabs and a floating pill-shaped tab bar.
final class MainTabBarController: UIViewController {

    var onSignOut: (() -> Void)?

    private let customTabBar = ENVITabBar()
    private var viewControllers: [UIViewController] = []
    private var currentIndex = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ENVITheme.UIKit.backgroundDark

        setupViewControllers()
        setupTabBar()
        showViewController(at: 0)
    }

    private func setupViewControllers() {
        // Tab 1: Feed (UIKit)
        let feedVC = FeedViewController()
        let feedNav = UINavigationController(rootViewController: feedVC)
        feedNav.setNavigationBarHidden(true, animated: false)

        // Tab 2: Library (SwiftUI)
        let libraryVC = UIHostingController(rootView: LibraryView())
        libraryVC.view.backgroundColor = ENVITheme.UIKit.backgroundDark

        // Tab 3: Chat (SwiftUI)
        let chatVC = UIHostingController(rootView: ChatView())
        chatVC.view.backgroundColor = ENVITheme.UIKit.backgroundDark

        // Tab 4: Analytics (SwiftUI)
        let analyticsVC = UIHostingController(rootView: AnalyticsView())
        analyticsVC.view.backgroundColor = ENVITheme.UIKit.backgroundDark

        // Tab 5: Profile (SwiftUI)
        let profileView = ProfileView(onSignOut: { [weak self] in
            self?.onSignOut?()
        })
        let profileVC = UIHostingController(rootView: profileView)
        profileVC.view.backgroundColor = ENVITheme.UIKit.backgroundDark

        viewControllers = [feedNav, libraryVC, chatVC, analyticsVC, profileVC]
    }

    private func setupTabBar() {
        customTabBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(customTabBar)

        NSLayoutConstraint.activate([
            customTabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            customTabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            customTabBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -4),
        ])

        customTabBar.onTabSelected = { [weak self] index in
            self?.showViewController(at: index)
        }
    }

    private func showViewController(at index: Int) {
        guard index < viewControllers.count else { return }

        // Remove current child
        if currentIndex < viewControllers.count {
            let current = viewControllers[currentIndex]
            current.willMove(toParent: nil)
            current.view.removeFromSuperview()
            current.removeFromParent()
        }

        // Add new child
        let newVC = viewControllers[index]
        addChild(newVC)
        newVC.view.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(newVC.view, belowSubview: customTabBar)

        NSLayoutConstraint.activate([
            newVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            newVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            newVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            newVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        newVC.didMove(toParent: self)

        currentIndex = index
        customTabBar.selectedIndex = index
    }
}
