import UIKit

/// 3-pill floating tab bar matching Sketch "Main App" Tab Pill Bar symbol (164×64).
/// iOS 26: uses `UIGlassEffect` for the native Liquid Glass look; falls back to
/// `UIBlurEffect(.systemUltraThinMaterialDark)` on iOS 25 and below.
///
/// - Tab 0: Home/Feed icon (house)
/// - Tab 1: ENVI logo (center)
/// - Tab 2: Profile icon (person)
///
/// Active tab gets a white 45×45 circle behind the icon; tab tint inverts to
/// pill color (#191919) when selected.
final class ENVITabBar: UIView {

    struct Tab {
        let iconName: String?
        let logoImageName: String?
    }

    static let defaultTabs: [Tab] = [
        Tab(iconName: "house.fill", logoImageName: nil),
        Tab(iconName: nil, logoImageName: "envi-logo"),
        Tab(iconName: "person.crop.circle.fill", logoImageName: nil),
    ]

    var selectedIndex: Int = 0 {
        didSet { updateSelection() }
    }

    var onTabSelected: ((Int) -> Void)?

    private let tabs: [Tab]
    private var buttons: [UIButton] = []
    private var activeCircles: [UIView] = []
    private let pillBackground = UIView()
    private let glassContainer = UIView()
    private let pillTint = UIView()
    private let stackView = UIStackView()

    // Sketch spec: pill background #191919 (near-black) with glass overlay.
    private let pillColor = UIColor(red: 0x19 / 255.0, green: 0x19 / 255.0, blue: 0x19 / 255.0, alpha: 1.0)
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

    private func setupUI() {
        backgroundColor = .clear
        clipsToBounds = false

        pillBackground.backgroundColor = .clear
        pillBackground.layer.cornerRadius = 32
        pillBackground.layer.cornerCurve = .continuous
        pillBackground.clipsToBounds = true
        pillBackground.layer.borderWidth = 1
        pillBackground.layer.borderColor = UIColor.white.withAlphaComponent(0.14).cgColor
        pillBackground.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pillBackground)

        // Drop shadow on a sibling container so it's not clipped.
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowRadius = 24
        layer.shadowOffset = CGSize(width: 0, height: 12)

        glassContainer.translatesAutoresizingMaskIntoConstraints = false
        glassContainer.isUserInteractionEnabled = false
        pillBackground.addSubview(glassContainer)

        installGlass(on: glassContainer)

        // Tint overlay sits above glass to give the pill its #191919 read.
        pillTint.backgroundColor = pillColor.withAlphaComponent(0.62)
        pillTint.translatesAutoresizingMaskIntoConstraints = false
        pillTint.isUserInteractionEnabled = false
        pillBackground.addSubview(pillTint)

        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        pillBackground.addSubview(stackView)

        for (index, tab) in tabs.enumerated() {
            let container = UIView()
            container.translatesAutoresizingMaskIntoConstraints = false

            let circle = UIView()
            circle.backgroundColor = .white
            circle.layer.cornerRadius = activeCircleSize / 2
            circle.translatesAutoresizingMaskIntoConstraints = false
            circle.isUserInteractionEnabled = false
            circle.alpha = 0
            circle.transform = CGAffineTransform(scaleX: 0.72, y: 0.72)
            container.addSubview(circle)
            activeCircles.append(circle)

            let button = UIButton(type: .system)
            button.tag = index
            button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.adjustsImageWhenHighlighted = false
            button.tintColor = .white

            if let iconName = tab.iconName {
                let config = UIImage.SymbolConfiguration(pointSize: 19, weight: .medium)
                button.setImage(UIImage(systemName: iconName, withConfiguration: config), for: .normal)
            } else if let logoName = tab.logoImageName, let logo = UIImage(named: logoName) {
                let tinted = logo.withRenderingMode(.alwaysTemplate)
                button.setImage(tinted, for: .normal)
                button.imageView?.contentMode = .scaleAspectFit
                button.contentHorizontalAlignment = .fill
                button.contentVerticalAlignment = .fill
                button.imageEdgeInsets = UIEdgeInsets(top: 7, left: 7, bottom: 7, right: 7)
            }
            container.addSubview(button)
            buttons.append(button)

            NSLayoutConstraint.activate([
                circle.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                circle.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                circle.widthAnchor.constraint(equalToConstant: activeCircleSize),
                circle.heightAnchor.constraint(equalToConstant: activeCircleSize),
                button.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                button.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                button.widthAnchor.constraint(equalToConstant: 44),
                button.heightAnchor.constraint(equalToConstant: 44),
            ])

            stackView.addArrangedSubview(container)
        }

        NSLayoutConstraint.activate([
            pillBackground.centerXAnchor.constraint(equalTo: centerXAnchor),
            pillBackground.widthAnchor.constraint(equalToConstant: 164),
            pillBackground.heightAnchor.constraint(equalToConstant: 64),
            pillBackground.topAnchor.constraint(equalTo: topAnchor),
            pillBackground.bottomAnchor.constraint(equalTo: bottomAnchor),

            glassContainer.topAnchor.constraint(equalTo: pillBackground.topAnchor),
            glassContainer.bottomAnchor.constraint(equalTo: pillBackground.bottomAnchor),
            glassContainer.leadingAnchor.constraint(equalTo: pillBackground.leadingAnchor),
            glassContainer.trailingAnchor.constraint(equalTo: pillBackground.trailingAnchor),

            pillTint.topAnchor.constraint(equalTo: pillBackground.topAnchor),
            pillTint.bottomAnchor.constraint(equalTo: pillBackground.bottomAnchor),
            pillTint.leadingAnchor.constraint(equalTo: pillBackground.leadingAnchor),
            pillTint.trailingAnchor.constraint(equalTo: pillBackground.trailingAnchor),

            stackView.topAnchor.constraint(equalTo: pillBackground.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: pillBackground.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: pillBackground.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: pillBackground.trailingAnchor, constant: -10),
        ])

        updateSelection()
    }

    /// Installs iOS 26 `UIGlassEffect` if available, else falls back to blur.
    private func installGlass(on container: UIView) {
        if #available(iOS 26.0, *) {
            let effect = UIGlassEffect()
            effect.tintColor = .clear
            effect.isInteractive = false
            let view = UIVisualEffectView(effect: effect)
            view.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(view)
            pinEdges(view, to: container)
        } else {
            let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
            view.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(view)
            pinEdges(view, to: container)
        }
    }

    private func pinEdges(_ child: UIView, to parent: UIView) {
        NSLayoutConstraint.activate([
            child.topAnchor.constraint(equalTo: parent.topAnchor),
            child.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
            child.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            child.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
        ])
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
        for (index, button) in buttons.enumerated() {
            let isSelected = index == selectedIndex

            // When selected, the active white circle appears behind the icon —
            // tint the icon to pill color (#191919) so it reads on white.
            button.tintColor = isSelected ? pillColor : .white

            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
                self.activeCircles[index].alpha = isSelected ? 1 : 0
                self.activeCircles[index].transform = isSelected ? .identity : CGAffineTransform(scaleX: 0.72, y: 0.72)
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
