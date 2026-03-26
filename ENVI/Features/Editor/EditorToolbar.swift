import UIKit

/// Bottom toolbar for the video editor with tool icons.
final class EditorToolbar: UIView {

    struct Tool {
        let name: String
        let iconName: String
    }

    static let defaultTools: [Tool] = [
        Tool(name: "Trim", iconName: "scissors"),
        Tool(name: "Adjust", iconName: "slider.horizontal.3"),
        Tool(name: "Text", iconName: "textformat"),
        Tool(name: "Audio", iconName: "waveform"),
        Tool(name: "Filters", iconName: "camera.filters"),
        Tool(name: "Crop", iconName: "crop"),
    ]

    var onToolSelected: ((Int) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        for (index, tool) in Self.defaultTools.enumerated() {
            let button = UIButton(type: .system)
            let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
            button.setImage(UIImage(systemName: tool.iconName, withConfiguration: config), for: .normal)
            button.tintColor = ENVITheme.UIKit.textLightDark
            button.tag = index
            button.addTarget(self, action: #selector(toolTapped(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
        }
    }

    @objc private func toolTapped(_ sender: UIButton) {
        onToolSelected?(sender.tag)
    }
}
