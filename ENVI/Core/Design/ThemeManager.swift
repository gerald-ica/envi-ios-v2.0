import SwiftUI
import Combine

/// Manages the app's appearance mode (light/dark/system).
/// Published as an ObservableObject so SwiftUI views auto-update.
final class ThemeManager: ObservableObject {
    enum AppearanceMode: String, CaseIterable {
        case light
        case dark
        case system
    }

    nonisolated(unsafe) static let shared = ThemeManager()

    @Published var mode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "envi_appearance_mode")
            applyMode()
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "envi_appearance_mode") ?? "dark"
        self.mode = AppearanceMode(rawValue: saved) ?? .dark
        applyMode()
    }

    nonisolated func applyMode() {
        let currentMode = self.mode
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            let style: UIUserInterfaceStyle
            switch currentMode {
            case .light:  style = .light
            case .dark:   style = .dark
            case .system: style = .unspecified
            }
            windowScene.windows.forEach { $0.overrideUserInterfaceStyle = style }
        }
    }

    var colorScheme: ColorScheme? {
        switch mode {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return nil
        }
    }
}
