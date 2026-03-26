import UIKit
import SwiftUI
import Combine

/// Main feed screen (UIKit) with top navigation bar and swipeable card stack.
final class FeedViewController: UIViewController {

    private let viewModel = FeedViewModel()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Top Nav
    private let topNavBar: UIView = {
        let v = UIView()
        v.backgroundColor = ENVITheme.UIKit.backgroundDark
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let logoLabel: UILabel = {
        let l = UILabel()
        l.text = "ENVI"
        l.font = .interBlack(22)
        l.textColor = .white
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let forYouButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("For You", for: .normal)
        b.titleLabel?.font = .interSemiBold(15)
        b.setTitleColor(.white, for: .normal)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let exploreButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Explore", for: .normal)
        b.titleLabel?.font = .interRegular(15)
        b.setTitleColor(UIColor.white.withAlphaComponent(0.55), for: .normal)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let searchButton: UIButton = {
        let b = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        b.setImage(UIImage(systemName: "magnifyingglass", withConfiguration: config), for: .normal)
        b.tintColor = .white
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let notificationButton: UIButton = {
        let b = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        b.setImage(UIImage(systemName: "bell", withConfiguration: config), for: .normal)
        b.tintColor = .white
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    // Active tab indicator
    private let tabIndicator: UIView = {
        let v = UIView()
        v.backgroundColor = ENVITheme.UIKit.primaryDark
        v.layer.cornerRadius = 1.5
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private var tabIndicatorCenterX: NSLayoutConstraint?

    // MARK: - Card Stack
    private let cardStack = SwipeableCardStack()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ENVITheme.UIKit.backgroundDark
        navigationController?.setNavigationBarHidden(true, animated: false)

        setupTopNav()
        setupCardStack()
        loadCards()
    }

    // MARK: - Setup Top Nav
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
            notificationButton.widthAnchor.constraint(equalToConstant: 36),
            notificationButton.heightAnchor.constraint(equalToConstant: 36),

            searchButton.trailingAnchor.constraint(equalTo: notificationButton.leadingAnchor, constant: -8),
            searchButton.centerYAnchor.constraint(equalTo: topNavBar.centerYAnchor),
            searchButton.widthAnchor.constraint(equalToConstant: 36),
            searchButton.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    // MARK: - Setup Card Stack
    private func setupCardStack() {
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardStack)

        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: topNavBar.bottomAnchor, constant: 12),
            cardStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            cardStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            cardStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -80),
        ])

        cardStack.onSwipeLeft = { [weak self] index in
            self?.viewModel.passCard()
        }
        cardStack.onSwipeRight = { [weak self] index in
            self?.viewModel.approveCard()
        }
    }

    // MARK: - Load Cards
    private func loadCards() {
        let cards: [UIView] = viewModel.remainingCards.prefix(3).map { item in
            if item.type == .textPost {
                let card = TextPostCardView()
                card.configure(with: item)
                card.onPass = { [weak self] in self?.viewModel.passCard() }
                card.onApprove = { [weak self] in self?.viewModel.approveCard() }
                return card
            } else {
                let card = ContentCardView()
                card.configure(with: item)
                return card
            }
        }
        cardStack.loadCards(cards)
    }

    // MARK: - Tab Switching
    @objc private func forYouTapped() {
        viewModel.selectedTab = .forYou
        forYouButton.titleLabel?.font = .interSemiBold(15)
        forYouButton.setTitleColor(.white, for: .normal)
        exploreButton.titleLabel?.font = .interRegular(15)
        exploreButton.setTitleColor(UIColor.white.withAlphaComponent(0.55), for: .normal)

        UIView.animate(withDuration: 0.25) {
            self.tabIndicatorCenterX?.isActive = false
            self.tabIndicatorCenterX = self.tabIndicator.centerXAnchor.constraint(equalTo: self.forYouButton.centerXAnchor)
            self.tabIndicatorCenterX?.isActive = true
            self.view.layoutIfNeeded()
        }
    }

    @objc private func exploreTapped() {
        viewModel.selectedTab = .explore
        exploreButton.titleLabel?.font = .interSemiBold(15)
        exploreButton.setTitleColor(.white, for: .normal)
        forYouButton.titleLabel?.font = .interRegular(15)
        forYouButton.setTitleColor(UIColor.white.withAlphaComponent(0.55), for: .normal)

        UIView.animate(withDuration: 0.25) {
            self.tabIndicatorCenterX?.isActive = false
            self.tabIndicatorCenterX = self.tabIndicator.centerXAnchor.constraint(equalTo: self.exploreButton.centerXAnchor)
            self.tabIndicatorCenterX?.isActive = true
            self.view.layoutIfNeeded()
        }
    }
}
