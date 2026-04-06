import SwiftUI

/// Reusable uppercase section header for the ENVI design system.
/// Used across Settings, Publishing, Security, and other feature views.
struct ENVISectionHeader: View {
    let title: String
    var tracking: CGFloat = 0.88

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(title)
            .font(.spaceMonoBold(11))
            .tracking(tracking)
            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        ENVISectionHeader(title: "ACTIVE DEVICES")
        ENVISectionHeader(title: "SECURITY ALERTS", tracking: 2.0)
    }
    .padding()
    .preferredColorScheme(.dark)
}
