import SwiftUI

/// Text overlay editor: add, style, animate, and position text layers on the video preview.
struct TextOverlayView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TextOverlayViewModel()

    var body: some View {
        ZStack {
            ENVITheme.Dark.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                previewArea
                timelineBars
                controlsPanel
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

            Text("TEXT")
                .font(.spaceMonoBold(17))
                .foregroundColor(.white)
                .tracking(-1)

            Spacer()

            Button(action: { viewModel.addLayer() }) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
    }

    // MARK: - Preview Area

    private var previewArea: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: ENVIRadius.lg)
                    .fill(ENVITheme.Dark.surfaceLow)

                ForEach($viewModel.overlays) { $overlay in
                    DraggableTextLabel(
                        overlay: $overlay,
                        containerSize: geo.size,
                        isSelected: viewModel.selectedID == overlay.id,
                        onTap: { viewModel.selectedID = overlay.id }
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: UIScreen.main.bounds.height * 0.4)
    }

    // MARK: - Timeline Duration Bars

    private var timelineBars: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(viewModel.overlays) { overlay in
                    HStack(spacing: 4) {
                        Text(overlay.text.prefix(12))
                            .font(.spaceMonoBold(9))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 60, alignment: .leading)
                            .lineLimit(1)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(viewModel.selectedID == overlay.id ? Color.white : Color.white.opacity(0.3))
                            .frame(
                                width: max(40, CGFloat(overlay.endTime - overlay.startTime) * 20),
                                height: 20
                            )
                            .offset(x: CGFloat(overlay.startTime) * 20)
                    }
                    .onTapGesture { viewModel.selectedID = overlay.id }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(height: viewModel.overlays.isEmpty ? 0 : CGFloat(viewModel.overlays.count * 28 + 16))
    }

    // MARK: - Controls Panel

    private var controlsPanel: some View {
        VStack(spacing: 12) {
            if let binding = viewModel.selectedBinding {
                textInputRow(binding: binding)
                fontAndSizeRow(binding: binding)
                colorRow(binding: binding)
                animationPicker(binding: binding)
            } else {
                emptyPrompt
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: ENVIRadius.xl)
                .fill(Color.black.opacity(0.9))
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func textInputRow(binding: Binding<TextOverlay>) -> some View {
        HStack {
            TextField("Enter text", text: binding.text)
                .font(.interRegular(15))
                .foregroundColor(.white)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: ENVIRadius.sm)
                        .fill(ENVITheme.Dark.surfaceHigh)
                )

            Button(role: .destructive) {
                viewModel.removeSelected()
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.8))
            }
        }
    }

    private func fontAndSizeRow(binding: Binding<TextOverlay>) -> some View {
        HStack(spacing: 12) {
            // Font picker
            Menu {
                ForEach(TextOverlayViewModel.availableFonts, id: \.self) { fontName in
                    Button(fontName) {
                        binding.wrappedValue.fontName = fontName
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "textformat")
                    Text(binding.wrappedValue.fontName.split(separator: "-").first.map(String.init) ?? "Font")
                        .lineLimit(1)
                }
                .font(.spaceMono(11))
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: ENVIRadius.sm)
                        .fill(ENVITheme.Dark.surfaceHigh)
                )
            }

            // Size slider
            HStack(spacing: 6) {
                Text("SIZE")
                    .font(.spaceMonoBold(9))
                    .foregroundColor(.white.opacity(0.5))
                Slider(value: binding.fontSize, in: 12...72, step: 1)
                    .tint(.white)
                Text("\(Int(binding.wrappedValue.fontSize))")
                    .font(.interRegular(13))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 28)
            }
        }
    }

    private func colorRow(binding: Binding<TextOverlay>) -> some View {
        HStack(spacing: 8) {
            Text("COLOR")
                .font(.spaceMonoBold(9))
                .foregroundColor(.white.opacity(0.5))

            ForEach(TextOverlayViewModel.colorOptions, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white, lineWidth: binding.wrappedValue.color == hex ? 2 : 0)
                    )
                    .onTapGesture { binding.wrappedValue.color = hex }
            }

            Spacer()
        }
    }

    private func animationPicker(binding: Binding<TextOverlay>) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TextAnimation.allCases, id: \.self) { anim in
                    Button {
                        binding.wrappedValue.animation = anim
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: anim.iconName)
                                .font(.system(size: 16))
                            Text(anim.displayName.uppercased())
                                .font(.spaceMonoBold(8))
                        }
                        .foregroundColor(binding.wrappedValue.animation == anim ? .white : .white.opacity(0.4))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: ENVIRadius.sm)
                                .fill(binding.wrappedValue.animation == anim
                                      ? Color.white.opacity(0.15)
                                      : Color.clear)
                        )
                    }
                }
            }
        }
    }

    private var emptyPrompt: some View {
        VStack(spacing: 8) {
            Image(systemName: "textformat")
                .font(.system(size: 28))
                .foregroundColor(.white.opacity(0.3))
            Text("Tap + to add a text layer")
                .font(.interRegular(13))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - Draggable Text Label

private struct DraggableTextLabel: View {
    @Binding var overlay: TextOverlay
    let containerSize: CGSize
    let isSelected: Bool
    let onTap: () -> Void

    @State private var dragOffset: CGSize = .zero

    var body: some View {
        Text(overlay.text)
            .font(.custom(overlay.fontName, size: overlay.fontSize))
            .foregroundColor(Color(hex: overlay.color))
            .padding(6)
            .background(
                isSelected
                    ? RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    : nil
            )
            .position(
                x: overlay.position.x * containerSize.width + dragOffset.width,
                y: overlay.position.y * containerSize.height + dragOffset.height
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        overlay.position = CGPoint(
                            x: clamp((overlay.position.x * containerSize.width + value.translation.width) / containerSize.width, 0.05, 0.95),
                            y: clamp((overlay.position.y * containerSize.height + value.translation.height) / containerSize.height, 0.05, 0.95)
                        )
                        dragOffset = .zero
                    }
            )
            .onTapGesture { onTap() }
    }

    private func clamp(_ value: CGFloat, _ low: CGFloat, _ high: CGFloat) -> CGFloat {
        min(max(value, low), high)
    }
}

// MARK: - ViewModel

final class TextOverlayViewModel: ObservableObject {
    @Published var overlays: [TextOverlay] = []
    @Published var selectedID: UUID?

    static let availableFonts = [
        "SpaceMono-Bold",
        "SpaceMono-Regular",
        "Inter-Bold",
        "Inter-Regular",
        "Inter-Black",
    ]

    static let colorOptions = [
        "#FFFFFF", "#000000", "#FF0000", "#00FF00",
        "#0000FF", "#FFD700", "#FF69B4", "#00FFFF",
    ]

    var selectedBinding: Binding<TextOverlay>? {
        guard let id = selectedID,
              let index = overlays.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { self.overlays[index] },
            set: { self.overlays[index] = $0 }
        )
    }

    func addLayer() {
        let overlay = TextOverlay(
            text: "Text \(overlays.count + 1)",
            position: CGPoint(x: 0.5, y: 0.3 + Double(overlays.count) * 0.1)
        )
        overlays.append(overlay)
        selectedID = overlay.id
    }

    func removeSelected() {
        guard let id = selectedID else { return }
        overlays.removeAll { $0.id == id }
        selectedID = overlays.last?.id
    }
}
