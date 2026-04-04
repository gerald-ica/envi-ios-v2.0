import UIKit
import SwiftUI

/// UIKit-based video editor with preview, timeline, and toolbar.
final class EditorViewController: UIViewController {

    private let viewModel = EditorViewModel()
    private let contentItem: ContentItem?
    private let contentPiece: ContentPiece?
    private lazy var exportComposer = ExportComposerFactory.make(contentItem: contentItem, contentPiece: contentPiece)
    private var isPreviewPlaying = false
    private let videoEditService = VideoEditService()
    private var latestTrimmedVideoURL: URL?

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

        // Add a placeholder image
        let imageView = UIImageView()
        imageView.image = previewImage()
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        previewView.insertSubview(imageView, at: 0)

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

            playButton.centerXAnchor.constraint(equalTo: previewView.centerXAnchor),
            playButton.centerYAnchor.constraint(equalTo: previewView.centerYAnchor),

            textPreviewLabel.leadingAnchor.constraint(equalTo: previewView.leadingAnchor, constant: 20),
            textPreviewLabel.trailingAnchor.constraint(equalTo: previewView.trailingAnchor, constant: -20),
            textPreviewLabel.centerYAnchor.constraint(equalTo: previewView.centerYAnchor),
        ])
    }

    private func setupTimeline() {
        // Simplified timeline placeholder
        let timelineLabel = UILabel()
        timelineLabel.text = "Timeline"
        timelineLabel.font = .spaceMono(11)
        timelineLabel.textColor = ENVITheme.UIKit.textLightDark
        timelineLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(timelineLabel)

        // Track lanes
        let tracks = ["V1", "A1", "T1", "FX"]
        var previousView: UIView = previewView
        for (index, trackName) in tracks.enumerated() {
            let track = createTrackView(name: trackName)
            view.addSubview(track)
            NSLayoutConstraint.activate([
                track.topAnchor.constraint(equalTo: previousView.bottomAnchor, constant: index == 0 ? 32 : 4),
                track.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 48),
                track.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
                track.heightAnchor.constraint(equalToConstant: 28),
            ])
            previousView = track

            // Label
            let label = UILabel()
            label.text = trackName
            label.font = .spaceMonoBold(9)
            label.textColor = ENVITheme.UIKit.textLightDark
            label.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerYAnchor.constraint(equalTo: track.centerYAnchor),
                label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            ])
        }
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
        default:
            presentPlaceholderAlert(
                title: tool,
                message: "This editing tool is still placeholder UI. The next pass should wire it into the real editor stack."
            )
        }
    }

    private func presentPlaceholderAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @MainActor
    private func performQuickTrim() async {
        guard let sourceURL = resolveSourceVideoURL() else {
            presentPlaceholderAlert(
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
            presentPlaceholderAlert(
                title: "Trim Complete",
                message: "Created trimmed clip: \(outputURL.lastPathComponent)"
            )
        } catch {
            presentPlaceholderAlert(
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
            return loadImage(named: "runway") ?? loadImage(named: "studio-fashion")
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
}
