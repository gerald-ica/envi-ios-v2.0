import SwiftUI

/// Aspect ratio selector with visual previews and platform recommendations.
struct AspectRatioPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedRatio: AspectRatio
    @State private var fillMode: FillMode = .crop

    enum FillMode: String, CaseIterable {
        case crop = "Crop"
        case fit = "Fit"
        case blur = "Blur Fill"

        var iconName: String {
            switch self {
            case .crop: return "crop"
            case .fit:  return "arrow.down.right.and.arrow.up.left"
            case .blur: return "rectangle.on.rectangle"
            }
        }
    }

    var body: some View {
        ZStack {
            ENVITheme.Dark.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                previewCard
                ratioGrid
                fillModeSelector
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }

            Spacer()

            Text("ASPECT RATIO")
                .font(.spaceMonoBold(17))
                .foregroundColor(.white)
                .tracking(-1)

            Spacer()

            Button("DONE") {
                dismiss()
            }
            .font(.spaceMonoBold(13))
            .foregroundColor(.white.opacity(0.7))
            .tracking(1)
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
    }

    // MARK: - Preview Card

    private var previewCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .fill(ENVITheme.Dark.surfaceLow)

            // Inner ratio frame
            let previewSize = ratioPreviewSize(in: CGSize(width: 280, height: 320))
            RoundedRectangle(cornerRadius: ENVIRadius.sm)
                .fill(ENVITheme.Dark.surfaceHigh)
                .frame(width: previewSize.width, height: previewSize.height)
                .overlay(
                    VStack(spacing: 4) {
                        Text(selectedRatio.displayName)
                            .font(.spaceMonoBold(22))
                            .foregroundColor(.white)
                            .tracking(-1)
                        Text(selectedRatio.platformHint.uppercased())
                            .font(.spaceMonoBold(9))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(2)
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.sm)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
        .frame(height: 300)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func ratioPreviewSize(in container: CGSize) -> CGSize {
        let ratio = selectedRatio.ratio
        if ratio >= 1 {
            // Landscape or square
            let width = min(container.width, container.width)
            let height = width / ratio
            return CGSize(width: width, height: min(height, container.height))
        } else {
            // Portrait
            let height = min(container.height, container.height)
            let width = height * ratio
            return CGSize(width: min(width, container.width), height: height)
        }
    }

    // MARK: - Ratio Grid

    private var ratioGrid: some View {
        VStack(spacing: 8) {
            HStack {
                Text("SELECT RATIO")
                    .font(.spaceMonoBold(9))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(2)
                Spacer()
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                ForEach(AspectRatio.allCases, id: \.self) { ratio in
                    RatioButton(
                        ratio: ratio,
                        isSelected: selectedRatio == ratio,
                        onTap: { selectedRatio = ratio }
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Fill Mode Selector

    private var fillModeSelector: some View {
        VStack(spacing: 8) {
            HStack {
                Text("FILL MODE")
                    .font(.spaceMonoBold(9))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(2)
                Spacer()
            }

            HStack(spacing: 10) {
                ForEach(FillMode.allCases, id: \.self) { mode in
                    Button {
                        fillMode = mode
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: mode.iconName)
                                .font(.system(size: 18))
                            Text(mode.rawValue.uppercased())
                                .font(.spaceMonoBold(9))
                                .tracking(0.5)
                        }
                        .foregroundColor(fillMode == mode ? .white : .white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: ENVIRadius.sm)
                                .fill(fillMode == mode ? Color.white.opacity(0.12) : ENVITheme.Dark.surfaceLow)
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
}

// MARK: - Ratio Button

private struct RatioButton: View {
    let ratio: AspectRatio
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                // Mini aspect ratio preview
                let miniSize = miniPreviewSize
                RoundedRectangle(cornerRadius: 3)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.2))
                    .frame(width: miniSize.width, height: miniSize.height)

                Text(ratio.displayName)
                    .font(.spaceMonoBold(10))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.5))

                Text(ratio.platformHint.components(separatedBy: ",").first ?? "")
                    .font(.interRegular(8))
                    .foregroundColor(.white.opacity(0.3))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: ENVIRadius.sm)
                    .fill(isSelected ? Color.white.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.sm)
                    .strokeBorder(isSelected ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
    }

    private var miniPreviewSize: CGSize {
        let maxSide: CGFloat = 28
        let r = ratio.ratio
        if r >= 1 {
            return CGSize(width: maxSide, height: maxSide / r)
        } else {
            return CGSize(width: maxSide * r, height: maxSide)
        }
    }
}
