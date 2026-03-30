import UIKit

/// Main feed screen with a tappable "For You" feed.
final class FeedViewController: UIViewController, UIScrollViewDelegate {

    private let viewModel = FeedViewModel()
    private var cardViews: [UUID: ExpandableFeedCardView] = [:]
    private var hasAppliedDebugLaunchState = false
    private var mainTabBarController: MainTabBarController? {
        navigationController?.parent as? MainTabBarController
    }

    // MARK: - Top Nav
    private let topNavBar: UIView = {
        let view = UIView()
        view.backgroundColor = ENVITheme.UIKit.background
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let logoLabel: UILabel = {
        let label = UILabel()
        label.text = "ENVI"
        label.font = .spaceMonoBold(22)
        label.textColor = ENVITheme.UIKit.text
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let forYouButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("FOR YOU", for: .normal)
        button.titleLabel?.font = .spaceMonoBold(15)
        button.setTitleColor(ENVITheme.UIKit.text, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let exploreButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("EXPLORE", for: .normal)
        button.titleLabel?.font = .spaceMonoBold(15)
        button.setTitleColor(ENVITheme.UIKit.textSecondary, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let searchButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        button.setImage(UIImage(systemName: "magnifyingglass", withConfiguration: config), for: .normal)
        button.tintColor = ENVITheme.UIKit.text
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let notificationButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        button.setImage(UIImage(systemName: "bell", withConfiguration: config), for: .normal)
        button.tintColor = ENVITheme.UIKit.text
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let tabIndicator: UIView = {
        let view = UIView()
        view.backgroundColor = ENVITheme.UIKit.text
        view.layer.cornerRadius = 1.5
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var tabIndicatorCenterX: NSLayoutConstraint?

    // MARK: - Feed
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let sectionHeaderLabel: UILabel = {
        let label = UILabel()
        label.font = .interSemiBold(14)
        label.textColor = ENVITheme.UIKit.textSecondary
        label.numberOfLines = 0
        label.text = "Fresh concepts across your connected platforms."
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let explorePlaceholderView: UIView = {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 40, weight: .light)
        let iconView = UIImageView(image: UIImage(systemName: "compass", withConfiguration: iconConfig))
        iconView.tintColor = ENVITheme.UIKit.textSecondary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "COMING SOON"
        titleLabel.font = .spaceMonoBold(18)
        titleLabel.textColor = ENVITheme.UIKit.text
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Discover trending content and creators.\nWe're building something special."
        subtitleLabel.font = .interRegular(14)
        subtitleLabel.textColor = ENVITheme.UIKit.textSecondary
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 80),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -32),
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 300),
        ])

        return container
    }()

    private let searchBarView: UIView = {
        let container = UIView()
        container.backgroundColor = ENVITheme.UIKit.surfaceLow
        container.layer.cornerRadius = 12
        container.clipsToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let iconView = UIImageView(image: UIImage(systemName: "magnifyingglass", withConfiguration: iconConfig))
        iconView.tintColor = ENVITheme.UIKit.textSecondary
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let placeholderLabel = UILabel()
        placeholderLabel.text = "Search content, creators, tags..."
        placeholderLabel.font = .interRegular(15)
        placeholderLabel.textColor = ENVITheme.UIKit.textSecondary
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(iconView)
        container.addSubview(placeholderLabel)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 44),
            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            placeholderLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            placeholderLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -14),
        ])

        return container
    }()

    private let notificationsEmptyView: UIView = {
        let container = UIView()
        container.backgroundColor = ENVITheme.UIKit.surfaceLow
        container.layer.cornerRadius = 16
        container.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 32, weight: .light)
        let bellIcon = UIImageView(image: UIImage(systemName: "bell.slash", withConfiguration: iconConfig))
        bellIcon.tintColor = ENVITheme.UIKit.textSecondary
        bellIcon.contentMode = .scaleAspectFit
        bellIcon.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = "No notifications yet"
        label.font = .interSemiBold(15)
        label.textColor = ENVITheme.UIKit.textSecondary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = UILabel()
        subtitleLabel.text = "We'll let you know when something happens."
        subtitleLabel.font = .interRegular(13)
        subtitleLabel.textColor = ENVITheme.UIKit.textSecondary
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [bellIcon, label, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -24),
            container.heightAnchor.constraint(equalToConstant: 200),
        ])

        return container
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ENVITheme.UIKit.background
        navigationController?.setNavigationBarHidden(true, animated: false)

        setupTopNav()
        setupFeed()
        renderFeed()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        mainTabBarController?.setTabBarVisible(true, animated: true)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applyDebugLaunchStateIfNeeded()
    }

    private func setupTopNav() {
        view.addSubview(topNavBar)

        topNavBar.addSubview(logoLabel)
        topNavBar.addSubview(forYouButton)
        topNavBar.addSubview(exploreButton)
        topNavBar.addSubview(tabIndicator)
        topNavBar.addSubview(searchButton)
        topNavBar.addSubview(notificationButton)

        forYouButton.addTarget(self, action: #selector(forYouTapped), for: .touchUpInside)
        exploreButton.addTarget(self, action: #selector(exploreTapped), for: .touchUpInside)
        searchButton.addTarget(self, action: #selector(searchTapped), for: .touchUpInside)
        notificationButton.addTarget(self, action: #selector(notificationsTapped), for: .touchUpInside)

        forYouButton.accessibilityLabel = "For You"
        forYouButton.accessibilityHint = "Shows recommended content"
        exploreButton.accessibilityLabel = "Explore"
        exploreButton.accessibilityHint = "Shows explore content"
        searchButton.accessibilityLabel = "Search"
        searchButton.accessibilityHint = "Search content"
        notificationButton.accessibilityLabel = "Notifications"
        notificationButton.accessibilityHint = "Open notifications center"

        let tabIndicatorCenterX = tabIndicator.centerXAnchor.constraint(equalTo: forYouButton.centerXAnchor)
        self.tabIndicatorCenterX = tabIndicatorCenterX

        NSLayoutConstraint.activate([
            topNavBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topNavBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topNavBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topNavBar.heightAnchor.constraint(equalToConstant: 52),

            logoLabel.leadingAnchor.constraint(equalTo: topNavBar.leadingAnchor, constant: 20),
            logoLabel.centerYAnchor.constraint(equalTo: topNavBar.centerYAnchor),

            forYouButton.leadingAnchor.constraint(equalTo: logoLabel.trailingAnchor, constant: 24),
            forYouButton.centerYAnchor.constraint(equalTo: topNavBar.centerYAnchor),

            exploreButton.leadingAnchor.constraint(equalTo: forYouButton.trailingAnchor, constant: 16),
            exploreButton.centerYAnchor.constraint(equalTo: topNavBar.centerYAnchor),

            tabIndicator.bottomAnchor.constraint(equalTo: topNavBar.bottomAnchor),
            tabIndicator.heightAnchor.constraint(equalToConstant: 3),
            tabIndicator.widthAnchor.constraint(equalToConstant: 40),
            tabIndicatorCenterX,

            notificationButton.trailingAnchor.constraint(equalTo: topNavBar.trailingAnchor, constant: -20),
            notificationButton.centerYAnchor.constraint(equalTo: topNavBar.centerYAnchor),
            notificationButton.widthAnchor.constraint(equalToConstant: 44),
            notificationButton.heightAnchor.constraint(equalToConstant: 44),

            searchButton.trailingAnchor.constraint(equalTo: notificationButton.leadingAnchor, constant: -8),
            searchButton.centerYAnchor.constraint(equalTo: topNavBar.centerYAnchor),
            searchButton.widthAnchor.constraint(equalToConstant: 44),
            searchButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    private func setupFeed() {
        scrollView.delegate = self
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 120, right: 0)
        scrollView.verticalScrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topNavBar.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
        ])
    }

    private func renderFeed() {
        contentStack.arrangedSubviews.forEach {
            contentStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        cardViews.removeAll()

        switch viewModel.selectedTab {
        case .forYou:
            contentStack.addArrangedSubview(sectionHeaderLabel)

            for item in viewModel.visibleItems {
                let cardView = ExpandableFeedCardView()
                cardView.setPresentationMode(detail: false)
                cardView.configure(with: item, expanded: false)
                cardView.onToggleExpanded = { [weak self] in
                    self?.openDetail(for: item)
                }
                cardView.onEdit = { [weak self] in
                    self?.openEditor(for: item)
                }
                cardView.onBookmark = { [weak self] in
                    self?.toggleBookmark(for: item.id)
                }
                cardView.onSwipeDecision = { [weak self] decision in
                    self?.handleSwipe(decision, for: item.id)
                }
                cardViews[item.id] = cardView
                contentStack.addArrangedSubview(cardView)
            }
        case .explore:
            contentStack.addArrangedSubview(explorePlaceholderView)
        }
        // TODO: Optimize renderFeed for incremental updates — currently removes
        // and re-creates all card views on every call. Switch to diffable data
        // source or UICollectionView with DiffableDataSource to only insert/remove
        // changed items and avoid unnecessary view recycling.
    }

    private func toggleBookmark(for id: UUID) {
        viewModel.bookmarkCard(id: id)
        refreshCard(for: id)
    }

    private func refreshCard(for id: UUID) {
        guard
            let item = viewModel.visibleItems.first(where: { $0.id == id }),
            let cardView = cardViews[id]
        else { return }
        cardView.setPresentationMode(detail: false)
        cardView.configure(with: item, expanded: false)
    }

    private func openDetail(for item: ContentItem) {
        let detail = FeedDetailViewController(
            item: item,
            onBookmarkToggle: { [weak self] id in
                self?.viewModel.bookmarkCard(id: id)
                self?.refreshCard(for: id)
                return self?.viewModel.visibleItems.first(where: { $0.id == id })
            }
        )
        let detailNavigationController = UINavigationController(rootViewController: detail)
        detailNavigationController.setNavigationBarHidden(true, animated: false)
        detailNavigationController.modalPresentationStyle = .fullScreen
        detailNavigationController.modalTransitionStyle = .crossDissolve
        present(detailNavigationController, animated: true)
    }

    private func openEditor(for item: ContentItem) {
        mainTabBarController?.setTabBarVisible(false, animated: true)
        let editor = EditorViewController(contentItem: item)
        navigationController?.pushViewController(editor, animated: true)
    }

    private func handleSwipe(_ decision: ExpandableFeedCardView.SwipeDecision, for id: UUID) {
        guard let item = viewModel.visibleItems.first(where: { $0.id == id }) else { return }

        if decision == .approve {
            ApprovedMediaLibraryStore.shared.approve(item)
        }

        viewModel.removeCard(id: id)
        renderFeed()
        mainTabBarController?.setTabBarVisible(true, animated: true)
    }

    @objc private func forYouTapped() {
        guard viewModel.selectedTab != .forYou else { return }
        viewModel.selectedTab = .forYou
        updateTabSelection(animated: true)
        renderFeed()
    }

    @objc private func exploreTapped() {
        guard viewModel.selectedTab != .explore else { return }
        viewModel.selectedTab = .explore
        updateTabSelection(animated: true)
        renderFeed()
    }

    @objc private func searchTapped() {
        let searchVC = UIViewController()
        searchVC.view.backgroundColor = ENVITheme.UIKit.background

        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = ENVITheme.UIKit.text
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addAction(UIAction { _ in searchVC.dismiss(animated: true) }, for: .touchUpInside)

        searchVC.view.addSubview(searchBarView)
        searchVC.view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            searchBarView.topAnchor.constraint(equalTo: searchVC.view.safeAreaLayoutGuide.topAnchor, constant: 16),
            searchBarView.leadingAnchor.constraint(equalTo: searchVC.view.leadingAnchor, constant: 16),
            searchBarView.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -12),
            closeButton.centerYAnchor.constraint(equalTo: searchBarView.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: searchVC.view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
        ])

        searchVC.modalPresentationStyle = .pageSheet
        if let sheet = searchVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(searchVC, animated: true)
    }

    @objc private func notificationsTapped() {
        let notifVC = UIViewController()
        notifVC.view.backgroundColor = ENVITheme.UIKit.background

        let titleLabel = UILabel()
        titleLabel.text = "NOTIFICATIONS"
        titleLabel.font = .spaceMonoBold(18)
        titleLabel.textColor = ENVITheme.UIKit.text
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        notifVC.view.addSubview(titleLabel)
        notifVC.view.addSubview(notificationsEmptyView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: notifVC.view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: notifVC.view.centerXAnchor),
            notificationsEmptyView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 40),
            notificationsEmptyView.leadingAnchor.constraint(equalTo: notifVC.view.leadingAnchor, constant: 24),
            notificationsEmptyView.trailingAnchor.constraint(equalTo: notifVC.view.trailingAnchor, constant: -24),
        ])

        notifVC.modalPresentationStyle = .pageSheet
        if let sheet = notifVC.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        present(notifVC, animated: true)
    }

    private func updateTabSelection(animated: Bool) {
        let selectedButton = viewModel.selectedTab == .forYou ? forYouButton : exploreButton
        let deselectedButton = viewModel.selectedTab == .forYou ? exploreButton : forYouButton

        selectedButton.setTitleColor(ENVITheme.UIKit.text, for: .normal)
        deselectedButton.setTitleColor(ENVITheme.UIKit.textSecondary, for: .normal)

        let updates = {
            self.tabIndicatorCenterX?.isActive = false
            self.tabIndicatorCenterX = self.tabIndicator.centerXAnchor.constraint(equalTo: selectedButton.centerXAnchor)
            self.tabIndicatorCenterX?.isActive = true
            self.view.layoutIfNeeded()
        }

        if animated {
            UIView.animate(withDuration: 0.25, animations: updates)
        } else {
            updates()
        }
    }

    private func applyDebugLaunchStateIfNeeded() {
        #if DEBUG
        guard !hasAppliedDebugLaunchState else { return }
        guard ProcessInfo.processInfo.arguments.contains("UITestOpenFeedDetail") else { return }
        guard let firstMediaItem = viewModel.visibleItems.first(where: { $0.type != .textPost }) else { return }
        hasAppliedDebugLaunchState = true
        openDetail(for: firstMediaItem)
        #endif
    }
}
