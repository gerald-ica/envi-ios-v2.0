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
        view.backgroundColor = ENVITheme.UIKit.backgroundDark
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let logoLabel: UILabel = {
        let label = UILabel()
        label.text = "ENVI"
        label.font = .spaceMonoBold(22)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let forYouButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("FOR YOU", for: .normal)
        button.titleLabel?.font = .spaceMonoBold(15)
        button.setTitleColor(.white, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let exploreButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("EXPLORE", for: .normal)
        button.titleLabel?.font = .spaceMonoBold(15)
        button.setTitleColor(UIColor.white.withAlphaComponent(0.5), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let searchButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        button.setImage(UIImage(systemName: "magnifyingglass", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let notificationButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        button.setImage(UIImage(systemName: "bell", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let tabIndicator: UIView = {
        let view = UIView()
        view.backgroundColor = .white
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
        label.textColor = UIColor.white.withAlphaComponent(0.72)
        label.numberOfLines = 0
        label.text = "Fresh concepts across your connected platforms."
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let explorePlaceholderLabel: UILabel = {
        let label = UILabel()
        label.font = .interRegular(15)
        label.textColor = UIColor.white.withAlphaComponent(0.72)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = "Explore is coming next. For now, your For You feed is fully interactive."
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ENVITheme.UIKit.backgroundDark
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
            contentStack.addArrangedSubview(explorePlaceholderLabel)
        }
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
        guard item.type != .textPost else { return }
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
        presentPlaceholderAlert(title: "Search", message: "Global search is the next feed flow to wire up.")
    }

    @objc private func notificationsTapped() {
        presentPlaceholderAlert(title: "Notifications", message: "Notifications center is not wired yet.")
    }

    private func presentPlaceholderAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func updateTabSelection(animated: Bool) {
        let selectedButton = viewModel.selectedTab == .forYou ? forYouButton : exploreButton
        let deselectedButton = viewModel.selectedTab == .forYou ? exploreButton : forYouButton

        selectedButton.setTitleColor(.white, for: .normal)
        deselectedButton.setTitleColor(UIColor.white.withAlphaComponent(0.5), for: .normal)

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
