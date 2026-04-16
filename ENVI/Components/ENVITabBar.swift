import UIKit

/// Condensed 3-tab pill bar matching Sketch "Main App" design.
/// - Tab 0: Feed/Home icon (left)
/// - Tab 1: ENVI logo (center)
/// - Tab 2: Profile circle (right)
///
/// Pill: 164x64pt, fill #4A60B2, centered. Active tab gets a white 45x45 circle behind icon.
final class ENVITabBar: UIView {

    struct Tab {
        let iconName: String?
        let title: String?
        let isLogoCenter: Bool
    }

    static let defaultTabs: [Tab] = [
        Tab(iconName: "house.fill", title: nil, isLogoCenter: false),
        Tab(iconName: nil, title: "ENVI", isLogoCenter: true),
        Tab(iconName: "person.crop.circle.fill", title: nil, isLogoCenter: false),
    ]

    var selectedIndex: Int = 0 {
        didSet { updateSelection() }
    }

    var onTabSelected: ((Int) -> Void)?

    private let tabs: [Tab]
    private var buttons: [UIButton] = []
    private var activeCircles: [UIView] = []
    private var titleLabels: [UILabel] = []
    private let pillBackground = UIView()
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let tintOverlay = UIView()
    private let stackView = UIStackView()

    // Sketch spec: #4A60B2
    private let pillColor = UIColor(red: 0x4A / 255.0, green: 0x60 / 255.0, blue: 0xB2 / 255.0, alpha: 1.0)
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
        pillBackground.layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor
        pillBackground.layer.shadowColor = UIColor.black.cgColor
        pillBackground.layer.shadowOpacity = 0.24
        pillBackground.layer.shadowRadius = 20
        pillBackground.layer.shadowOffset = CGSize(width: 0, height: 10)
        pillBackground.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pillBackground)

        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.isUserInteractionEnabled = false
        pillBackground.addSubview(blurView)

        tintOverlay.backgroundColor = pillColor.withAlphaComponent(0.70)
        tintOverlay.translatesAutoresizingMaskIntoConstraints = false
        tintOverlay.isUserInteractionEnabled = false
        pillBackground.addSubview(tintOverlay)

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
            button.tintColor = UIColor.white.withAlphaComponent(0.64)

            if let iconName = tab.iconName {
                let config = UIImage.SymbolConfiguration(
                    pointSize: tab.isLogoCenter ? 22 : 19,
                    weight: tab.isLogoCenter ? .bold : .medium
                )
                button.setImage(UIImage(systemName: iconName, withConfiguration: config), for: .normal)
            } else {
                button.setTitle(nil, for: .normal)
            }
            container.addSubview(button)
            buttons.append(button)

            let titleLabel = UILabel()
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            titleLabel.isUserInteractionEnabled = false
            titleLabel.text = tab.title
            titleLabel.textAlignment = .center
            titleLabel.font = .spaceMonoBold(tab.isLogoCenter ? 13 : 11)
            titleLabel.textColor = UIColor.white.withAlphaComponent(0.9)
            titleLabel.alpha = tab.title == nil ? 0 : 1
            container.addSubview(titleLabel)
            titleLabels.append(titleLabel)

            NSLayoutConstraint.activate([
                circle.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                circle.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                circle.widthAnchor.constraint(equalToConstant: activeCircleSize),
                circle.heightAnchor.constraint(equalToConstant: activeCircleSize),
                button.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                button.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                button.widthAnchor.constraint(equalToConstant: 44),
                button.heightAnchor.constraint(equalToConstant: 44),
                titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            ])

            stackView.addArrangedSubview(container)
        }

        NSLayoutConstraint.activate([
            pillBackground.centerXAnchor.constraint(equalTo: centerXAnchor),
            pillBackground.widthAnchor.constraint(equalToConstant: 164),
            pillBackground.heightAnchor.constraint(equalToConstant: 64),
            pillBackground.topAnchor.constraint(equalTo: topAnchor),
            pillBackground.bottomAnchor.constraint(equalTo: bottomAnchor),

            blurView.topAnchor.constraint(equalTo: pillBackground.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: pillBackground.bottomAnchor),
            blurView.leadingAnchor.constraint(equalTo: pillBackground.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: pillBackground.trailingAnchor),

            tintOverlay.topAnchor.constraint(equalTo: pillBackground.topAnchor),
            tintOverlay.bottomAnchor.constraint(equalTo: pillBackground.bottomAnchor),
            tintOverlay.leadingAnchor.constraint(equalTo: pillBackground.leadingAnchor),
            tintOverlay.trailingAnchor.constraint(equalTo: pillBackground.trailingAnchor),

            stackView.topAnchor.constraint(equalTo: pillBackground.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: pillBackground.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: pillBackground.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: pillBackground.trailingAnchor, constant: -10),
        ])

        updateSelection()
    }

    @objc private func tabTapped(_ sender: UIButton) {
        let oldIndex = selectedIndex
        selectedIndex = sender.tag
        if oldIndex != sender.tag {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }
        onTabSelected?(sender.tag)
    }

    private func updateSelection() {
        for (index, button) in buttons.enumerated() {
            let isSelected = index == selectedIndex
            let tab = tabs[index]
            if let iconName = tab.iconName {
                let config = UIImage.SymbolConfiguration(
                    pointSize: tab.isLogoCenter ? 22 : 19,
                    weight: isSelected ? .bold : .medium
                )
                button.setImage(UIImage(systemName: iconName, withConfiguration: config), for: .normal)
            }

            button.tintColor = isSelected ? pillColor : UIColor.white.withAlphaComponent(0.64)
            titleLabels[index].textColor = isSelected ? pillColor : UIColor.white.withAlphaComponent(0.9)
            titleLabels[index].alpha = tab.title == nil ? 0 : 1

            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
                self.activeCircles[index].alpha = isSelected ? 1 : 0
                self.activeCircles[index].transform = isSelected ? .identity : CGAffineTransform(scaleX: 0.72, y: 0.72)
            }
        }
    }

    func setVisible(_ visible: Bool, animated: Bool = true) {
        let transform = visible ? .identity : CGAffineTransform(translationX: 0, y: 100)
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
