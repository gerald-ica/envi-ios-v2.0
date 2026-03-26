import UIKit

/// Singleton haptic feedback manager for ENVI.
/// Centralises all haptic triggers so callers stay decoupled from UIKit generators.
final class HapticManager {
    static let shared = HapticManager()
    private init() {}

    // MARK: - Impact

    private let lightGenerator   = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator  = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator   = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()

    /// Light tap — chips, toggles, minor interactions.
    func lightImpact() {
        lightGenerator.prepare()
        lightGenerator.impactOccurred()
    }

    /// Medium tap — card taps, navigation transitions.
    func mediumImpact() {
        mediumGenerator.prepare()
        mediumGenerator.impactOccurred()
    }

    /// Heavy tap — long-press confirmations, significant actions.
    func heavyImpact() {
        heavyGenerator.prepare()
        heavyGenerator.impactOccurred()
    }

    /// Selection tick — scrolling through a picker or highlighting items.
    func selection() {
        selectionGenerator.prepare()
        selectionGenerator.selectionChanged()
    }

    /// Notification feedback — success, warning, or error.
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(type)
    }
}
