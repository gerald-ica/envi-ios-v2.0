import SwiftUI

/// Canonical ENVI wordmark component (Phase 19 Plan 05).
///
/// Before Phase 19 there were two different stencil-font renderings of
/// the wordmark — Splash used `SpaceMonoBold(48)` with default tracking
/// and hardcoded white, SignIn used `SpaceMonoBold(40)` with `-2.0`
/// tracking and theme-aware text color. The Wave 3 simulator walkthrough
/// caught this as the only visual-design inconsistency in the audit.
///
/// This component locks in one canonical rendering and is the only
/// place the wordmark should be set in SwiftUI code going forward. The
/// `Splash` UIKit controller uses a `UIHostingConfiguration` to render
/// this same SwiftUI component so all call sites agree.
struct ENVIWordmark: View {

    enum Size {
        /// Splash / launch screens (~48 pt).
        case splash
        /// Sign-in / onboarding headers (~40 pt).
        case heading

        var pointSize: CGFloat {
            switch self {
            case .splash:  return 48
            case .heading: return 40
            }
        }
    }

    let size: Size
    let color: Color

    init(size: Size = .heading, color: Color? = nil) {
        self.size = size
        // Default to the canonical theme text color when no override is
        // supplied. Splash passes `.white` so it renders correctly on the
        // dark spiral background regardless of colorScheme.
        self.color = color ?? Color.white
    }

    var body: some View {
        Text("ENVI")
            .font(.spaceMonoBold(size.pointSize))
            .tracking(-2.0)
            .foregroundColor(color)
    }
}

#Preview {
    VStack(spacing: 24) {
        ENVIWordmark(size: .splash, color: .white)
        ENVIWordmark(size: .heading, color: .white)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
}
