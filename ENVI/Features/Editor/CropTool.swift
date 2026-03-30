import SwiftUI

struct CropTool: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedRatio: AspectRatio = .free

    var onApply: ((AspectRatio) -> Void)?
    var onCancel: (() -> Void)?

    enum AspectRatio: String, CaseIterable, Identifiable {
        case free = "Free"
        case square = "1:1"
        case portrait = "4:5"
        case story = "9:16"
        case landscape = "16:9"
        case wide = "1.91:1"

        var id: String { rawValue }

        var ratio: CGFloat? {
            switch self {
            case .free: return nil
            case .square: return 1.0
            case .portrait: return 4.0 / 5.0
            case .story: return 9.0 / 16.0
            case .landscape: return 16.0 / 9.0
            case .wide: return 1.91
            }
        }

        var platformHint: String {
            switch self {
            case .free: return "Any platform"
            case .square: return "Instagram Feed"
            case .portrait: return "Instagram / TikTok Feed"
            case .story: return "Stories / Reels / TikTok"
            case .landscape: return "YouTube / Twitter"
            case .wide: return "Facebook / LinkedIn"
            }
        }
    }

    var body: some View {
        VStack(spacing: ENVISpacing.lg) {
            Text("ASPECT RATIO")
                .font(.spaceMonoBold(13))
                .tracking(2.0)
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: ENVISpacing.md) {
                ForEach(AspectRatio.allCases) { ratio in
                    VStack(spacing: ENVISpacing.xs) {
                        RoundedRectangle(cornerRadius: ENVIRadius.sm)
                            .stroke(
                                selectedRatio == ratio
                                    ? ENVITheme.primary(for: colorScheme)
                                    : ENVITheme.border(for: colorScheme),
                                lineWidth: 2
                            )
                            .frame(width: 60, height: ratio.ratio.map { 60 / $0 } ?? 60)
                            .frame(height: 80)

                        Text(ratio.rawValue)
                            .font(.spaceMonoBold(12))
                            .foregroundColor(
                                selectedRatio == ratio
                                    ? ENVITheme.primary(for: colorScheme)
                                    : ENVITheme.text(for: colorScheme)
                            )

                        Text(ratio.platformHint)
                            .font(.interRegular(9))
                            .foregroundColor(ENVITheme.textLight(for: colorScheme))
                            .lineLimit(1)
                    }
                    .onTapGesture {
                        selectedRatio = ratio
                        HapticManager.shared.lightImpact()
                    }
                }
            }

            HStack {
                Button("Cancel") { onCancel?() }
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))
                Spacer()
                Button("Apply") { onApply?(selectedRatio) }
                    .foregroundColor(ENVITheme.primary(for: colorScheme))
            }
        }
        .padding()
    }
}
