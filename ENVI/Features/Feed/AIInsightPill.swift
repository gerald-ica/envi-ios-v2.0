import SwiftUI

/// Small pill showing AI-generated insight (confidence %, best time, estimated reach).
struct AIInsightPill: View {
    enum InsightType {
        case confidence(Double)   // 0–1
        case bestTime(String)
        case reach(String)
    }

    let type: InsightType

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 10, weight: .semibold))

            Text(displayText)
                .font(.spaceMonoBold(10))
                .tracking(0.80)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(pillColor.opacity(0.85))
        .clipShape(Capsule())
    }

    private var iconName: String {
        switch type {
        case .confidence: return "brain.head.profile"
        case .bestTime:   return "clock.fill"
        case .reach:      return "eye.fill"
        }
    }

    private var displayText: String {
        switch type {
        case .confidence(let value): return "\(Int(value * 100))%"
        case .bestTime(let time):    return time
        case .reach(let reach):      return reach
        }
    }

    private var pillColor: Color {
        switch type {
        case .confidence: return Color(hex: "#22C55E") // green
        case .bestTime:   return Color(hex: "#3B82F6") // blue
        case .reach:      return Color(hex: "#8B5CF6") // purple
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
