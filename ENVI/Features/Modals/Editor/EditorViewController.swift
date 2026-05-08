import UIKit
import SwiftUI
import AVFoundation
import CoreImage

/// UIKit-based video editor with preview, timeline, and toolbar.
final class EditorViewController: UIViewController {

    private let viewModel = EditorViewModel()
    private let contentItem: ContentItem?
    private let contentPiece: ContentPiece?
    private lazy var exportComposer = ExportComposerFactory.make(contentItem: contentItem, contentPiece: contentPiece)
    private var isPreviewPlaying = false
    private nonisolated(unsafe) let videoEditService = VideoEditService()
    private var latestTrimmedVideoURL: URL?

    // MARK: - Editor Tool State
    private var currentFilterIndex = 0
    private var currentSpeedMultiplier: Float = 1.0
    private var currentRotationAngle: CGFloat = 0
    private var isCroppedToSquare = false

    // MARK: - Adjust Panel State
    private var adjustPanel: UIView?
    private var adjustBrightness: Float = 0
    private var adjustContrast: Float = 1.0
    private var adjustSaturation: Float = 1.0
    private var originalPreviewImage: UIImage?

    // MARK: - Timeline State
    private var timelineContainer: UIView?
    private var playheadView: UIView?
    private var scrubPosition: CGFloat = 0
    private var player: AVPlayer?

    // MARK: - Top Toolbar
    private let topBar: UIView = {
        let v = UIView()
        v.backgroundColor = ENVITheme.UIKit.backgroundDark
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let backButton: UIButton = {
        let b = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        b.setImage(UIImage(systemName: "chevron.left", withConfiguration: config), for: .normal)
        b.tintColor = .white
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "EDIT"
        l.font = .spaceMonoBold(17)
        l.textColor = .white
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let exportButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "EXPORT"
        config.baseBackgroundColor = .white
        config.baseForegroundColor = .black
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        let b = UIButton(configuration: config)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    // MARK: - Preview Area
    private let previewView: UIView = {
        let v = UIView()
        v.backgroundColor = ENVITheme.UIKit.surfaceLowDark
        v.layer.cornerRadius = ENVIRadius.lg
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let textPreviewLabel: UILabel = {
        let label = UILabel()
        label.font = .interRegular(18)
        label.textColor = .white
        label.numberOfLines = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let playButton: UIButton = {
        let b = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 36, weight: .medium)
        b.setImage(UIImage(systemName: "play.circle", withConfiguration: config), for: .normal)
        b.tintColor = .white
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    init(contentItem: ContentItem? = nil, contentPiece: ContentPiece? = nil) {
        self.contentItem = contentItem
        self.contentPiece = contentPiece
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ENVITheme.UIKit.backgroundDark
        titleLabel.text = editorTitle
        setupTopBar()
        setupPreview()
        setupTimeline()
        setupToolbar()
    }

    private func setupTopBar() {
        view.addSubview(topBar)
        topBar.addSubview(backButton)
        topBar.addSubview(titleLabel)
        topBar.addSubview(exportButton)

        backButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        exportButton.addTarget(self, action: #selector(showExport), for: .touchUpInside)

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 48),

            backButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 16),
            backButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            titleLabel.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            exportButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -16),
            exportButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
        ])
    }

    private func setupPreview() {
        view.addSubview(previewView)
        previewView.addSubview(playButton)
        previewView.addSubview(textPreviewLabel)

        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        previewView.insertSubview(imageView, at: 0)

        // Load preview from content item or content piece
        let preview = previewImage()
        if let image = preview {
            imageView.image = image
            originalPreviewImage = image
        } else if let pieceImageName = contentPiece?.imageName {
            Task { [weak imageView] in
                guard let mediaThumbnail = await Self.loadContentPieceThumbnail(imageName: pieceImageName) else {
                    return
                }
                await MainActor.run { [weak self, weak imageView] in
                    guard let self, let imageView else { return }
                    imageView.image = mediaThumbnail
                    self.originalPreviewImage = mediaThumbnail
                }
            }
        }

        // Gradient overlay for contrast against controls
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.4).cgColor
        ]
        gradientLayer.locations = [0.6, 1.0]
        let gradientView = UIView()
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        gradientView.isUserInteractionEnabled = false
        gradientView.layer.addSublayer(gradientLayer)
        previewView.insertSubview(gradientView, aboveSubview: imageView)
        // Size gradient layer on layout
        gradientView.layoutIfNeeded()
        DispatchQueue.main.async {
            gradientLayer.frame = gradientView.bounds
        }

        if isTextEditingContext {
            imageView.isHidden = true
            playButton.isHidden = true
            textPreviewLabel.isHidden = false
            textPreviewLabel.text = contentItem?.bodyText ?? contentItem?.caption ?? contentPiece?.description
        } else {
            textPreviewLabel.isHidden = true
            playButton.isHidden = false
            playButton.addTarget(self, action: #selector(togglePreviewPlayback), for: .touchUpInside)
        }

        NSLayoutConstraint.activate([
            previewView.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 12),
            previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            previewView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.45),

            imageView.topAnchor.constraint(equalTo: previewView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: previewView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: previewView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: previewView.trailingAnchor),

            gradientView.topAnchor.constraint(equalTo: previewView.topAnchor),
            gradientView.bottomAnchor.constraint(equalTo: previewView.bottomAnchor),
            gradientView.leadingAnchor.constraint(equalTo: previewView.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: previewView.trailingAnchor),

            playButton.centerXAnchor.constraint(equalTo: previewView.centerXAnchor),
            playButton.centerYAnchor.constraint(equalTo: previewView.centerYAnchor),

            textPreviewLabel.leadingAnchor.constraint(equalTo: previewView.leadingAnchor, constant: 20),
            textPreviewLabel.trailingAnchor.constraint(equalTo: previewView.trailingAnchor, constant: -20),
            textPreviewLabel.centerYAnchor.constraint(equalTo: previewView.centerYAnchor),
        ])
    }

    private func setupTimeline() {
        // Interactive timeline with scrubbing and playhead
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.clipsToBounds = true
        view.addSubview(container)
        self.timelineContainer = container

        let timelineLabel = UILabel()
        timelineLabel.text = "Timeline"
        timelineLabel.font = .spaceMono(11)
        timelineLabel.textColor = ENVITheme.UIKit.textLightDark
        timelineLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(timelineLabel)

        // Playhead indicator
        let playhead = UIView()
        playhead.backgroundColor = .white
        playhead.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(playhead)
        self.playheadView = playhead

        // Track lanes
        let tracks = ["V1", "A1", "T1", "FX"]
        var previousAnchor = container.topAnchor
        var topOffset: CGFloat = 20
        for (index, trackName) in tracks.enumerated() {
            let track = createTrackView(name: trackName)
            container.addSubview(track)
            NSLayoutConstraint.activate([
                track.topAnchor.constraint(equalTo: previousAnchor, constant: index == 0 ? topOffset : 4),
                track.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
                track.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                track.heightAnchor.constraint(equalToConstant: 28),
            ])
            previousAnchor = track.bottomAnchor
            topOffset = 4

            // Label
            let label = UILabel()
            label.text = trackName
            label.font = .spaceMonoBold(9)
            label.textColor = ENVITheme.UIKit.textLightDark
            label.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerYAnchor.constraint(equalTo: track.centerYAnchor),
                label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            ])
        }

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: previewView.bottomAnchor, constant: 12),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            container.heightAnchor.constraint(equalToConstant: 148),

            timelineLabel.topAnchor.constraint(equalTo: container.topAnchor),
            timelineLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),

            playhead.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            playhead.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            playhead.widthAnchor.constraint(equalToConstant: 2),
            playhead.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
        ])

        // Pan gesture for scrubbing
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleTimelineScrub(_:)))
        container.addGestureRecognizer(panGesture)

        // Bring playhead to front so it renders above tracks
        container.bringSubviewToFront(playhead)
    }

    private func createTrackView(name: String) -> UIView {
        let v = UIView()
        v.backgroundColor = ENVITheme.UIKit.surfaceLowDark
        v.layer.cornerRadius = 4
        v.translatesAutoresizingMaskIntoConstraints = false

        // Clip indicator
        let clip = UIView()
        clip.backgroundColor = UIColor.white.withAlphaComponent(0.4)
        clip.layer.cornerRadius = 3
        clip.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(clip)

        NSLayoutConstraint.activate([
            clip.topAnchor.constraint(equalTo: v.topAnchor, constant: 2),
            clip.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -2),
            clip.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 4),
            clip.widthAnchor.constraint(equalTo: v.widthAnchor, multiplier: 0.7),
        ])

        return v
    }

    private func setupToolbar() {
        let toolStack = UIStackView()
        toolStack.axis = .horizontal
        toolStack.distribution = .fillEqually
        toolStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolStack)

        let tools = zip(viewModel.tools, viewModel.toolIcons)
        for (index, (title, icon)) in tools.enumerated() {
            let symConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
            var btnConfig = UIButton.Configuration.plain()
            btnConfig.image = UIImage(systemName: icon, withConfiguration: symConfig)
            btnConfig.title = title
            btnConfig.imagePlacement = .top
            btnConfig.imagePadding = 4
            btnConfig.baseForegroundColor = ENVITheme.UIKit.textLightDark

            let button = UIButton(configuration: btnConfig)
            button.tag = index
            button.addTarget(self, action: #selector(toolTapped(_:)), for: .touchUpInside)
            toolStack.addArrangedSubview(button)
        }

        NSLayoutConstraint.activate([
            toolStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            toolStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolStack.heightAnchor.constraint(equalToConstant: 60),
        ])
    }

    @objc private func togglePreviewPlayback() {
        isPreviewPlaying.toggle()
        let symbolName = isPreviewPlaying ? "pause.circle" : "play.circle"
        let config = UIImage.SymbolConfiguration(pointSize: 36, weight: .medium)
        playButton.setImage(UIImage(systemName: symbolName, withConfiguration: config), for: .normal)
    }

    @objc private func goBack() {
        if let navigationController, navigationController.viewControllers.count > 1 {
            navigationController.popViewController(animated: true)
            return
        }

        dismiss(animated: true)
    }

    @objc private func showExport() {
        let exportView = ExportSheetView(composer: exportComposer)
        let hostingController = UIHostingController(rootView: exportView)
        hostingController.modalPresentationStyle = .pageSheet
        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(hostingController, animated: true)
    }

    @objc private func toolTapped(_ sender: UIButton) {
        guard sender.tag < viewModel.tools.count else { return }
        let tool = viewModel.tools[sender.tag]

        switch tool {
        case "Trim":
            Task { await performQuickTrim() }
        case "Crop":
            performCrop()
        case "Filters":
            performFilterCycle()
        case "Speed":
            performSpeedToggle()
        case "Rotate":
            performRotate()
        case "Adjust":
            showAdjustPanel()
        case "Text":
            presentTextOverlay()
        case "Audio":
            presentAudioMixer()
        case "Color":
            presentColorGrade()
        case "Ratio":
            presentAspectRatioPicker()
        default:
            presentAlert(
                title: tool,
                message: "This tool is not yet available."
            )
        }
    }

    private func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Crop (1:1 center crop)

    private func performCrop() {
        isCroppedToSquare.toggle()

        if isCroppedToSquare {
            // Apply center-crop to 1:1 by masking the preview view
            let side = min(previewView.bounds.width, previewView.bounds.height)
            let maskLayer = CALayer()
            maskLayer.backgroundColor = UIColor.white.cgColor
            maskLayer.frame = CGRect(
                x: (previewView.bounds.width - side) / 2,
                y: (previewView.bounds.height - side) / 2,
                width: side,
                height: side
            )
            maskLayer.cornerRadius = ENVIRadius.lg
            previewView.layer.mask = maskLayer
            showHUD("Crop: 1:1")
        } else {
            previewView.layer.mask = nil
            showHUD("Crop: Original")
        }
    }

    /// Applies 1:1 center crop to a video asset using AVVideoComposition.Configuration.
    private func applyCropToAsset(_ asset: AVAsset) async throws -> AVVideoComposition {
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = tracks.first else {
            throw VideoEditService.EditError.exportSessionUnavailable
        }
        let naturalSize = try await videoTrack.load(.naturalSize)
        let side = min(naturalSize.width, naturalSize.height)
        let cropOrigin = CGPoint(
            x: (naturalSize.width - side) / 2,
            y: (naturalSize.height - side) / 2
        )

        let duration = try await asset.load(.duration)
        var layerConfig = AVVideoCompositionLayerInstruction.Configuration(assetTrack: videoTrack)
        let transform = CGAffineTransform(translationX: -cropOrigin.x, y: -cropOrigin.y)
        layerConfig.setTransform(transform, at: .zero)

        let instructionConfig = AVVideoCompositionInstruction.Configuration(
            layerInstructions: [AVVideoCompositionLayerInstruction(configuration: layerConfig)],
            timeRange: CMTimeRange(start: .zero, duration: duration)
        )
        let instruction = AVVideoCompositionInstruction(configuration: instructionConfig)

        let compositionConfig = AVVideoComposition.Configuration(
            frameDuration: CMTime(value: 1, timescale: 30),
            instructions: [instruction],
            renderSize: CGSize(width: side, height: side)
        )
        return AVVideoComposition(configuration: compositionConfig)
    }

    // MARK: - Filter (cycle through presets)

    private struct FilterPreset {
        let name: String
        let brightness: Float
        let contrast: Float
        let saturation: Float
    }

    private static let filterPresets: [FilterPreset] = [
        FilterPreset(name: "Original", brightness: 0, contrast: 1.0, saturation: 1.0),
        FilterPreset(name: "High Contrast", brightness: 0.05, contrast: 1.4, saturation: 1.1),
        FilterPreset(name: "Warm Tone", brightness: 0.08, contrast: 1.1, saturation: 1.35),
    ]

    private func performFilterCycle() {
        currentFilterIndex = (currentFilterIndex + 1) % Self.filterPresets.count
        let preset = Self.filterPresets[currentFilterIndex]

        // Apply CIFilter to the preview image view
        if let imageView = previewView.subviews.compactMap({ $0 as? UIImageView }).first,
           let originalImage = imageView.image,
           let ciImage = CIImage(image: originalImage) {

            let filter = CIFilter(name: "CIColorControls")!
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(preset.brightness, forKey: kCIInputBrightnessKey)
            filter.setValue(preset.contrast, forKey: kCIInputContrastKey)
            filter.setValue(preset.saturation, forKey: kCIInputSaturationKey)

            if let output = filter.outputImage {
                let context = CIContext()
                if let cgImage = context.createCGImage(output, from: output.extent) {
                    imageView.image = UIImage(cgImage: cgImage)
                }
            }
        }

        showHUD("Filter: \(preset.name)")
    }

    /// Builds a CIFilter-based AVVideoComposition for export.
    private func applyFilterToAsset(_ asset: AVAsset) async throws -> AVVideoComposition {
        let preset = Self.filterPresets[currentFilterIndex]
        return try await AVVideoComposition(applyingFiltersTo: asset) { request in
            let filter = CIFilter(name: "CIColorControls")!
            filter.setValue(request.sourceImage.clampedToExtent(), forKey: kCIInputImageKey)
            filter.setValue(preset.brightness, forKey: kCIInputBrightnessKey)
            filter.setValue(preset.contrast, forKey: kCIInputContrastKey)
            filter.setValue(preset.saturation, forKey: kCIInputSaturationKey)

            let outputImage = filter.outputImage?.cropped(to: request.sourceImage.extent) ?? request.sourceImage
            return AVCIImageFilteringResult(resultImage: outputImage)
        }
    }

    // MARK: - Speed (toggle 1x / 0.5x / 2x)

    private func performSpeedToggle() {
        switch currentSpeedMultiplier {
        case 1.0:
            currentSpeedMultiplier = 0.5
        case 0.5:
            currentSpeedMultiplier = 2.0
        default:
            currentSpeedMultiplier = 1.0
        }
        showHUD("Speed: \(currentSpeedMultiplier == 1.0 ? "1x" : currentSpeedMultiplier == 0.5 ? "0.5x" : "2x")")
    }

    /// Applies speed change to an AVMutableComposition track via scaleTimeRange.
    private func applySpeedToComposition(_ composition: AVMutableComposition, asset: AVAsset) async throws {
        let duration = try await asset.load(.duration)
        let timeRange = CMTimeRange(start: .zero, duration: duration)
        let scaledDuration = CMTimeMultiplyByFloat64(duration, multiplier: Float64(1.0 / currentSpeedMultiplier))

        for track in composition.tracks {
            track.scaleTimeRange(timeRange, toDuration: scaledDuration)
        }
    }

    // MARK: - Rotate (90 degrees clockwise each tap)

    private func performRotate() {
        currentRotationAngle += 90
        if currentRotationAngle >= 360 { currentRotationAngle = 0 }

        let radians = currentRotationAngle * .pi / 180
        UIView.animate(withDuration: 0.3) {
            self.previewView.transform = CGAffineTransform(rotationAngle: radians)
        }

        let label = currentRotationAngle == 0 ? "0 (Original)" : "\(Int(currentRotationAngle))"
        showHUD("Rotate: \(label)")
    }

    /// Builds a rotation transform for export via AVVideoCompositionLayerInstruction.Configuration.
    private func applyRotationToAsset(_ asset: AVAsset) async throws -> AVVideoComposition {
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = tracks.first else {
            throw VideoEditService.EditError.exportSessionUnavailable
        }
        let naturalSize = try await videoTrack.load(.naturalSize)
        let isLandscapeRotation = Int(currentRotationAngle) % 180 != 0
        let renderSize: CGSize
        if isLandscapeRotation {
            renderSize = CGSize(width: naturalSize.height, height: naturalSize.width)
        } else {
            renderSize = naturalSize
        }

        let duration = try await asset.load(.duration)
        var layerConfig = AVVideoCompositionLayerInstruction.Configuration(assetTrack: videoTrack)
        var transform = CGAffineTransform.identity
        switch Int(currentRotationAngle) {
        case 90:
            transform = transform.translatedBy(x: naturalSize.height, y: 0)
                .rotated(by: .pi / 2)
        case 180:
            transform = transform.translatedBy(x: naturalSize.width, y: naturalSize.height)
                .rotated(by: .pi)
        case 270:
            transform = transform.translatedBy(x: 0, y: naturalSize.width)
                .rotated(by: .pi * 3 / 2)
        default:
            break
        }
        layerConfig.setTransform(transform, at: .zero)

        let instructionConfig = AVVideoCompositionInstruction.Configuration(
            layerInstructions: [AVVideoCompositionLayerInstruction(configuration: layerConfig)],
            timeRange: CMTimeRange(start: .zero, duration: duration)
        )
        let instruction = AVVideoCompositionInstruction(configuration: instructionConfig)

        let compositionConfig = AVVideoComposition.Configuration(
            frameDuration: CMTime(value: 1, timescale: 30),
            instructions: [instruction],
            renderSize: renderSize
        )
        return AVVideoComposition(configuration: compositionConfig)
    }

    // MARK: - HUD Toast

    private func showHUD(_ message: String) {
        let hudLabel = UILabel()
        hudLabel.text = message
        hudLabel.font = .spaceMonoBold(13)
        hudLabel.textColor = .white
        hudLabel.textAlignment = .center
        hudLabel.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        hudLabel.layer.cornerRadius = 8
        hudLabel.clipsToBounds = true
        hudLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(hudLabel)
        NSLayoutConstraint.activate([
            hudLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hudLabel.topAnchor.constraint(equalTo: previewView.bottomAnchor, constant: 8),
            hudLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            hudLabel.heightAnchor.constraint(equalToConstant: 32),
        ])
        // Add padding via content insets
        hudLabel.layoutMargins = UIEdgeInsets(top: 4, left: 12, bottom: 4, right: 12)

        UIView.animate(withDuration: 0.3, delay: 1.2, options: .curveEaseOut) {
            hudLabel.alpha = 0
        } completion: { _ in
            hudLabel.removeFromSuperview()
        }
    }

    @MainActor
    private func performQuickTrim() async {
        guard let sourceURL = resolveSourceVideoURL() else {
            presentAlert(
                title: "Trim",
                message: "No source video is available for trimming in this context."
            )
            return
        }

        do {
            let outputURL = try await videoEditService.trimVideo(
                sourceURL: sourceURL,
                startTime: 0,
                endTime: min(8, 30)
            )
            latestTrimmedVideoURL = outputURL
            presentAlert(
                title: "Trim Complete",
                message: "Created trimmed clip: \(outputURL.lastPathComponent)"
            )
        } catch {
            presentAlert(
                title: "Trim Failed",
                message: "Could not trim video: \(error.localizedDescription)"
            )
        }
    }

    private func resolveSourceVideoURL() -> URL? {
        if let latestTrimmedVideoURL {
            return latestTrimmedVideoURL
        }

        let candidateNames: [String] = [
            contentItem?.imageName,
            contentPiece?.imageName,
            "preview"
        ].compactMap { $0 }

        for baseName in candidateNames {
            if let url = Bundle.main.url(forResource: baseName, withExtension: "mp4") {
                return url
            }
            if let url = Bundle.main.url(forResource: baseName, withExtension: "mov") {
                return url
            }
        }
        return nil
    }

    private func previewImage() -> UIImage? {
        guard let imageName = contentItem?.imageName ?? contentPiece?.imageName else {
            return loadImage(named: "runway") ?? loadImage(named: "card-graphic")
        }

        return loadImage(named: imageName)
    }

    private var editorTitle: String {
        if let contentItem {
            switch contentItem.platform {
            case .x:
                return "EDIT TWEET"
            case .threads:
                return "EDIT THREAD"
            default:
                return "EDIT"
            }
        }

        guard let contentPiece else { return "EDIT" }
        switch contentPiece.type {
        case .carousel:
            return "EDIT CAROUSEL"
        case .photo, .story:
            return "EDIT PHOTO"
        case .video, .reel:
            return "EDIT VIDEO"
        }
    }

    private var isTextEditingContext: Bool {
        contentItem?.type == .textPost
    }

    private func loadImage(named imageName: String) -> UIImage? {
        if let image = UIImage(named: imageName) {
            return image
        }

        if let resourceBundle = Bundle.main.url(forResource: "ENVI_ENVI", withExtension: "bundle").flatMap(Bundle.init(url:)) {
            if let image = UIImage(named: imageName, in: resourceBundle, compatibleWith: nil) {
                return image
            }

            let bundledPath = resourceBundle.path(forResource: imageName, ofType: "jpg")
                ?? resourceBundle.path(forResource: imageName, ofType: "png")
            if let bundledPath {
                return UIImage(contentsOfFile: bundledPath)
            }
        }

        let resourcePath = Bundle.main.path(forResource: imageName, ofType: "jpg")
            ?? Bundle.main.path(forResource: imageName, ofType: "png")
        guard let resourcePath else { return nil }
        return UIImage(contentsOfFile: resourcePath)
    }

    /// Attempts to generate a thumbnail from a content piece's video media.
    private static func loadContentPieceThumbnail(imageName: String?) async -> UIImage? {
        guard let imageName else { return nil }

        for ext in ["mp4", "mov"] {
            if let url = Bundle.main.url(forResource: imageName, withExtension: ext) {
                let asset = AVURLAsset(url: url)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: 600, height: 600)
                do {
                    let frame = try await generator.image(at: .zero)
                    return UIImage(cgImage: frame.image)
                } catch {
                    continue
                }
            }
        }
        return nil
    }

    // MARK: - Adjust Panel

    private func showAdjustPanel() {
        // Dismiss if already showing
        if let existing = adjustPanel {
            existing.removeFromSuperview()
            adjustPanel = nil
            return
        }

        // Store original image for live adjustment
        if originalPreviewImage == nil,
           let imageView = previewView.subviews.compactMap({ $0 as? UIImageView }).first {
            originalPreviewImage = imageView.image
        }

        let panel = UIView()
        panel.backgroundColor = UIColor.black.withAlphaComponent(0.9)
        panel.layer.cornerRadius = ENVIRadius.lg
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)
        self.adjustPanel = panel

        // Done button
        let doneButton = UIButton(type: .system)
        doneButton.setTitle("Done", for: .normal)
        doneButton.titleLabel?.font = .spaceMonoBold(14)
        doneButton.tintColor = .white
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.addTarget(self, action: #selector(dismissAdjustPanel), for: .touchUpInside)
        panel.addSubview(doneButton)

        // Slider rows
        let brightnessRow = makeAdjustSlider(label: "Brightness", min: -0.5, max: 0.5, value: adjustBrightness, tag: 0)
        let contrastRow = makeAdjustSlider(label: "Contrast", min: 0.5, max: 2.0, value: adjustContrast, tag: 1)
        let saturationRow = makeAdjustSlider(label: "Saturation", min: 0.0, max: 2.0, value: adjustSaturation, tag: 2)

        let stack = UIStackView(arrangedSubviews: [brightnessRow, contrastRow, saturationRow])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(stack)

        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            panel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            panel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -72),
            panel.heightAnchor.constraint(equalToConstant: 180),

            doneButton.topAnchor.constraint(equalTo: panel.topAnchor, constant: 8),
            doneButton.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12),

            stack.topAnchor.constraint(equalTo: doneButton.bottomAnchor, constant: 4),
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16),
        ])
    }

    private func makeAdjustSlider(label: String, min: Float, max: Float, value: Float, tag: Int) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = UILabel()
        nameLabel.text = label
        nameLabel.font = .spaceMono(11)
        nameLabel.textColor = ENVITheme.UIKit.textLightDark
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.setContentHuggingPriority(.required, for: .horizontal)
        row.addSubview(nameLabel)

        let slider = UISlider()
        slider.minimumValue = min
        slider.maximumValue = max
        slider.value = value
        slider.tintColor = .white
        slider.tag = tag
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.addTarget(self, action: #selector(adjustSliderChanged(_:)), for: .valueChanged)
        row.addSubview(slider)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 32),
            nameLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            nameLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            nameLabel.widthAnchor.constraint(equalToConstant: 80),
            slider.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
            slider.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            slider.centerYAnchor.constraint(equalTo: row.centerYAnchor),
        ])

        return row
    }

    @objc private func adjustSliderChanged(_ sender: UISlider) {
        switch sender.tag {
        case 0: adjustBrightness = sender.value
        case 1: adjustContrast = sender.value
        case 2: adjustSaturation = sender.value
        default: break
        }
        applyAdjustments()
    }

    private func applyAdjustments() {
        guard let imageView = previewView.subviews.compactMap({ $0 as? UIImageView }).first,
              let original = originalPreviewImage,
              let ciImage = CIImage(image: original) else { return }

        let filter = CIFilter(name: "CIColorControls")!
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(adjustBrightness, forKey: kCIInputBrightnessKey)
        filter.setValue(adjustContrast, forKey: kCIInputContrastKey)
        filter.setValue(adjustSaturation, forKey: kCIInputSaturationKey)

        if let output = filter.outputImage {
            let context = CIContext()
            if let cgImage = context.createCGImage(output, from: output.extent) {
                imageView.image = UIImage(cgImage: cgImage)
            }
        }
    }

    @objc private func dismissAdjustPanel() {
        adjustPanel?.removeFromSuperview()
        adjustPanel = nil
    }

    // MARK: - New Editor Panels

    private func presentTextOverlay() {
        let textView = TextOverlayView()
        let host = UIHostingController(rootView: textView)
        host.modalPresentationStyle = .pageSheet
        if let sheet = host.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(host, animated: true)
    }

    private func presentAudioMixer() {
        let audioView = AudioMixerView()
        let host = UIHostingController(rootView: audioView)
        host.modalPresentationStyle = .pageSheet
        if let sheet = host.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(host, animated: true)
    }

    private func presentColorGrade() {
        let colorView = ColorGradeView()
        let host = UIHostingController(rootView: colorView)
        host.modalPresentationStyle = .pageSheet
        if let sheet = host.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(host, animated: true)
    }

    private func presentAspectRatioPicker() {
        let pickerView = AspectRatioPickerView(selectedRatio: Binding(
            get: { self.viewModel.selectedAspectRatio },
            set: { self.viewModel.selectedAspectRatio = $0 }
        ))
        let host = UIHostingController(rootView: pickerView)
        host.modalPresentationStyle = .pageSheet
        if let sheet = host.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(host, animated: true)
    }

    // MARK: - Timeline Scrubbing

    @objc private func handleTimelineScrub(_ gesture: UIPanGestureRecognizer) {
        guard let container = timelineContainer else { return }

        let trackAreaLeading: CGFloat = 32
        let trackAreaWidth = container.bounds.width - trackAreaLeading
        guard trackAreaWidth > 0 else { return }

        let locationX = gesture.location(in: container).x - trackAreaLeading
        let percent = Swift.min(Swift.max(locationX / trackAreaWidth, 0), 1.0)
        scrubPosition = percent

        // Move playhead
        if let playhead = playheadView {
            let xOffset = trackAreaLeading + (trackAreaWidth * percent)
            playhead.constraints.forEach { constraint in
                if constraint.firstAttribute == .leading {
                    constraint.constant = xOffset
                }
            }
            container.layoutIfNeeded()
        }

        // Seek AVPlayer if present
        if let player = self.player,
           let duration = player.currentItem?.duration,
           duration.isNumeric && duration.seconds > 0 {
            let targetTime = CMTimeMultiplyByFloat64(duration, multiplier: Float64(percent))
            player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }
}
