import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

/// Color grading panel: preset LUT-style grades, manual color wheels, temperature/tint, before/after toggle.
struct ColorGradeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ColorGradeViewModel()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ENVITheme.Dark.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                    previewArea(containerHeight: geo.size.height)
                    presetStrip
                    manualControls
                }
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

            Text("COLOR")
                .font(.spaceMonoBold(17))
                .foregroundColor(.white)
                .tracking(-1)

            Spacer()

            // Before/After toggle
            Button {
                viewModel.showOriginal.toggle()
            } label: {
                Text(viewModel.showOriginal ? "BEFORE" : "AFTER")
                    .font(.spaceMonoBold(11))
                    .foregroundColor(.white.opacity(0.7))
                    .tracking(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: ENVIRadius.sm)
                            .fill(ENVITheme.Dark.surfaceHigh)
                    )
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
    }

    // MARK: - Preview

    private func previewArea(containerHeight: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .fill(ENVITheme.Dark.surfaceLow)

            if let image = viewModel.showOriginal ? viewModel.originalImage : viewModel.gradedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.2))
                    Text("No preview available")
                        .font(.interRegular(13))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: containerHeight * 0.32)
    }

    // MARK: - Preset Strip

    private var presetStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ColorGradePreset.presets) { preset in
                    Button {
                        viewModel.selectPreset(preset)
                    } label: {
                        VStack(spacing: 6) {
                            // Thumbnail circle
                            Circle()
                                .fill(preset.iconColor.opacity(0.6))
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Circle()
                                        .strokeBorder(
                                            viewModel.selectedPresetID == preset.id
                                                ? Color.white
                                                : Color.clear,
                                            lineWidth: 2
                                        )
                                )

                            Text(preset.name.uppercased())
                                .font(.spaceMonoBold(8))
                                .foregroundColor(
                                    viewModel.selectedPresetID == preset.id
                                        ? .white
                                        : .white.opacity(0.5)
                                )
                                .tracking(0.5)
                                .lineLimit(1)
                        }
                        .frame(width: 60)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Manual Controls

    private var manualControls: some View {
        VStack(spacing: 10) {
            // Color wheel section header
            HStack {
                Text("MANUAL ADJUSTMENTS")
                    .font(.spaceMonoBold(9))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(2)
                Spacer()
                Button("RESET") {
                    viewModel.resetManual()
                }
                .font(.spaceMonoBold(9))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1)
            }

            // Shadows / Midtones / Highlights wheels
            HStack(spacing: 16) {
                ColorWheelControl(label: "SHADOWS", hue: $viewModel.shadowHue, intensity: $viewModel.shadowIntensity)
                ColorWheelControl(label: "MIDTONES", hue: $viewModel.midtoneHue, intensity: $viewModel.midtoneIntensity)
                ColorWheelControl(label: "HIGHLIGHTS", hue: $viewModel.highlightHue, intensity: $viewModel.highlightIntensity)
            }

            // Temperature slider
            GradeSlider(label: "TEMP", value: $viewModel.temperature, range: -1...1, onChange: { viewModel.applyGrade() })

            // Tint slider
            GradeSlider(label: "TINT", value: $viewModel.tint, range: -1...1, onChange: { viewModel.applyGrade() })
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: ENVIRadius.xl)
                .fill(Color.black.opacity(0.9))
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - Color Wheel Control

private struct ColorWheelControl: View {
    let label: String
    @Binding var hue: Double
    @Binding var intensity: Double

    var body: some View {
        VStack(spacing: 6) {
            // Simplified color wheel as a hue ring
            ZStack {
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            gradient: Gradient(colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red]),
                            center: .center
                        ),
                        lineWidth: 6
                    )
                    .frame(width: 50, height: 50)

                // Indicator dot
                Circle()
                    .fill(Color(hue: hue, saturation: 0.8, brightness: 1.0))
                    .frame(width: 10, height: 10)
                    .offset(x: cos(hue * 2 * .pi - .pi / 2) * 20,
                            y: sin(hue * 2 * .pi - .pi / 2) * 20)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let center = CGPoint(x: 25, y: 25)
                        let angle = atan2(value.location.y - center.y, value.location.x - center.x)
                        hue = (Double(angle) / (2 * .pi) + 0.75).truncatingRemainder(dividingBy: 1.0)
                        let distance = hypot(value.location.x - center.x, value.location.y - center.y)
                        intensity = min(Double(distance / 25), 1.0)
                    }
            )

            Text(label)
                .font(.spaceMonoBold(7))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Grade Slider

private struct GradeSlider: View {
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
                .frame(width: 40, alignment: .leading)

            Slider(value: $value, in: range)
                .tint(.white)
                .onChange(of: value) { _, _ in onChange() }

            Text(String(format: "%+.1f", value))
                .font(.interRegular(11))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 34)
        }
    }
}

// MARK: - ViewModel

final class ColorGradeViewModel: ObservableObject {
    @Published var selectedPresetID: String = "original"
    @Published var showOriginal = false

    // Manual color wheel values
    @Published var shadowHue: Double = 0.6
    @Published var shadowIntensity: Double = 0
    @Published var midtoneHue: Double = 0.1
    @Published var midtoneIntensity: Double = 0
    @Published var highlightHue: Double = 0.15
    @Published var highlightIntensity: Double = 0

    // Temperature and tint
    @Published var temperature: Float = 0
    @Published var tint: Float = 0

    // Images
    @Published var originalImage: UIImage?
    @Published var gradedImage: UIImage?

    private let ciContext = CIContext()

    init() {
        // Load a default preview image
        if let img = UIImage(named: "studio-fashion") ?? UIImage(named: "runway") {
            originalImage = img
            gradedImage = img
        }
    }

    func selectPreset(_ preset: ColorGradePreset) {
        selectedPresetID = preset.id
        temperature = preset.temperature
        tint = preset.tint
        applyGrade(brightness: preset.brightness, contrast: preset.contrast, saturation: preset.saturation)
    }

    func applyGrade(brightness: Float? = nil, contrast: Float? = nil, saturation: Float? = nil) {
        guard let original = originalImage, let ciImage = CIImage(image: original) else { return }

        let preset = ColorGradePreset.presets.first { $0.id == selectedPresetID }

        let filter = CIFilter(name: "CIColorControls")!
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(brightness ?? preset?.brightness ?? 0, forKey: kCIInputBrightnessKey)
        filter.setValue(contrast ?? preset?.contrast ?? 1.0, forKey: kCIInputContrastKey)
        filter.setValue(saturation ?? preset?.saturation ?? 1.0, forKey: kCIInputSaturationKey)

        guard var output = filter.outputImage else { return }

        // Apply temperature/tint via CITemperatureAndTint
        let tempFilter = CIFilter(name: "CITemperatureAndTint")!
        let neutral = CIVector(x: CGFloat(6500 + temperature * 2000), y: 0)
        let targetNeutral = CIVector(x: CGFloat(6500), y: CGFloat(tint * 100))
        tempFilter.setValue(output, forKey: kCIInputImageKey)
        tempFilter.setValue(neutral, forKey: "inputNeutral")
        tempFilter.setValue(targetNeutral, forKey: "inputTargetNeutral")

        if let tempOutput = tempFilter.outputImage {
            output = tempOutput
        }

        if let cgImage = ciContext.createCGImage(output, from: output.extent) {
            gradedImage = UIImage(cgImage: cgImage)
        }
    }

    func resetManual() {
        shadowHue = 0.6; shadowIntensity = 0
        midtoneHue = 0.1; midtoneIntensity = 0
        highlightHue = 0.15; highlightIntensity = 0
        temperature = 0; tint = 0
        selectedPresetID = "original"
        gradedImage = originalImage
    }
}
