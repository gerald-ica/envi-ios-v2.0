import UIKit

/// Custom pill-shaped tab bar for the ENVI app.
/// Renders 5 icon-only tabs with a floating pill background.
final class ENVITabBar: UIView {

    struct Tab {
        let iconName: String       // SF Symbol name
        let selectedIconName: String
    }

    static let defaultTabs: [Tab] = [
        Tab(iconName: "house", selectedIconName: "house.fill"),
        Tab(iconName: "square.grid.2x2", selectedIconName: "square.grid.2x2.fill"),
        Tab(iconName: "sparkles", selectedIconName: "sparkles"),
        Tab(iconName: "chart.bar", selectedIconName: "chart.bar.fill"),
        Tab(iconName: "person", selectedIconName: "person.fill"),
    ]

    var selectedIndex: Int = 0 {
        didSet { updateSelection() }
    }

    var onTabSelected: ((Int) -> Void)?

    private let tabs: [Tab]
    private var buttons: [UIButton] = []
    private let pillBackground = UIView()
    private let stackView = UIStackView()

    init(tabs: [Tab] = ENVITabBar.defaultTabs) {
        self.tabs = tabs
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        // Pill background
        pillBackground.backgroundColor = ENVITheme.UIKit.surfaceLowDark
        pillBackground.layer.cornerRadius = 32
        pillBackground.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pillBackground)

        // Stack
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        pillBackground.addSubview(stackView)

        // Create buttons
        for (index, tab) in tabs.enumerated() {
            let button = UIButton(type: .system)
            let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
            button.setImage(UIImage(systemName: tab.iconName, withConfiguration: config), for: .normal)
            button.tintColor = ENVITheme.UIKit.textLightDark
            button.tag = index
            button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            buttons.append(button)
            stackView.addArrangedSubview(button)
        }

        NSLayoutConstraint.activate([
            pillBackground.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            pillBackground.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            pillBackground.topAnchor.constraint(equalTo: topAnchor),
            pillBackground.heightAnchor.constraint(equalToConstant: 64),
            pillBackground.bottomAnchor.constraint(equalTo: bottomAnchor),

            stackView.topAnchor.constraint(equalTo: pillBackground.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: pillBackground.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: pillBackground.leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: pillBackground.trailingAnchor, constant: -8),
        ])

        updateSelection()
    }

    @objc private func tabTapped(_ sender: UIButton) {
        selectedIndex = sender.tag
        onTabSelected?(sender.tag)
    }

    private func updateSelection() {
        for (index, button) in buttons.enumerated() {
            let tab = tabs[index]
            let isSelected = index == selectedIndex
            let config = UIImage.SymbolConfiguration(pointSize: 22, weight: isSelected ? .semibold : .medium)
            let iconName = isSelected ? tab.selectedIconName : tab.iconName
            button.setImage(UIImage(systemName: iconName, withConfiguration: config), for: .normal)
            button.tintColor = isSelected ? ENVITheme.UIKit.primaryDark : ENVITheme.UIKit.textLightDark
        }
    }

    /// Animate hide/show for scroll-driven hiding
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
