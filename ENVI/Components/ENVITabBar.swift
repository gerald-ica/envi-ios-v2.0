import UIKit

/// 3-pill floating tab bar matching Sketch "Main App" Tab Pill Bar symbol (164×64).
///
/// Per Sketch spec:
/// - Pill fill: `#4A5FB2` (the "purple aura")
/// - Inner white glow at top edge: shadow #FFFFFF@72% blur=8 offset=(0,4) — creates
///   a luminous highlight that reads as a translucent aura
/// - Tab 0: `shape-15` (home/feed bitmap), 30×30
/// - Tab 1: `envi-logo` (center), 30×24.6
/// - Tab 2: `person.fill` SF Symbol (profile placeholder)
///
/// When a tab is selected, a 45×45 white circle appears behind its icon and the
/// icon tints to the pill color for contrast on the white circle.
final class ENVITabBar: UIView {

    struct Tab {
        let iconName: String?
        let imageName: String?
        let iconPointSize: CGFloat
        let imageWidth: CGFloat
        let imageHeight: CGFloat
        /// When true, the tab always shows its 45×45 white background disc
        /// (e.g. the profile tab — Sketch "profile / settings icon" is
        /// persistently a white rounded rect, avatar fills it in production).
        let persistentDisc: Bool
    }

    static let defaultTabs: [Tab] = [
        Tab(iconName: nil, imageName: "shape-15", iconPointSize: 0, imageWidth: 30, imageHeight: 30, persistentDisc: false),
        Tab(iconName: nil, imageName: "envi-logo", iconPointSize: 0, imageWidth: 30, imageHeight: 25, persistentDisc: false),
        Tab(iconName: "person.fill", imageName: nil, iconPointSize: 19, imageWidth: 0, imageHeight: 0, persistentDisc: true),
    ]

    var selectedIndex: Int = 0 {
        didSet { updateSelection() }
    }

    var onTabSelected: ((Int) -> Void)?

    private let tabs: [Tab]
    private var buttons: [UIButton] = []
    private var iconViews: [UIImageView] = []
    private var activeCircles: [UIView] = []
    private let pillBackground = UIView()
    private let topGlow = CAGradientLayer()
    private let stackView = UIStackView()

    // Sketch spec: pill fill #4A5FB2 (purple aura).
    private let pillColor = UIColor(red: 0x4A / 255.0, green: 0x5F / 255.0, blue: 0xB2 / 255.0, alpha: 1.0)
    private let activeCircleSize: CGFloat = 45

    init(tabs: [Tab] = ENVITabBar.defaultTabs) {
        self.tabs = tabs
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: CGSize {
        CGSize(width: 164, height: 64)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Inner top glow — matches Sketch inner shadow #FFFFFF@72% blur=8 offset=(0,4).
        topGlow.frame = CGRect(x: 0, y: 0, width: pillBackground.bounds.width, height: 14)
    }

    private func setupUI() {
        backgroundColor = .clear
        clipsToBounds = false
        isUserInteractionEnabled = true

        // Outer drop shadow on self — not clipped by pill.
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.32
        layer.shadowRadius = 22
        layer.shadowOffset = CGSize(width: 0, height: 12)

        pillBackground.backgroundColor = pillColor
        pillBackground.layer.cornerRadius = 32
        pillBackground.layer.cornerCurve = .continuous
        pillBackground.clipsToBounds = true
        pillBackground.layer.borderWidth = 1
        pillBackground.layer.borderColor = UIColor.white.withAlphaComponent(0.16).cgColor
        pillBackground.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pillBackground)

        // Top edge glow: white → clear vertical gradient clipped by pill corners.
        // This creates the Sketch's luminous aura effect along the top rim.
        topGlow.colors = [
            UIColor.white.withAlphaComponent(0.72).cgColor,
            UIColor.white.withAlphaComponent(0.00).cgColor,
        ]
        topGlow.locations = [0.0, 1.0]
        topGlow.startPoint = CGPoint(x: 0.5, y: 0)
        topGlow.endPoint = CGPoint(x: 0.5, y: 1)
        pillBackground.layer.addSublayer(topGlow)

        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.alignment = .fill
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        pillBackground.addSubview(stackView)

        for (index, tab) in tabs.enumerated() {
            let container = UIView()
            container.translatesAutoresizingMaskIntoConstraints = false
            container.isUserInteractionEnabled = true

            let circle = UIView()
            circle.backgroundColor = .white
            circle.layer.cornerRadius = activeCircleSize / 2
            circle.translatesAutoresizingMaskIntoConstraints = false
            circle.isUserInteractionEnabled = false
            circle.alpha = 0
            circle.transform = CGAffineTransform(scaleX: 0.72, y: 0.72)
            container.addSubview(circle)
            activeCircles.append(circle)

            let iconView = UIImageView()
            iconView.translatesAutoresizingMaskIntoConstraints = false
            iconView.contentMode = .scaleAspectFit
            iconView.isUserInteractionEnabled = false
            iconView.tintColor = .white
            if let imageName = tab.imageName, let image = UIImage(named: imageName) {
                iconView.image = image.withRenderingMode(.alwaysTemplate)
            } else if let systemName = tab.iconName {
                let config = UIImage.SymbolConfiguration(pointSize: tab.iconPointSize, weight: .medium)
                iconView.image = UIImage(systemName: systemName, withConfiguration: config)?
                    .withRenderingMode(.alwaysTemplate)
            }
            container.addSubview(iconView)
            iconViews.append(iconView)

            let button = UIButton(type: .custom)
            button.backgroundColor = .clear
            button.tag = index
            button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            button.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(button)
            buttons.append(button)

            let iconWidth = tab.imageName != nil ? tab.imageWidth : 26
            let iconHeight = tab.imageName != nil ? tab.imageHeight : 26

            NSLayoutConstraint.activate([
                circle.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                circle.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                circle.widthAnchor.constraint(equalToConstant: activeCircleSize),
                circle.heightAnchor.constraint(equalToConstant: activeCircleSize),
                iconView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                iconView.widthAnchor.constraint(equalToConstant: iconWidth),
                iconView.heightAnchor.constraint(equalToConstant: iconHeight),
                button.topAnchor.constraint(equalTo: container.topAnchor),
                button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            ])

            stackView.addArrangedSubview(container)
        }

        NSLayoutConstraint.activate([
            pillBackground.centerXAnchor.constraint(equalTo: centerXAnchor),
            pillBackground.widthAnchor.constraint(equalToConstant: 164),
            pillBackground.heightAnchor.constraint(equalToConstant: 64),
            pillBackground.topAnchor.constraint(equalTo: topAnchor),
            pillBackground.bottomAnchor.constraint(equalTo: bottomAnchor),

            stackView.topAnchor.constraint(equalTo: pillBackground.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: pillBackground.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: pillBackground.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: pillBackground.trailingAnchor),
        ])

        updateSelection()
    }

    @objc private func tabTapped(_ sender: UIButton) {
        let oldIndex = selectedIndex
        selectedIndex = sender.tag
        if oldIndex != sender.tag {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        onTabSelected?(sender.tag)
    }

    private func updateSelection() {
        for (index, iconView) in iconViews.enumerated() {
            let isSelected = index == selectedIndex
            let tab = tabs[index]

            // Sketch: resting left/center icons at 85% opacity; selected tint
            // flips to pill color when the icon sits on a white circle.
            if tab.persistentDisc {
                iconView.tintColor = pillColor
                iconView.alpha = 1
            } else {
                iconView.tintColor = isSelected ? pillColor : .white
                iconView.alpha = isSelected ? 1 : 0.85
            }

            let shouldShowCircle = isSelected || tab.persistentDisc
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
                self.activeCircles[index].alpha = shouldShowCircle ? 1 : 0
                self.activeCircles[index].transform = shouldShowCircle
                    ? .identity
                    : CGAffineTransform(scaleX: 0.72, y: 0.72)
            }
        }
    }

    func setVisible(_ visible: Bool, animated: Bool = true) {
        let transform: CGAffineTransform = visible ? .identity : CGAffineTransform(translationX: 0, y: 100)
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
                self.transform = transform
                self.alpha = visible ? 1 : 0
            }
        } else {
            self.transform = transform
            self.alpha = visible ? 1 : 0
        }
    }
}
