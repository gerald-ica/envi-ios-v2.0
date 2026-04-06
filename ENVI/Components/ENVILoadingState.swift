import SwiftUI

/// Centered loading indicator for the ENVI design system.
/// Displays a ProgressView centered with a minimum height.
struct ENVILoadingState: View {
    var minHeight: CGFloat = 120

    var body: some View {
        ProgressView()
            .frame(maxWidth: .infinity, minHeight: minHeight)
    }
}

#Preview {
    ENVILoadingState()
        .preferredColorScheme(.dark)
}
