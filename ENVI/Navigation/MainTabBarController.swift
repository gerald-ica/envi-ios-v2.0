import UIKit
import SwiftUI

/// Custom tab bar controller with 5 tabs and a floating pill-shaped tab bar.
final class MainTabBarController: UIViewController {

    var onSignOut: (() -> Void)?

    private let customTabBar = ENVITabBar()
    private var viewControllers: [UIViewController] = []
    private(set) var currentIndex = 0
    private var trackedScrollViews: [UIScrollView] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ENVITheme.UIKit.background

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
        libraryVC.view.backgroundColor = ENVITheme.UIKit.background

        // Tab 3: Chat + Explore (SwiftUI)
        let chatExploreVC = UIHostingController(rootView: ChatExploreView())
        chatExploreVC.view.backgroundColor = ENVITheme.UIKit.background

        // Tab 4: Analytics (SwiftUI)
        let analyticsVC = UIHostingController(rootView: AnalyticsView())
        analyticsVC.view.backgroundColor = ENVITheme.UIKit.background

        // Tab 5: Profile (SwiftUI)
        let profileView = ProfileView(onSignOut: { [weak self] in
            self?.onSignOut?()
        })
        let profileVC = UIHostingController(rootView: profileView)
        profileVC.view.backgroundColor = ENVITheme.UIKit.background

        viewControllers = [feedNav, libraryVC, chatExploreVC, analyticsVC, profileVC]
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
        setTabBarVisible(true, animated: false)
        configureTabBarVisibilityHandling(for: newVC)
    }

    func setTabBarVisible(_ visible: Bool, animated: Bool = true) {
        customTabBar.setVisible(visible, animated: animated)
    }

    private func configureTabBarVisibilityHandling(for viewController: UIViewController) {
        clearTrackedScrollViews()

        let attachHandlers = { [weak self, weak viewController] in
            guard let self, let viewController else { return }
            let scrollViews = self.findScrollViews(in: viewController.view)
                .filter { $0.contentSize.height > $0.bounds.height + 40 }

            self.trackedScrollViews = scrollViews
            for scrollView in scrollViews {
                scrollView.panGestureRecognizer.removeTarget(self, action: #selector(self.handleTrackedScrollPan(_:)))
                scrollView.panGestureRecognizer.addTarget(self, action: #selector(self.handleTrackedScrollPan(_:)))
            }
        }

        DispatchQueue.main.async(execute: attachHandlers)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: attachHandlers)
    }

    private func clearTrackedScrollViews() {
        for scrollView in trackedScrollViews {
            scrollView.panGestureRecognizer.removeTarget(self, action: #selector(handleTrackedScrollPan(_:)))
        }
        trackedScrollViews.removeAll()
    }

    private func findScrollViews(in rootView: UIView) -> [UIScrollView] {
        var scrollViews: [UIScrollView] = []

        if let scrollView = rootView as? UIScrollView {
            scrollViews.append(scrollView)
        }

        for subview in rootView.subviews {
            scrollViews.append(contentsOf: findScrollViews(in: subview))
        }

        return scrollViews
    }

    @objc private func handleTrackedScrollPan(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard
            gestureRecognizer.state == .changed,
            let scrollView = gestureRecognizer.view as? UIScrollView
        else { return }

        let translation = gestureRecognizer.translation(in: scrollView)
        let isPrimarilyVertical = abs(translation.y) > abs(translation.x)
        guard isPrimarilyVertical else { return }

        let topOffset = -scrollView.adjustedContentInset.top
        let nearTop = scrollView.contentOffset.y <= topOffset + 20

        if nearTop || translation.y > 6 {
            setTabBarVisible(true, animated: true)
        } else if translation.y < -6 {
            setTabBarVisible(false, animated: true)
        }
    }
}
