import SwiftUI

/// Small pill showing AI-generated insight (confidence %, best time, estimated reach).
/// All pills: white/0.15 bg, white text. No green/blue/purple pill colors.
struct AIInsightPill: View {
    enum InsightType {
        case confidence(Double)   // 0–1
        case bestTime(String)
        case reach(String)
    }

    let type: InsightType
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 10, weight: .semibold))

            Text(displayText.uppercased())
                .font(.spaceMonoBold(10))
                .tracking(2.0)
        }
        .foregroundColor(ENVITheme.text(for: colorScheme))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(ENVITheme.text(for: colorScheme).opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
    }

    // All icons use outline variants — no .fill
    private var iconName: String {
        switch type {
        case .confidence: return "brain.head.profile"
        case .bestTime:   return "clock"
        case .reach:      return "eye"
        }
    }

    private var displayText: String {
        switch type {
        case .confidence(let value): return "\(Int(value * 100))%"
        case .bestTime(let time):    return time
        case .reach(let reach):      return reach
        }
    }
}

/// Row of 3 AI insight pills.
struct AIInsightRow: View {
    let confidence: Double
    let bestTime: String
    let reach: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            AIInsightPill(type: .confidence(confidence))
            AIInsightPill(type: .bestTime(bestTime))
            AIInsightPill(type: .reach(reach))
        }
    }
}

#Preview {
    VStack {
        AIInsightRow(confidence: 0.92, bestTime: "6:00 PM", reach: "45.2K")
    }
    .padding()
    .background(Color.black)
}
