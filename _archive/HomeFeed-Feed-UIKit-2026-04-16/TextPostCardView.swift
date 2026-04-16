import UIKit

/// UIKit card view for text-only posts with avatar, name, handle,
/// platform badge, body text, and pass/approve buttons.
final class TextPostCardView: UIView {

    // MARK: - Subviews
    private let avatarView: UIView = {
        let v = UIView()
        v.backgroundColor = ENVITheme.UIKit.surfaceHighDark
        v.layer.cornerRadius = 24
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let avatarLabel: UILabel = {
        let l = UILabel()
        l.font = .interBold(16)
        l.textColor = .white
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = .interSemiBold(17)
        l.textColor = .white
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let handleLabel: UILabel = {
        let l = UILabel()
        l.font = .interRegular(13)
        l.textColor = UIColor.white.withAlphaComponent(0.7)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let platformBadge: UILabel = {
        let l = UILabel()
        l.font = .spaceMonoBold(10)
        l.textColor = .white
        l.backgroundColor = ENVITheme.UIKit.surfaceHighDark
        l.textAlignment = .center
        l.layer.cornerRadius = 4
        l.clipsToBounds = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let bodyLabel: UILabel = {
        let l = UILabel()
        l.font = .interRegular(15)
        l.textColor = .white
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let passButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("PASS", for: .normal)
        b.titleLabel?.font = .spaceMonoBold(13)
        b.setTitleColor(.white.withAlphaComponent(0.7), for: .normal)
        b.backgroundColor = ENVITheme.UIKit.surfaceHighDark
        b.layer.cornerRadius = ENVIRadius.lg
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let approveButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("APPROVE", for: .normal)
        b.titleLabel?.font = .spaceMonoBold(13)
        b.setTitleColor(.black, for: .normal)
        b.backgroundColor = .white
        b.layer.cornerRadius = ENVIRadius.lg
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    // Swipe overlays
    let passOverlay: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.red.withAlphaComponent(0.3)
        v.alpha = 0
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    let approveOverlay: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.green.withAlphaComponent(0.3)
        v.alpha = 0
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    var onPass: (() -> Void)?
    var onApprove: (() -> Void)?

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup
    private func setupUI() {
        layer.cornerRadius = ENVIRadius.xl
        clipsToBounds = true
        backgroundColor = ENVITheme.UIKit.surfaceLowDark

        addSubview(avatarView)
        avatarView.addSubview(avatarLabel)
        addSubview(nameLabel)
        addSubview(handleLabel)
        addSubview(platformBadge)
        addSubview(bodyLabel)
        addSubview(passButton)
        addSubview(approveButton)
        addSubview(passOverlay)
        addSubview(approveOverlay)

        passButton.addTarget(self, action: #selector(passTapped), for: .touchUpInside)
        approveButton.addTarget(self, action: #selector(approveTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            // Avatar
            avatarView.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            avatarView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            avatarView.widthAnchor.constraint(equalToConstant: 48),
            avatarView.heightAnchor.constraint(equalToConstant: 48),
            avatarLabel.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),

            // Name
            nameLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: avatarView.topAnchor, constant: 2),

            // Handle
            handleLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            handleLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),

            // Platform badge
            platformBadge.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),
            platformBadge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            platformBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 32),
            platformBadge.heightAnchor.constraint(equalToConstant: 22),

            // Body
            bodyLabel.topAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 20),
            bodyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            bodyLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            // Buttons
            passButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            passButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24),
            passButton.heightAnchor.constraint(equalToConstant: 44),
            passButton.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.38),

            approveButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            approveButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24),
            approveButton.heightAnchor.constraint(equalToConstant: 44),
            approveButton.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.38),

            // Overlays
            passOverlay.topAnchor.constraint(equalTo: topAnchor),
            passOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            passOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            passOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),

            approveOverlay.topAnchor.constraint(equalTo: topAnchor),
            approveOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            approveOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            approveOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    // MARK: - Configure
    func configure(with item: ContentItem) {
        nameLabel.text = item.creatorName
        handleLabel.text = item.creatorHandle
        bodyLabel.text = item.bodyText ?? item.caption
        platformBadge.text = "  \(item.platform.rawValue.uppercased())  "

        let initials = item.creatorName.split(separator: " ")
            .compactMap { $0.first }
            .map(String.init)
            .joined()
        avatarLabel.text = String(initials.prefix(2))
    }

    @objc private func passTapped() { onPass?() }
    @objc private func approveTapped() { onApprove?() }
}
