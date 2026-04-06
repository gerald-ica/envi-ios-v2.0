import SwiftUI

/// Inline error message banner for the ENVI design system.
/// Displays an error string in the standard error color with Inter Regular 13pt.
struct ENVIErrorBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.interRegular(13))
            .foregroundColor(ENVITheme.error)
            .padding(.horizontal, ENVISpacing.xl)
    }
}

#Preview {
    ENVIErrorBanner(message: "Unable to load experiments.")
        .preferredColorScheme(.dark)
}
