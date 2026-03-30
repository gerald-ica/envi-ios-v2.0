import SwiftUI

struct TextOverlayTool: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var overlayText = ""
    @State private var selectedFont: TextFont = .spaceMono
    @State private var selectedColor: Color = .white
    @State private var fontSize: CGFloat = 24
    @State private var textPosition: CGPoint = CGPoint(x: 0.5, y: 0.5) // normalized

    var onApply: ((TextOverlayConfig) -> Void)?
    var onCancel: (() -> Void)?

    enum TextFont: String, CaseIterable {
        case spaceMono = "Space Mono"
        case inter = "Inter"
        case system = "System"
    }

    var body: some View {
        VStack(spacing: ENVISpacing.lg) {
            // Text input
            TextField("Enter text...", text: $overlayText)
                .font(.system(size: fontSize))
                .foregroundColor(selectedColor)
                .multilineTextAlignment(.center)
                .padding()
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .cornerRadius(ENVIRadius.md)

            // Font selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ENVISpacing.sm) {
                    ForEach(TextFont.allCases, id: \.self) { font in
                        ENVIChip(title: font.rawValue, isSelected: selectedFont == font) {
                            selectedFont = font
                        }
                    }
                }
            }

            // Font size slider
            VStack(alignment: .leading) {
                Text("SIZE")
                    .font(.spaceMonoBold(11))
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))
                Slider(value: $fontSize, in: 12...72, step: 2)
                    .tint(ENVITheme.primary(for: colorScheme))
            }

            // Color picker
            HStack(spacing: ENVISpacing.md) {
                ForEach([Color.white, Color.black, Color.red, Color.blue, Color.yellow, Color.green], id: \.self) { color in
                    Circle()
                        .fill(color)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(selectedColor == color ? ENVITheme.primary(for: colorScheme) : .clear, lineWidth: 2)
                        )
                        .onTapGesture { selectedColor = color }
                }
            }

            // Action buttons
            HStack {
                Button("Cancel") { onCancel?() }
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))
                Spacer()
                Button("Apply") {
                    onApply?(TextOverlayConfig(
                        text: overlayText,
                        font: selectedFont,
                        color: selectedColor,
                        fontSize: fontSize,
                        position: textPosition
                    ))
                }
                .foregroundColor(ENVITheme.primary(for: colorScheme))
                .disabled(overlayText.isEmpty)
            }
        }
        .padding()
    }
}

struct TextOverlayConfig {
    let text: String
    let font: TextOverlayTool.TextFont
    let color: Color
    let fontSize: CGFloat
    let position: CGPoint
}
