import UIKit

/// Condensed 3-tab pill bar matching Sketch "Main App" design.
/// - Tab 0: Feed/Home icon (left)
/// - Tab 1: ENVI logo (center)
/// - Tab 2: Profile circle (right)
///
/// Pill: 164x64pt, fill #4A60B2, centered. Active tab gets a white 45x45 circle behind icon.
final class ENVITabBar: UIView {

    struct Tab {
        let iconName: String       // SF Symbol name
        let isLogoCenter: Bool     // true for the ENVI logo center tab
    }

    static let defaultTabs: [Tab] = [
        Tab(iconName: "square.grid.2x2", isLogoCenter: false),   // For You / Gallery
        Tab(iconName: "sparkles", isLogoCenter: true),             // World Explorer (ENVI logo — placeholder SF Symbol until custom asset)
        Tab(iconName: "person.crop.circle", isLogoCenter: false),  // Profile
    ]

    var selectedIndex: Int = 0 {
        didSet { updateSelection() }
    }

    var onTabSelected: ((Int) -> Void)?

    private let tabs: [Tab]
    private var buttons: [UIButton] = []
    private var activeCircles: [UIView] = []
    private let pillBackground = UIView()
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

    private func setupUI() {
        // Pill background — Sketch: 164x64, fill #4A60B2, centered
        pillBackground.backgroundColor = pillColor
        pillBackground.layer.cornerRadius = 32 // half of 64pt height
        pillBackground.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pillBackground)

        // Stack for icons
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        pillBackground.addSubview(stackView)

        for (index, tab) in tabs.enumerated() {
            // Container for active circle + icon
            let container = UIView()
            container.translatesAutoresizingMaskIntoConstraints = false

            // Active circle (white, behind icon)
            let circle = UIView()
            circle.backgroundColor = .white
            circle.layer.cornerRadius = activeCircleSize / 2
            circle.translatesAutoresizingMaskIntoConstraints = false
            circle.alpha = 0
            container.addSubview(circle)
            activeCircles.append(circle)

            // Icon button
            let button = UIButton(type: .system)
            let config = UIImage.SymbolConfiguration(pointSize: tab.isLogoCenter ? 24 : 20, weight: .medium)
            button.setImage(UIImage(systemName: tab.iconName, withConfiguration: config), for: .normal)
            button.tintColor = UIColor.white.withAlphaComponent(0.6)
            button.tag = index
            button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            button.translatesAutoresizingMaskIntoConstraints = false
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

        // Pill: 164pt wide, 64pt tall, centered horizontally
        NSLayoutConstraint.activate([
            pillBackground.centerXAnchor.constraint(equalTo: centerXAnchor),
            pillBackground.widthAnchor.constraint(equalToConstant: 164),
            pillBackground.heightAnchor.constraint(equalToConstant: 64),
            pillBackground.topAnchor.constraint(equalTo: topAnchor),
            pillBackground.bottomAnchor.constraint(equalTo: bottomAnchor),

            stackView.topAnchor.constraint(equalTo: pillBackground.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: pillBackground.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: pillBackground.leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: pillBackground.trailingAnchor, constant: -8),
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
            let config = UIImage.SymbolConfiguration(
                pointSize: tab.isLogoCenter ? 24 : 20,
                weight: isSelected ? .bold : .medium
            )
            button.setImage(UIImage(systemName: tab.iconName, withConfiguration: config), for: .normal)

            // Active: dark icon on white circle. Inactive: white/0.6 icon, no circle.
            button.tintColor = isSelected ? pillColor : UIColor.white.withAlphaComponent(0.6)

            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
                self.activeCircles[index].alpha = isSelected ? 1 : 0
                self.activeCircles[index].transform = isSelected ? .identity : CGAffineTransform(scaleX: 0.6, y: 0.6)
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
