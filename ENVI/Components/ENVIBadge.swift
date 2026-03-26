import SwiftUI

/// Small status badge for the ENVI design system.
struct ENVIBadge: View {
    let text: String
    var color: Color = ENVITheme.Dark.primary

    var body: some View {
        Text(text.uppercased())
            .font(.spaceMonoBold(10))
            .tracking(0.80)
            .foregroundColor(.white)
            .padding(.horizontal, ENVISpacing.sm)
            .padding(.vertical, ENVISpacing.xs)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
    }
}

#Preview {
    HStack {
        ENVIBadge(text: "Connected", color: ENVITheme.success)
        ENVIBadge(text: "New", color: ENVITheme.Dark.primary)
        ENVIBadge(text: "Live", color: ENVITheme.error)
    }
    .preferredColorScheme(.dark)
}
