import SwiftUI

/// Colored status badge for the ENVI design system.
/// Displays uppercase text with a tinted background matching the provided color.
struct ENVIStatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text.uppercased())
            .font(.spaceMono(9))
            .tracking(0.44)
            .foregroundColor(color)
            .padding(.horizontal, ENVISpacing.sm)
            .padding(.vertical, ENVISpacing.xs)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
    }
}

#Preview {
    HStack {
        ENVIStatusBadge(text: "Passed", color: .green)
        ENVIStatusBadge(text: "Pending", color: .orange)
        ENVIStatusBadge(text: "Failed", color: .red)
    }
    .padding()
    .preferredColorScheme(.dark)
}
