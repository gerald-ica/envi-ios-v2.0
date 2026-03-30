import UIKit
import SwiftUI

/// UIKit card view for photo content with full-bleed image, gradient overlay,
/// creator info, caption, AI insight pills, and bookmark button.
final class ContentCardView: UIView {

    // MARK: - Subviews
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.8).cgColor]
        layer.locations = [0.4, 1.0]
        return layer
    }()

    private let creatorAvatarView: UIView = {
        let v = UIView()
        v.backgroundColor = ENVITheme.UIKit.surfaceHighDark
        v.layer.cornerRadius = 18
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let creatorInitialsLabel: UILabel = {
        let l = UILabel()
        l.font = .interBold(12)
        l.textColor = .white
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let creatorNameLabel: UILabel = {
        let l = UILabel()
        l.font = .interSemiBold(15)
        l.textColor = .white
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let creatorHandleLabel: UILabel = {
        let l = UILabel()
        l.font = .interRegular(13)
        l.textColor = UIColor.white.withAlphaComponent(0.7)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let captionLabel: UILabel = {
        let l = UILabel()
        l.font = .interRegular(14)
        l.textColor = .white
        l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let bookmarkButton: UIButton = {
        let b = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        b.setImage(UIImage(systemName: "bookmark", withConfiguration: config), for: .normal)
        b.tintColor = .white
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private var insightHostingController: UIHostingController<AIInsightRow>?

    // Swipe overlay
    let passOverlay: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.red.withAlphaComponent(0.3)
        v.alpha = 0
        let label = UILabel()
        label.text = "✕"
        label.font = .interBlack(60)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: v.centerYAnchor),
        ])
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    let approveOverlay: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.green.withAlphaComponent(0.3)
        v.alpha = 0
        let label = UILabel()
        label.text = "✓"
        label.font = .interBlack(60)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: v.centerYAnchor),
        ])
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    // MARK: - Setup
    private func setupUI() {
        layer.cornerRadius = ENVIRadius.xl
        clipsToBounds = true
        backgroundColor = ENVITheme.UIKit.surfaceLowDark

        addSubview(imageView)
        layer.addSublayer(gradientLayer)

        // Overlays
        addSubview(passOverlay)
        addSubview(approveOverlay)

        // Creator info stack
        addSubview(creatorAvatarView)
        creatorAvatarView.addSubview(creatorInitialsLabel)
        addSubview(creatorNameLabel)
        addSubview(creatorHandleLabel)
        addSubview(captionLabel)
        addSubview(bookmarkButton)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),

            passOverlay.topAnchor.constraint(equalTo: topAnchor),
            passOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            passOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            passOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),

            approveOverlay.topAnchor.constraint(equalTo: topAnchor),
            approveOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            approveOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            approveOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),

            // Creator avatar
            creatorAvatarView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            creatorAvatarView.bottomAnchor.constraint(equalTo: captionLabel.topAnchor, constant: -12),
            creatorAvatarView.widthAnchor.constraint(equalToConstant: 36),
            creatorAvatarView.heightAnchor.constraint(equalToConstant: 36),

            creatorInitialsLabel.centerXAnchor.constraint(equalTo: creatorAvatarView.centerXAnchor),
            creatorInitialsLabel.centerYAnchor.constraint(equalTo: creatorAvatarView.centerYAnchor),

            // Creator name
            creatorNameLabel.leadingAnchor.constraint(equalTo: creatorAvatarView.trailingAnchor, constant: 8),
            creatorNameLabel.topAnchor.constraint(equalTo: creatorAvatarView.topAnchor),

            // Creator handle
            creatorHandleLabel.leadingAnchor.constraint(equalTo: creatorNameLabel.leadingAnchor),
            creatorHandleLabel.topAnchor.constraint(equalTo: creatorNameLabel.bottomAnchor, constant: 2),

            // Caption
            captionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            captionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            captionLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),

            // Bookmark
            bookmarkButton.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            bookmarkButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            bookmarkButton.widthAnchor.constraint(equalToConstant: 44),
            bookmarkButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    // MARK: - Configure
    func configure(with item: ContentItem) {
        creatorNameLabel.text = item.creatorName
        creatorHandleLabel.text = item.creatorHandle
        captionLabel.text = item.caption

        let initials = item.creatorName.split(separator: " ")
            .compactMap { $0.first }
            .map(String.init)
            .joined()
        creatorInitialsLabel.text = String(initials.prefix(2))

        if let imageName = item.imageName {
            if let image = UIImage(named: imageName) {
                imageView.image = image
            } else {
                if let resourceBundle = Bundle.main.url(forResource: "ENVI_ENVI", withExtension: "bundle").flatMap(Bundle.init(url:)) {
                    if let image = UIImage(named: imageName, in: resourceBundle, compatibleWith: nil) {
                        imageView.image = image
                    } else {
                        let bundledPath = resourceBundle.path(forResource: imageName, ofType: "jpg")
                            ?? resourceBundle.path(forResource: imageName, ofType: "png")
                        if let bundledPath {
                            imageView.image = UIImage(contentsOfFile: bundledPath)
                        }
                    }
                } else {
                    let resourcePath = Bundle.main.path(forResource: imageName, ofType: "jpg")
                        ?? Bundle.main.path(forResource: imageName, ofType: "png")
                    if let path = resourcePath {
                        imageView.image = UIImage(contentsOfFile: path)
                    }
                }
            }
        }

        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let bookmarkIcon = "bookmark"  // Always outline per brand guidelines
        bookmarkButton.setImage(UIImage(systemName: bookmarkIcon, withConfiguration: config), for: .normal)

        // AI insight pills
        addInsightPills(item: item)
    }

    private func addInsightPills(item: ContentItem) {
        insightHostingController?.view.removeFromSuperview()

        let pillView = AIInsightRow(
            confidence: item.confidenceScore,
            bestTime: item.bestTime,
            reach: item.estimatedReach
        )
        let hosting = UIHostingController(rootView: pillView)
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hosting.view)

        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            hosting.view.trailingAnchor.constraint(equalTo: bookmarkButton.leadingAnchor, constant: -8),
        ])

        insightHostingController = hosting
    }
}
