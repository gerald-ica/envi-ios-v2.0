import UIKit

final class FeedDetailViewController: UIViewController {

    private var item: ContentItem
    private let onBookmarkToggle: ((UUID) -> ContentItem?)?

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    private let cardView: ExpandableFeedCardView = {
        let cardView = ExpandableFeedCardView()
        cardView.translatesAutoresizingMaskIntoConstraints = false
        return cardView
    }()

    private let backButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "chevron.left")
        config.baseForegroundColor = ENVITheme.UIKit.text
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        let button = UIButton(configuration: config)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.42)
        button.layer.cornerRadius = 22
        button.layer.cornerCurve = .continuous
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    init(item: ContentItem, onBookmarkToggle: ((UUID) -> ContentItem?)? = nil) {
        self.item = item
        self.onBookmarkToggle = onBookmarkToggle
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ENVITheme.UIKit.background
        navigationController?.setNavigationBarHidden(true, animated: false)

        setupLayout()
        configureCard()
    }

    private func setupLayout() {
        view.addSubview(scrollView)
        view.addSubview(backButton)
        scrollView.addSubview(cardView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            cardView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            cardView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),
        ])

        backButton.addTarget(self, action: #selector(handleBackTap), for: .touchUpInside)
        backButton.accessibilityLabel = "Back to For You"
    }

    private func configureCard() {
        cardView.setPresentationMode(detail: true)
        cardView.configure(with: item, expanded: true)
        cardView.onEdit = { [weak self] in
            self?.openEditor()
        }
        cardView.onBookmark = { [weak self] in
            self?.toggleBookmark()
        }
        cardView.onToggleExpanded = nil
        cardView.onSwipeDecision = nil
    }

    private func openEditor() {
        let editor = EditorViewController(contentItem: item)
        navigationController?.pushViewController(editor, animated: true)
    }

    private func toggleBookmark() {
        guard let updatedItem = onBookmarkToggle?(item.id) else { return }
        item = updatedItem
        configureCard()
    }

    @objc private func handleBackTap() {
        dismiss(animated: true)
    }
}
