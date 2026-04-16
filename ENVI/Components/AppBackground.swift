import SwiftUI

/// App-wide background layer rendering a grainy texture from
/// `Resources/Images/Backgrounds/` with a dark vignette on top.
///
/// Each Main App screen pairs with a specific asset:
/// - For You / Home feed → `bg-texture-09`
/// - Chat home          → `chat-home-bg`
/// - World Explorer     → `world-explorer-bg`
/// - Analytics          → `analytics-bg`
/// - Profile            → `profile-bg`
struct AppBackground: View {

    let imageName: String
    var vignetteOpacity: Double = 0.55

    /// Convenience default matches the For You screen.
    init(imageName: String = "bg-texture-09", vignetteOpacity: Double = 0.55) {
        self.imageName = imageName
        self.vignetteOpacity = vignetteOpacity
    }

    var body: some View {
        ZStack {
            Color.black

            Image(imageName)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // Vignette fade to near-black at the edges so text stays readable.
            RadialGradient(
                colors: [.clear, .black.opacity(vignetteOpacity)],
                center: .center,
                startRadius: 180,
                endRadius: 520
            )
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}

#Preview {
    AppBackground()
}
