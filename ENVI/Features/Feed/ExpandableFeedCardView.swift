import UIKit
import SwiftUI

/// Scrollable feed card that expands in place to reveal more context and actions.
final class ExpandableFeedCardView: UIView, UIGestureRecognizerDelegate {

    enum SwipeDecision: Equatable {
        case approve
        case reject
    }

    var onToggleExpanded: (() -> Void)?
    var onEdit: (() -> Void)?
    var onBookmark: (() -> Void)?
    var onSwipeDecision: ((SwipeDecision) -> Void)?

    private var item: ContentItem?
    private let swipeThreshold: CGFloat = 96

    private let shellView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let mediaContainer = UIView()
    private let rejectOverlay = SwipeDecisionOverlayView(
        title: "PASS",
        systemImageName: "xmark",
        color: UIColor.systemRed
    )
    private let approveOverlay = SwipeDecisionOverlayView(
        title: "SAVE",
        systemImageName: "checkmark",
        color: UIColor.systemGreen
    )

    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let imageGradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.18).cgColor,
            UIColor.black.withAlphaComponent(0.82).cgColor
        ]
        layer.locations = [0.25, 0.62, 1.0]
        return layer
    }()

    private let mediaOverlay = UIView()
    private let mediaMetricsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .trailing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    private let confidencePill = OverlayMetricPill()
    private let bestTimePill = OverlayMetricPill()
    private let reachPill = OverlayMetricPill()

    private let mediaFooterRow: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .bottom
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let mediaInfoStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let mediaPlatformRow: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let mediaPlatformIconContainer: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 14
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let mediaPlatformIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let mediaPlatformLabel: UILabel = {
        let label = UILabel()
        label.font = .spaceMonoBold(11)
        label.textColor = UIColor.white.withAlphaComponent(0.88)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let mediaCaptionLabel: UILabel = {
        let label = UILabel()
        label.font = .interSemiBold(22)
        label.textColor = .white
        label.numberOfLines = 3
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let mediaBookmarkButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        button.setImage(UIImage(systemName: "bookmark", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let textPanel: UIView = {
        let view = UIView()
        view.backgroundColor = ENVITheme.UIKit.surfaceHighDark
        view.layer.cornerRadius = ENVIRadius.lg
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let textPanelPlatformLabel: UILabel = {
        let label = UILabel()
        label.font = .spaceMonoBold(10)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let textPanelTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .interSemiBold(20)
        label.textColor = .white
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let textPanelBodyLabel: UILabel = {
        let label = UILabel()
        label.font = .interRegular(16)
        label.textColor = UIColor.white.withAlphaComponent(0.88)
        label.numberOfLines = 5
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let destinationRow = UIStackView()
    private let destinationIconContainer: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 18
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let destinationIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let destinationTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .interSemiBold(15)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let destinationSubtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .interRegular(13)
        label.textColor = UIColor.white.withAlphaComponent(0.62)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let insightHostingController = UIHostingController(rootView: AIInsightRow(confidence: 0, bestTime: "", reach: ""))

    private let bookmarkButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        button.setImage(UIImage(systemName: "bookmark", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let detailContainer = UIView()
    private let detailStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let angleSection = FeedDetailSectionCard()
    private let insightSection = FeedDetailSectionCard()
    private let draftSection = FeedDetailSectionCard()
    private let statsGrid = UIStackView()

    private let editButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = .white
        config.baseForegroundColor = .black
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private var mediaHeightConstraint: NSLayoutConstraint?
    private var isCurrentItemExpandable = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageGradientLayer.frame = mediaContainer.bounds
    }

    func configure(with item: ContentItem, expanded: Bool) {
        self.item = item
        isCurrentItemExpandable = item.type != .textPost

        let platformColor = color(for: item.platform)
        let platformName = item.platform.rawValue
        let bodyText = item.bodyText ?? item.caption

        mediaPlatformIconContainer.backgroundColor = platformColor.withAlphaComponent(0.28)
        mediaPlatformIconView.image = UIImage(systemName: item.platform.iconName)
        mediaPlatformLabel.text = "PLANNED FOR \(platformName.uppercased())"
        mediaCaptionLabel.text = item.caption
        textPanelPlatformLabel.text = "PLANNED FOR \(platformName.uppercased())"
        textPanelTitleLabel.text = item.caption
        textPanelBodyLabel.text = bodyText
        textPanelBodyLabel.numberOfLines = 0

        destinationTitleLabel.text = "Posting to \(platformName)"
        destinationSubtitleLabel.text = postingDestinationText(for: item)
        destinationIconContainer.backgroundColor = platformColor.withAlphaComponent(0.16)
        destinationIconView.image = UIImage(systemName: item.platform.iconName)
        destinationIconView.tintColor = platformColor

        confidencePill.setText("\(Int(item.confidenceScore * 100))%")
        bestTimePill.setText(item.bestTime.uppercased())
        reachPill.setText(item.estimatedReach.uppercased())

        let bookmarkConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let bookmarkName = item.isBookmarked ? "bookmark.fill" : "bookmark"
        bookmarkButton.setImage(UIImage(systemName: bookmarkName, withConfiguration: bookmarkConfig), for: .normal)
        mediaBookmarkButton.setImage(UIImage(systemName: bookmarkName, withConfiguration: bookmarkConfig), for: .normal)

        insightHostingController.rootView = AIInsightRow(
            confidence: item.confidenceScore,
            bestTime: item.bestTime,
            reach: item.estimatedReach
        )

        angleSection.configure(
            title: "POST ANGLE",
            body: angleText(for: item)
        )
        insightSection.configure(
            title: "WHY ENVI LIKES IT",
            body: insightText(for: item)
        )
        draftSection.configure(
            title: draftSectionTitle(for: item),
            body: bodyText
        )

        rebuildStats(for: item)
        editButton.configuration?.title = editTitle(for: item)

        if item.type == .textPost {
            mediaContainer.isHidden = true
            textPanel.isHidden = false
            imageView.image = nil
            imageView.isHidden = true
            imageGradientLayer.isHidden = true
            mediaOverlay.isHidden = true
            mediaHeightConstraint?.constant = 0
        } else {
            mediaContainer.isHidden = false
            textPanel.isHidden = true
            imageView.image = loadImage(named: item.imageName)
            imageView.isHidden = false
            imageGradientLayer.isHidden = false
            mediaOverlay.isHidden = false
            mediaHeightConstraint?.constant = expanded ? 520 : 480
        }

        setExpanded(isCurrentItemExpandable ? expanded : false, animated: false)
    }

    func setExpanded(_ expanded: Bool, animated: Bool) {
        let shouldExpand = isCurrentItemExpandable && expanded
        detailContainer.isHidden = !shouldExpand
        destinationRow.isHidden = isCurrentItemExpandable ? !shouldExpand : false
        insightHostingController.view.isHidden = isCurrentItemExpandable ? !shouldExpand : false
        let animations = { self.layoutIfNeeded() }

        if animated {
            UIView.animate(
                withDuration: 0.28,
                delay: 0,
                options: [.curveEaseInOut, .allowUserInteraction],
                animations: animations
            )
        } else {
            animations()
        }
    }

    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(shellView)
        shellView.addSubview(contentStack)

        mediaContainer.translatesAutoresizingMaskIntoConstraints = false
        mediaContainer.clipsToBounds = true
        mediaContainer.layer.cornerRadius = ENVIRadius.lg
        mediaContainer.layer.cornerCurve = .continuous
        mediaContainer.addSubview(imageView)
        mediaContainer.layer.addSublayer(imageGradientLayer)
        mediaContainer.addSubview(rejectOverlay)
        mediaContainer.addSubview(approveOverlay)

        mediaOverlay.translatesAutoresizingMaskIntoConstraints = false
        mediaContainer.addSubview(mediaOverlay)
        mediaOverlay.addSubview(mediaMetricsStack)
        mediaOverlay.addSubview(mediaFooterRow)

        mediaMetricsStack.addArrangedSubview(confidencePill)
        mediaMetricsStack.addArrangedSubview(bestTimePill)
        mediaMetricsStack.addArrangedSubview(reachPill)

        mediaPlatformIconContainer.addSubview(mediaPlatformIconView)
        mediaPlatformRow.addArrangedSubview(mediaPlatformIconContainer)
        mediaPlatformRow.addArrangedSubview(mediaPlatformLabel)
        mediaInfoStack.addArrangedSubview(mediaPlatformRow)
        mediaInfoStack.addArrangedSubview(mediaCaptionLabel)

        mediaFooterRow.addArrangedSubview(mediaInfoStack)
        mediaFooterRow.addArrangedSubview(UIView())
        mediaFooterRow.addArrangedSubview(mediaBookmarkButton)
        mediaHeightConstraint = mediaContainer.heightAnchor.constraint(equalToConstant: 480)

        textPanel.addSubview(textPanelPlatformLabel)
        textPanel.addSubview(textPanelTitleLabel)
        textPanel.addSubview(textPanelBodyLabel)

        destinationRow.axis = .horizontal
        destinationRow.spacing = 10
        destinationRow.alignment = .center
        destinationRow.translatesAutoresizingMaskIntoConstraints = false

        let destinationTextStack = UIStackView(arrangedSubviews: [destinationTitleLabel, destinationSubtitleLabel])
        destinationTextStack.axis = .vertical
        destinationTextStack.spacing = 2
        destinationTextStack.translatesAutoresizingMaskIntoConstraints = false

        destinationIconContainer.addSubview(destinationIconView)
        destinationRow.addArrangedSubview(destinationIconContainer)
        destinationRow.addArrangedSubview(destinationTextStack)
        destinationRow.addArrangedSubview(UIView())
        destinationRow.addArrangedSubview(bookmarkButton)

        insightHostingController.view.backgroundColor = .clear
        insightHostingController.view.translatesAutoresizingMaskIntoConstraints = false

        detailContainer.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.isHidden = true
        detailContainer.addSubview(detailStack)

        statsGrid.axis = .vertical
        statsGrid.spacing = 8
        statsGrid.translatesAutoresizingMaskIntoConstraints = false

        detailStack.addArrangedSubview(angleSection)
        detailStack.addArrangedSubview(insightSection)
        detailStack.addArrangedSubview(draftSection)
        detailStack.addArrangedSubview(statsGrid)
        detailStack.addArrangedSubview(editButton)

        contentStack.addArrangedSubview(mediaContainer)
        contentStack.addArrangedSubview(textPanel)
        contentStack.addArrangedSubview(destinationRow)
        contentStack.addArrangedSubview(insightHostingController.view)
        contentStack.addArrangedSubview(detailContainer)

        contentStack.setCustomSpacing(14, after: mediaContainer)
        contentStack.setCustomSpacing(14, after: textPanel)
        contentStack.setCustomSpacing(14, after: destinationRow)
        contentStack.setCustomSpacing(14, after: insightHostingController.view)

        NSLayoutConstraint.activate([
            shellView.topAnchor.constraint(equalTo: topAnchor),
            shellView.leadingAnchor.constraint(equalTo: leadingAnchor),
            shellView.trailingAnchor.constraint(equalTo: trailingAnchor),
            shellView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: shellView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: shellView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: shellView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: shellView.bottomAnchor),

            mediaHeightConstraint!,
            imageView.topAnchor.constraint(equalTo: mediaContainer.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: mediaContainer.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: mediaContainer.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: mediaContainer.bottomAnchor),

            rejectOverlay.topAnchor.constraint(equalTo: mediaContainer.topAnchor),
            rejectOverlay.leadingAnchor.constraint(equalTo: mediaContainer.leadingAnchor),
            rejectOverlay.trailingAnchor.constraint(equalTo: mediaContainer.trailingAnchor),
            rejectOverlay.bottomAnchor.constraint(equalTo: mediaContainer.bottomAnchor),

            approveOverlay.topAnchor.constraint(equalTo: mediaContainer.topAnchor),
            approveOverlay.leadingAnchor.constraint(equalTo: mediaContainer.leadingAnchor),
            approveOverlay.trailingAnchor.constraint(equalTo: mediaContainer.trailingAnchor),
            approveOverlay.bottomAnchor.constraint(equalTo: mediaContainer.bottomAnchor),

            mediaOverlay.topAnchor.constraint(equalTo: mediaContainer.topAnchor),
            mediaOverlay.leadingAnchor.constraint(equalTo: mediaContainer.leadingAnchor),
            mediaOverlay.trailingAnchor.constraint(equalTo: mediaContainer.trailingAnchor),
            mediaOverlay.bottomAnchor.constraint(equalTo: mediaContainer.bottomAnchor),

            mediaMetricsStack.topAnchor.constraint(equalTo: mediaOverlay.topAnchor, constant: 16),
            mediaMetricsStack.trailingAnchor.constraint(equalTo: mediaOverlay.trailingAnchor, constant: -14),

            mediaFooterRow.leadingAnchor.constraint(equalTo: mediaOverlay.leadingAnchor, constant: 16),
            mediaFooterRow.trailingAnchor.constraint(equalTo: mediaOverlay.trailingAnchor, constant: -12),
            mediaFooterRow.bottomAnchor.constraint(equalTo: mediaOverlay.bottomAnchor, constant: -18),

            mediaPlatformIconContainer.widthAnchor.constraint(equalToConstant: 28),
            mediaPlatformIconContainer.heightAnchor.constraint(equalToConstant: 28),
            mediaPlatformIconView.centerXAnchor.constraint(equalTo: mediaPlatformIconContainer.centerXAnchor),
            mediaPlatformIconView.centerYAnchor.constraint(equalTo: mediaPlatformIconContainer.centerYAnchor),
            mediaPlatformIconView.widthAnchor.constraint(equalToConstant: 14),
            mediaPlatformIconView.heightAnchor.constraint(equalToConstant: 14),

            textPanelPlatformLabel.topAnchor.constraint(equalTo: textPanel.topAnchor, constant: 16),
            textPanelPlatformLabel.leadingAnchor.constraint(equalTo: textPanel.leadingAnchor, constant: 16),
            textPanelPlatformLabel.trailingAnchor.constraint(lessThanOrEqualTo: textPanel.trailingAnchor, constant: -16),

            textPanelTitleLabel.topAnchor.constraint(equalTo: textPanelPlatformLabel.bottomAnchor, constant: 12),
            textPanelTitleLabel.leadingAnchor.constraint(equalTo: textPanel.leadingAnchor, constant: 16),
            textPanelTitleLabel.trailingAnchor.constraint(equalTo: textPanel.trailingAnchor, constant: -16),

            textPanelBodyLabel.topAnchor.constraint(equalTo: textPanelTitleLabel.bottomAnchor, constant: 12),
            textPanelBodyLabel.leadingAnchor.constraint(equalTo: textPanel.leadingAnchor, constant: 16),
            textPanelBodyLabel.trailingAnchor.constraint(equalTo: textPanel.trailingAnchor, constant: -16),
            textPanelBodyLabel.bottomAnchor.constraint(equalTo: textPanel.bottomAnchor, constant: -16),

            destinationIconContainer.widthAnchor.constraint(equalToConstant: 36),
            destinationIconContainer.heightAnchor.constraint(equalToConstant: 36),
            destinationIconView.centerXAnchor.constraint(equalTo: destinationIconContainer.centerXAnchor),
            destinationIconView.centerYAnchor.constraint(equalTo: destinationIconContainer.centerYAnchor),
            destinationIconView.widthAnchor.constraint(equalToConstant: 16),
            destinationIconView.heightAnchor.constraint(equalToConstant: 16),

            mediaBookmarkButton.widthAnchor.constraint(equalToConstant: 32),
            mediaBookmarkButton.heightAnchor.constraint(equalToConstant: 32),

            bookmarkButton.widthAnchor.constraint(equalToConstant: 36),
            bookmarkButton.heightAnchor.constraint(equalToConstant: 36),

            detailStack.topAnchor.constraint(equalTo: detailContainer.topAnchor),
            detailStack.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor),
            detailStack.trailingAnchor.constraint(equalTo: detailContainer.trailingAnchor),
            detailStack.bottomAnchor.constraint(equalTo: detailContainer.bottomAnchor),

            insightHostingController.view.heightAnchor.constraint(greaterThanOrEqualToConstant: 24),
            editButton.heightAnchor.constraint(equalToConstant: 48),
        ])

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleCardTap))
        tapGesture.delegate = self
        addGestureRecognizer(tapGesture)

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleCardPan(_:)))
        panGesture.delegate = self
        addGestureRecognizer(panGesture)

        tapGesture.require(toFail: panGesture)

        bookmarkButton.addTarget(self, action: #selector(handleBookmarkTap), for: .touchUpInside)
        mediaBookmarkButton.addTarget(self, action: #selector(handleBookmarkTap), for: .touchUpInside)
        editButton.addTarget(self, action: #selector(handleEditTap), for: .touchUpInside)
    }

    private func rebuildStats(for item: ContentItem) {
        statsGrid.arrangedSubviews.forEach {
            statsGrid.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let rowOne = UIStackView(arrangedSubviews: [
            FeedStatChip(title: "BEST TIME", value: item.bestTime),
            FeedStatChip(title: "EST. REACH", value: item.estimatedReach)
        ])
        rowOne.axis = .horizontal
        rowOne.spacing = 8
        rowOne.distribution = .fillEqually

        let engagement = "\(item.likes) likes"
        let discussion = "\(item.comments) comments · \(item.shares) shares"
        let rowTwo = UIStackView(arrangedSubviews: [
            FeedStatChip(title: "ENGAGEMENT", value: engagement),
            FeedStatChip(title: "DISCUSSION", value: discussion)
        ])
        rowTwo.axis = .horizontal
        rowTwo.spacing = 8
        rowTwo.distribution = .fillEqually

        statsGrid.addArrangedSubview(rowOne)
        statsGrid.addArrangedSubview(rowTwo)
    }

    private func draftSectionTitle(for item: ContentItem) -> String {
        switch item.platform {
        case .x:
            return "TWEET DRAFT"
        case .threads:
            return "THREAD DRAFT"
        default:
            return item.type == .textPost ? "POST DRAFT" : "CAPTION DIRECTION"
        }
    }

    private func editTitle(for item: ContentItem) -> String {
        switch item.platform {
        case .x:
            return "Edit Tweet"
        case .threads:
            return "Edit Thread"
        default:
            return item.type == .textPost ? "Edit Post" : "Edit Further"
        }
    }

    private func postingDestinationText(for item: ContentItem) -> String {
        switch item.type {
        case .photo:
            return "\(item.platform.rawValue) photo concept"
        case .video:
            return "\(item.platform.rawValue) video concept"
        case .carousel:
            return "\(item.platform.rawValue) carousel concept"
        case .textPost:
            return "\(item.platform.rawValue) text concept"
        }
    }

    private func angleText(for item: ContentItem) -> String {
        switch item.type {
        case .photo:
            return "Lead with the strongest visual first, keep the copy concise, and let the image carry the emotional pull."
        case .video:
            return "Open with the most dynamic frame, then let the caption frame the story so the hook lands before the swipe."
        case .carousel:
            return "Structure this like a story arc: a cover that hooks, supporting slides that build curiosity, and a final slide that drives the save or share."
        case .textPost:
            return "Treat this like a point-of-view post: a strong first line, one clear opinion, and enough detail to invite replies."
        }
    }

    private func insightText(for item: ContentItem) -> String {
        let confidence = Int(item.confidenceScore * 100)
        return "ENVI is prioritizing this for \(item.platform.rawValue) because the format fits the platform well, the best posting window is \(item.bestTime), and the current forecast suggests about \(item.estimatedReach) in reach with a \(confidence)% confidence score."
    }

    private func color(for platform: SocialPlatform) -> UIColor {
        switch platform {
        case .instagram:
            return UIColor(red: 0.89, green: 0.25, blue: 0.37, alpha: 1)
        case .tiktok:
            return UIColor(red: 0.15, green: 0.94, blue: 0.90, alpha: 1)
        case .x:
            return UIColor.white
        case .threads:
            return UIColor.white
        case .linkedin:
            return UIColor(red: 0.04, green: 0.40, blue: 0.76, alpha: 1)
        case .youtube:
            return UIColor(red: 1.0, green: 0.23, blue: 0.19, alpha: 1)
        }
    }

    private func loadImage(named imageName: String?) -> UIImage? {
        guard let imageName else { return nil }
        if let image = UIImage(named: imageName) {
            return image
        }

        if let resourceBundle = Bundle.main.url(forResource: "ENVI_ENVI", withExtension: "bundle").flatMap(Bundle.init(url:)) {
            if let image = UIImage(named: imageName, in: resourceBundle, compatibleWith: nil) {
                return image
            }

            let bundledPath = resourceBundle.path(forResource: imageName, ofType: "jpg")
                ?? resourceBundle.path(forResource: imageName, ofType: "png")
            if let bundledPath {
                return UIImage(contentsOfFile: bundledPath)
            }
        }

        let resourcePath = Bundle.main.path(forResource: imageName, ofType: "jpg")
            ?? Bundle.main.path(forResource: imageName, ofType: "png")
        guard let resourcePath else { return nil }
        return UIImage(contentsOfFile: resourcePath)
    }

    @objc private func handleCardTap() {
        guard isCurrentItemExpandable else { return }
        onToggleExpanded?()
    }

    @objc private func handleCardPan(_ gestureRecognizer: UIPanGestureRecognizer) {
        let translation = gestureRecognizer.translation(in: self)
        let horizontalOffset = translation.x

        switch gestureRecognizer.state {
        case .changed:
            let rotation = (horizontalOffset / bounds.width) * 0.08
            transform = CGAffineTransform(translationX: horizontalOffset, y: 0).rotated(by: rotation)

            let approveAlpha = min(max(horizontalOffset / swipeThreshold, 0), 1) * 0.9
            let rejectAlpha = min(max(-horizontalOffset / swipeThreshold, 0), 1) * 0.9
            approveOverlay.alpha = approveAlpha
            rejectOverlay.alpha = rejectAlpha

        case .ended, .cancelled:
            let velocity = gestureRecognizer.velocity(in: self).x
            if horizontalOffset > swipeThreshold || velocity > 700 {
                animateCardOffscreen(for: .approve)
            } else if horizontalOffset < -swipeThreshold || velocity < -700 {
                animateCardOffscreen(for: .reject)
            } else {
                springBackIntoPlace()
            }

        default:
            break
        }
    }

    @objc private func handleEditTap() {
        onEdit?()
    }

    @objc private func handleBookmarkTap() {
        onBookmark?()
    }

    private func animateCardOffscreen(for decision: SwipeDecision) {
        let targetX = decision == .approve ? bounds.width * 1.3 : -bounds.width * 1.3
        let rotation: CGFloat = decision == .approve ? 0.16 : -0.16

        UIView.animate(withDuration: 0.28, delay: 0, options: [.curveEaseInOut]) {
            self.transform = CGAffineTransform(translationX: targetX, y: 0).rotated(by: rotation)
            self.alpha = 0
        } completion: { _ in
            self.onSwipeDecision?(decision)
            self.transform = .identity
            self.alpha = 1
            self.resetSwipeOverlays()
        }
    }

    private func springBackIntoPlace() {
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.72, initialSpringVelocity: 0.4) {
            self.transform = .identity
            self.resetSwipeOverlays()
        }
    }

    private func resetSwipeOverlays() {
        approveOverlay.alpha = 0
        rejectOverlay.alpha = 0
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var currentView = touch.view
        while let view = currentView {
            if view is UIButton {
                return false
            }
            currentView = view.superview
        }
        return true
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = panGesture.velocity(in: self)
        return abs(velocity.x) > abs(velocity.y)
    }
}

private final class OverlayMetricPill: PaddingLabel {
    override init(frame: CGRect) {
        super.init(frame: frame)
        font = .spaceMonoBold(11)
        textColor = .white
        backgroundColor = UIColor.white.withAlphaComponent(0.18)
        layer.cornerRadius = 8
        clipsToBounds = true
        contentInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) { fatalError() }

    func setText(_ text: String) {
        self.text = text
    }
}

private final class FeedStatChip: UIView {
    init(title: String, value: String) {
        super.init(frame: .zero)
        backgroundColor = ENVITheme.UIKit.surfaceHighDark
        layer.cornerRadius = ENVIRadius.md
        translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.font = .spaceMonoBold(10)
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.58)
        titleLabel.text = title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let valueLabel = UILabel()
        valueLabel.font = .interSemiBold(13)
        valueLabel.textColor = .white
        valueLabel.numberOfLines = 0
        valueLabel.text = value
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)
        addSubview(valueLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),

            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            valueLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}

private final class FeedDetailSectionCard: UIView {
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .spaceMonoBold(10)
        label.textColor = UIColor.white.withAlphaComponent(0.56)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let bodyLabel: UILabel = {
        let label = UILabel()
        label.font = .interRegular(14)
        label.textColor = UIColor.white.withAlphaComponent(0.86)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = ENVITheme.UIKit.surfaceHighDark
        layer.cornerRadius = ENVIRadius.md
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)
        addSubview(bodyLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            bodyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            bodyLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            bodyLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, body: String) {
        titleLabel.text = title
        bodyLabel.text = body
    }
}

private final class SwipeDecisionOverlayView: UIView {
    init(title: String, systemImageName: String, color: UIColor) {
        super.init(frame: .zero)
        alpha = 0
        backgroundColor = color.withAlphaComponent(0.22)
        translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: UIImage(systemName: systemImageName))
        iconView.tintColor = .white
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.font = .spaceMonoBold(16)
        label.textColor = .white
        label.text = title
        label.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [iconView, label])
        stack.axis = .horizontal
        stack.spacing = 10
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}

private class PaddingLabel: UILabel {
    var contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: contentInsets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + contentInsets.left + contentInsets.right,
            height: size.height + contentInsets.top + contentInsets.bottom
        )
    }
}
