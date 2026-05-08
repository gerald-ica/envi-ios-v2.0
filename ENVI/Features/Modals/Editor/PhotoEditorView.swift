import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

/// Full-featured photo editor with adjustments, crop, text overlay, stickers, drawing, and export.
struct PhotoEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PhotoEditorViewModel()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ENVITheme.Dark.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                    photoPreview(containerHeight: geo.size.height)
                    toolSelector
                    activeToolPanel
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $viewModel.showExportSheet) {
            PhotoExportSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showTextOverlay) {
            TextOverlayView()
        }
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

            Text("EDIT PHOTO")
                .font(.spaceMonoBold(17))
                .foregroundColor(.white)
                .tracking(-1)

            Spacer()

            Button(action: { viewModel.showExportSheet = true }) {
                Text("EXPORT")
                    .font(.spaceMonoBold(13))
                    .foregroundColor(.black)
                    .tracking(1)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: ENVIRadius.lg)
                            .fill(Color.white)
                    )
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
    }

    // MARK: - Photo Preview

    private func photoPreview(containerHeight: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .fill(ENVITheme.Dark.surfaceLow)

            if let image = viewModel.editedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.2))
                    Text("Select a photo to edit")
                        .font(.interRegular(13))
                        .foregroundColor(.white.opacity(0.3))
                }
            }

            // Drawing overlay
            if viewModel.activeTool == .draw {
                PhotoDrawingOverlay(paths: $viewModel.drawingPaths, currentColor: viewModel.drawingColor, lineWidth: viewModel.drawingLineWidth)
            }

            // Sticker overlay
            ForEach($viewModel.stickers) { $sticker in
                DraggableStickerView(sticker: $sticker)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: containerHeight * 0.42)
    }

    // MARK: - Tool Selector

    private var toolSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(PhotoEditorTool.allCases, id: \.self) { tool in
                    Button {
                        viewModel.activeTool = tool
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tool.iconName)
                                .font(.system(size: 18))
                            Text(tool.displayName.uppercased())
                                .font(.spaceMonoBold(8))
                                .tracking(0.5)
                        }
                        .foregroundColor(viewModel.activeTool == tool ? .white : .white.opacity(0.4))
                        .frame(width: 60, height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: ENVIRadius.sm)
                                .fill(viewModel.activeTool == tool ? Color.white.opacity(0.12) : Color.clear)
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Active Tool Panel

    @ViewBuilder
    private var activeToolPanel: some View {
        VStack(spacing: 10) {
            switch viewModel.activeTool {
            case .adjust:
                adjustPanel
            case .crop:
                cropPanel
            case .text:
                textShortcutPanel
            case .sticker:
                stickerPanel
            case .draw:
                drawPanel
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

    // MARK: - Adjust Panel

    private var adjustPanel: some View {
        VStack(spacing: 10) {
            PhotoSliderRow(label: "BRIGHTNESS", value: $viewModel.brightness, range: -0.5...0.5, onChange: viewModel.applyAdjustments)
            PhotoSliderRow(label: "CONTRAST", value: $viewModel.contrast, range: 0.5...2.0, onChange: viewModel.applyAdjustments)
            PhotoSliderRow(label: "SATURATION", value: $viewModel.saturation, range: 0...2.0, onChange: viewModel.applyAdjustments)

            HStack {
                Spacer()
                Button("RESET") {
                    viewModel.resetAdjustments()
                }
                .font(.spaceMonoBold(9))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1)
            }
        }
    }

    // MARK: - Crop Panel

    private var cropPanel: some View {
        VStack(spacing: 10) {
            HStack {
                Text("CROP RATIO")
                    .font(.spaceMonoBold(9))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(2)
                Spacer()
            }

            HStack(spacing: 10) {
                ForEach(AspectRatio.allCases, id: \.self) { ratio in
                    Button {
                        viewModel.cropRatio = ratio
                    } label: {
                        Text(ratio.displayName)
                            .font(.spaceMonoBold(11))
                            .foregroundColor(viewModel.cropRatio == ratio ? .white : .white.opacity(0.4))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: ENVIRadius.sm)
                                    .fill(viewModel.cropRatio == ratio ? Color.white.opacity(0.15) : ENVITheme.Dark.surfaceHigh)
                            )
                    }
                }
            }

            Button {
                viewModel.applyCrop()
            } label: {
                Text("APPLY CROP")
                    .font(.spaceMonoBold(11))
                    .foregroundColor(.black)
                    .tracking(1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: ENVIRadius.lg)
                            .fill(Color.white)
                    )
            }
        }
    }

    // MARK: - Text Shortcut Panel

    private var textShortcutPanel: some View {
        VStack(spacing: 10) {
            Text("Add text overlays to your photo")
                .font(.interRegular(13))
                .foregroundColor(.white.opacity(0.5))

            Button {
                viewModel.showTextOverlay = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "textformat")
                    Text("OPEN TEXT EDITOR")
                        .font(.spaceMonoBold(11))
                        .tracking(1)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: ENVIRadius.lg)
                        .fill(ENVITheme.Dark.surfaceHigh)
                )
            }
        }
    }

    // MARK: - Sticker Panel

    private var stickerPanel: some View {
        VStack(spacing: 8) {
            HStack {
                Text("STICKERS & EMOJI")
                    .font(.spaceMonoBold(9))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(2)
                Spacer()
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                ForEach(PhotoEditorViewModel.emojiOptions, id: \.self) { emoji in
                    Button {
                        viewModel.addSticker(emoji)
                    } label: {
                        Text(emoji)
                            .font(.system(size: 28))
                    }
                }
            }
        }
    }

    // MARK: - Draw Panel

    private var drawPanel: some View {
        VStack(spacing: 10) {
            // Drawing tool selector
            HStack(spacing: 8) {
                ForEach([DrawingTool.pen, .highlighter, .eraser], id: \.self) { tool in
                    Button {
                        viewModel.drawingTool = tool
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: tool.iconName)
                                .font(.system(size: 16))
                            Text(tool.displayName.uppercased())
                                .font(.spaceMonoBold(7))
                                .tracking(0.5)
                        }
                        .foregroundColor(viewModel.drawingTool == tool ? .white : .white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: ENVIRadius.sm)
                                .fill(viewModel.drawingTool == tool ? Color.white.opacity(0.12) : Color.clear)
                        )
                    }
                }
            }

            // Color and size
            HStack(spacing: 8) {
                ForEach(["#FFFFFF", "#FF0000", "#00FF00", "#0000FF", "#FFD700", "#FF69B4"], id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white, lineWidth: viewModel.drawingColor == hex ? 2 : 0)
                        )
                        .onTapGesture { viewModel.drawingColor = hex }
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("SIZE")
                        .font(.spaceMonoBold(8))
                        .foregroundColor(.white.opacity(0.4))
                    Slider(value: $viewModel.drawingLineWidth, in: 1...20)
                        .tint(.white)
                        .frame(width: 80)
                }
            }

            // Undo/clear
            HStack {
                Button {
                    viewModel.undoLastPath()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("UNDO")
                            .font(.spaceMonoBold(9))
                            .tracking(1)
                    }
                    .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                Button {
                    viewModel.clearDrawing()
                } label: {
                    Text("CLEAR ALL")
                        .font(.spaceMonoBold(9))
                        .foregroundColor(.red.opacity(0.6))
                        .tracking(1)
                }
            }
        }
    }
}

// MARK: - Photo Editor Tools

enum PhotoEditorTool: String, CaseIterable {
    case adjust, crop, text, sticker, draw

    var displayName: String {
        rawValue.capitalized
    }

    var iconName: String {
        switch self {
        case .adjust:  return "slider.horizontal.3"
        case .crop:    return "crop"
        case .text:    return "textformat"
        case .sticker: return "face.smiling"
        case .draw:    return "pencil.tip"
        }
    }
}

// MARK: - Slider Row

private struct PhotoSliderRow: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let onChange: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.spaceMonoBold(9))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1)
                .frame(width: 80, alignment: .leading)

            Slider(value: $value, in: range)
                .tint(.white)
                .onChange(of: value) { _, _ in onChange() }

            Text(String(format: "%.2f", value))
                .font(.interRegular(11))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 36)
        }
    }
}

// MARK: - Drawing Overlay

struct PhotoDrawingOverlay: View {
    @Binding var paths: [DrawingPath]
    let currentColor: String
    let lineWidth: CGFloat

    @State private var currentPoints: [CGPoint] = []

    var body: some View {
        Canvas { context, _ in
            for path in paths {
                var bezier = Path()
                guard let first = path.points.first else { continue }
                bezier.move(to: first)
                for point in path.points.dropFirst() {
                    bezier.addLine(to: point)
                }
                context.stroke(
                    bezier,
                    with: .color(Color(hex: path.color)),
                    lineWidth: path.lineWidth
                )
            }

            // Current stroke
            if !currentPoints.isEmpty {
                var bezier = Path()
                bezier.move(to: currentPoints[0])
                for point in currentPoints.dropFirst() {
                    bezier.addLine(to: point)
                }
                context.stroke(
                    bezier,
                    with: .color(Color(hex: currentColor)),
                    lineWidth: lineWidth
                )
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    currentPoints.append(value.location)
                }
                .onEnded { _ in
                    let newPath = DrawingPath(points: currentPoints, color: currentColor, lineWidth: lineWidth)
                    paths.append(newPath)
                    currentPoints = []
                }
        )
        .allowsHitTesting(true)
    }
}

/// A single drawn path with color and width.
struct DrawingPath: Identifiable {
    let id = UUID()
    let points: [CGPoint]
    let color: String
    let lineWidth: CGFloat
}

// MARK: - Draggable Sticker

struct StickerItem: Identifiable {
    let id = UUID()
    var emoji: String
    var position: CGPoint
    var scale: CGFloat
}

private struct DraggableStickerView: View {
    @Binding var sticker: StickerItem
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        Text(sticker.emoji)
            .font(.system(size: 40 * sticker.scale))
            .position(
                x: sticker.position.x + dragOffset.width,
                y: sticker.position.y + dragOffset.height
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        sticker.position.x += value.translation.width
                        sticker.position.y += value.translation.height
                        dragOffset = .zero
                    }
            )
            .gesture(
                MagnificationGesture()
                    .onChanged { scale in
                        sticker.scale = max(0.5, min(scale, 3.0))
                    }
            )
    }
}

// MARK: - Photo Export Sheet

private struct PhotoExportSheet: View {
    @ObservedObject var viewModel: PhotoEditorViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            ENVITheme.Dark.background.ignoresSafeArea()

            VStack(spacing: 16) {
                HStack {
                    Text("EXPORT PHOTO")
                        .font(.spaceMonoBold(17))
                        .foregroundColor(.white)
                        .tracking(-1)
                    Spacer()
                    Button("Done") { dismiss() }
                        .font(.spaceMonoBold(14))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                VStack(spacing: 8) {
                    HStack {
                        Text("FORMAT")
                            .font(.spaceMonoBold(9))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(2)
                        Spacer()
                    }

                    HStack(spacing: 10) {
                        ForEach(PhotoExportFormat.allCases, id: \.self) { format in
                            Button {
                                viewModel.exportFormat = format
                            } label: {
                                Text(format.displayName)
                                    .font(.spaceMonoBold(13))
                                    .foregroundColor(viewModel.exportFormat == format ? .white : .white.opacity(0.4))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: ENVIRadius.sm)
                                            .fill(viewModel.exportFormat == format
                                                  ? Color.white.opacity(0.15)
                                                  : ENVITheme.Dark.surfaceLow)
                                    )
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)

                Button {
                    viewModel.exportPhoto()
                    dismiss()
                } label: {
                    Text("SAVE TO PHOTOS")
                        .font(.spaceMonoBold(13))
                        .foregroundColor(.black)
                        .tracking(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                                .fill(Color.white)
                        )
                }
                .padding(.horizontal, 16)

                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - ViewModel

final class PhotoEditorViewModel: ObservableObject {
    @Published var activeTool: PhotoEditorTool = .adjust
    @Published var editedImage: UIImage?
    @Published var showExportSheet = false
    @Published var showTextOverlay = false
    @Published var exportFormat: PhotoExportFormat = .jpeg

    // Adjust
    @Published var brightness: Float = 0
    @Published var contrast: Float = 1.0
    @Published var saturation: Float = 1.0

    // Crop
    @Published var cropRatio: AspectRatio = .square1x1

    // Stickers
    @Published var stickers: [StickerItem] = []

    // Drawing
    @Published var drawingPaths: [DrawingPath] = []
    @Published var drawingTool: DrawingTool = .pen
    @Published var drawingColor: String = "#FFFFFF"
    @Published var drawingLineWidth: CGFloat = 3

    private var originalImage: UIImage?
    private let ciContext = CIContext()

    static let emojiOptions = [
        "\u{2764}\u{FE0F}", "\u{1F525}", "\u{2728}", "\u{1F60E}",
        "\u{1F3A8}", "\u{1F4F8}", "\u{1F31F}", "\u{1F44D}",
        "\u{1F389}", "\u{1F4A1}", "\u{1F3AC}", "\u{1F680}",
        "\u{1F308}", "\u{1F4AB}", "\u{1F3B5}", "\u{1F48E}",
    ]

    init() {
        if let img = UIImage(named: "card-graphic") ?? UIImage(named: "runway") {
            originalImage = img
            editedImage = img
        }
    }

    func applyAdjustments() {
        guard let original = originalImage, let ciImage = CIImage(image: original) else { return }

        let filter = CIFilter(name: "CIColorControls")!
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(brightness, forKey: kCIInputBrightnessKey)
        filter.setValue(contrast, forKey: kCIInputContrastKey)
        filter.setValue(saturation, forKey: kCIInputSaturationKey)

        if let output = filter.outputImage,
           let cgImage = ciContext.createCGImage(output, from: output.extent) {
            editedImage = UIImage(cgImage: cgImage)
        }
    }

    func resetAdjustments() {
        brightness = 0; contrast = 1.0; saturation = 1.0
        editedImage = originalImage
    }

    func applyCrop() {
        guard let image = editedImage else { return }
        let size = image.size
        let targetRatio = cropRatio.ratio
        let currentRatio = size.width / size.height

        var cropRect: CGRect
        if currentRatio > targetRatio {
            let newWidth = size.height * targetRatio
            cropRect = CGRect(x: (size.width - newWidth) / 2, y: 0, width: newWidth, height: size.height)
        } else {
            let newHeight = size.width / targetRatio
            cropRect = CGRect(x: 0, y: (size.height - newHeight) / 2, width: size.width, height: newHeight)
        }

        if let cgImage = image.cgImage?.cropping(to: cropRect) {
            editedImage = UIImage(cgImage: cgImage)
            originalImage = editedImage
        }
    }

    func addSticker(_ emoji: String) {
        let sticker = StickerItem(
            emoji: emoji,
            position: CGPoint(x: 140 + CGFloat.random(in: -40...40), y: 200 + CGFloat.random(in: -40...40)),
            scale: 1.0
        )
        stickers.append(sticker)
    }

    func undoLastPath() {
        guard !drawingPaths.isEmpty else { return }
        drawingPaths.removeLast()
    }

    func clearDrawing() {
        drawingPaths.removeAll()
    }

    func exportPhoto() {
        guard let image = editedImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
}
