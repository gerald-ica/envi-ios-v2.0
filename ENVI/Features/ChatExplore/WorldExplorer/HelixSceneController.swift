import SceneKit
import UIKit

// MARK: - Content Links
// Uses ContentLink from Models/ContentLink.swift (canonical definition).
// kContentLinks is a convenience alias for HelixSceneController and ContentNodeView.
let kContentLinks = ContentLink.sampleLinks

// MARK: - Timeline Event Data

struct TimelineEvent {
    let id: String
    let label: String
    let date: String
    let group: String // "moment" or "prediction"
}

let kTimelineEvents: [TimelineEvent] = [
    TimelineEvent(id: "moment-4",  label: "GALLERY OPENING", date: "2026-03-08", group: "moment"),
    TimelineEvent(id: "moment-3",  label: "COFFEE MEETING",  date: "2026-03-10", group: "moment"),
    TimelineEvent(id: "moment-2",  label: "STUDIO SESSION",  date: "2026-03-12", group: "moment"),
    TimelineEvent(id: "moment-1",  label: "WEEKEND HIKE",    date: "2026-03-15", group: "moment"),
    TimelineEvent(id: "predict-1", label: "NEXT WEEK",       date: "2026-03-22", group: "prediction"),
    TimelineEvent(id: "predict-2", label: "OPPORTUNITY",     date: "2026-03-25", group: "prediction"),
]

// MARK: - Zoom Level

enum ExplorerZoomLevel: String, CaseIterable {
    case year, month, week, day

    var shortLabel: String {
        switch self {
        case .year:  return "Y"
        case .month: return "M"
        case .week:  return "W"
        case .day:   return "D"
        }
    }

    /// Camera Z distance for each zoom level (matches React exactly)
    var cameraDistance: Float {
        switch self {
        case .year:  return 32
        case .month: return 26
        case .week:  return 18
        case .day:   return 10
        }
    }

    /// Content piece scale multiplier (matches React exactly)
    var sizeMultiplier: Float {
        switch self {
        case .year:  return 0.8
        case .month: return 1.0
        case .week:  return 1.3
        case .day:   return 1.8
        }
    }
}

// MARK: - View Mode

enum ExplorerViewMode: String {
    case stream
    case spiral
}

// MARK: - Helix Scene Controller

/// Manages the SceneKit scene: 2000 content piece nodes arranged in a horizontal helix,
/// continuous animation, starfield, spine tube, timeline, connection lines,
/// camera system with auto/orbit/zoom modes, and tap-to-select hit testing.
///
/// Content pieces represent already-edited assets from the user's camera roll.
/// The 2000 count is a placeholder; in production this would match the user's actual library size.
final class HelixSceneController: NSObject, SCNSceneRendererDelegate {

    // MARK: - Configuration (matches React STREAM_CONFIG exactly)

    private struct Config {
        /// Placeholder count for user's content library — each represents an edited piece.
        static let contentPieceCount: Int = 2000
        static let streamLength: Float = 140
        static let streamRadius: Float = 10
        static let size: Float = 0.95
        static let speed: Float = 1.0
        static let fadeLen: Float = 0.345
        static let sizeDepthBias: Float = 0.89
        static let cameraFov: CGFloat = 97
        static let cameraPos = SCNVector3(-4, 4, 34)

        // Starfield
        static let starCount: Int = 250
        static let starSpread: Float = 120
        static let starSize: CGFloat = 0.12
        static let starOpacity: CGFloat = 0.5

        // Spine tube
        static let spinePoints: Int = 300
        static let spineRadius: CGFloat = 0.04

        // Timeline
        static let tickDates = [
            "2026-03-05", "2026-03-08", "2026-03-12", "2026-03-15",
            "2026-03-19", "2026-03-22", "2026-03-25", "2026-03-28"
        ]
        static let tlStart = "2026-03-05"
        static let tlEnd   = "2026-03-28"
    }

    // MARK: - Properties

    private weak var scnView: SCNView?
    private var scene: SCNScene?
    private var cameraNode: SCNNode?

    /// Per content piece state
    private var streamTs: [Float] = []          // [0,1] position along helix
    private var phases: [Float] = []            // random per-content-piece phase offset
    private var baseSizes: [Float] = []         // base scale
    private var contentIndices: [Int] = []      // maps content piece → CONTENT_IDS index (0..<14+6 future)
    private var contentPieceNodes: [SCNNode] = [] // the plane nodes
    private var positions: [SCNVector3] = []    // current world positions (updated each frame)
    private var isFutureNode: [Bool] = []       // whether this node represents a future/predicted piece

    /// Starfield
    private var starNodes: [SCNNode] = []
    private var starSpeeds: [Float] = []

    /// Spine tube
    private var spineNode: SCNNode?

    /// Timeline
    private var timelineGroup: SCNNode?

    /// Connection lines
    private var linkLineNodes: [SCNNode] = []
    private var linkPairs: [(Int, Int)] = []    // (content piece index A, content piece index B)
    private var selectedLinkLineNodes: [SCNNode] = []

    /// Textures loaded from bundle
    private var textures: [UIImage] = []

    /// Callbacks
    var onNodeTapped: ((String) -> Void)?
    var onSceneReady: (() -> Void)?

    /// Animation clock
    private var startTime: TimeInterval = 0
    private var isSetUp = false

    /// Pause / camera state
    var isPaused: Bool = false
    var pausedElapsed: Float = 0
    var userControlling: Bool = false
    var isScrubbing: Bool = false

    /// Camera zoom target (when a content piece is selected)
    var targetCamPos: SCNVector3?
    var targetLookAt: SCNVector3?

    /// View mode (stream vs spiral) and lerp
    var viewMode: ExplorerViewMode = .stream
    private var viewLerp: Float = 0       // 0 = stream, 1 = spiral
    private var viewLerpTarget: Float = 0

    /// External state bindings
    var activeTypeFilter: ContentType?
    var selectedContentId: String?
    var lightMode: Bool = false {
        didSet { updateLightMode() }
    }
    var timePosition: Float = 0.5
    var zoomLevel: ExplorerZoomLevel = .month

    /// Cached star material for light mode toggling
    private var starMaterial: SCNMaterial?
    private var tlLineMaterial: SCNMaterial?
    private var tlGlowMaterial: SCNMaterial?

    // MARK: - Init

    init(onNodeTapped: ((String) -> Void)?, onSceneReady: (() -> Void)?) {
        self.onNodeTapped = onNodeTapped
        self.onSceneReady = onSceneReady
        super.init()
    }

    // MARK: - Setup

    func setupScene(in scnView: SCNView) {
        self.scnView = scnView

        let scene = SCNScene()
        scene.background.contents = UIColor.black
        self.scene = scene

        // Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = Config.cameraFov
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 200
        cameraNode.position = Config.cameraPos
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)
        self.cameraNode = cameraNode

        // Ambient light for basic visibility
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = UIColor(white: 0.8, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLight)

        // Load textures
        loadTextures()

        // Build scene elements (order matters for depth)
        createStarfield(in: scene)
        createHelixSpineTube(in: scene)
        createTimeline(in: scene)
        createContentPieces(in: scene)
        createConnectionLines(in: scene)

        // Assign to SCNView
        scnView.scene = scene
        scnView.delegate = self
        scnView.isPlaying = true

        isSetUp = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.onSceneReady?()
        }
    }

    // MARK: - Texture Loading

    private func loadTextures() {
        textures = ContentLibrary.imageNames.compactMap { name in
            if let image = UIImage(named: name) { return image }
            if let path = Bundle.main.path(forResource: name, ofType: "jpg", inDirectory: "Images") {
                return UIImage(contentsOfFile: path)
            }
            if let path = Bundle.main.path(forResource: name, ofType: "jpg") {
                return UIImage(contentsOfFile: path)
            }
            return generatePlaceholderImage()
        }
        while textures.count < ContentLibrary.imageNames.count {
            textures.append(generatePlaceholderImage())
        }
    }

    private func generatePlaceholderImage() -> UIImage {
        let size = CGSize(width: 128, height: 180)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            UIColor(hex: "#1A1A1A").setFill()
            let path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 16)
            path.fill()
        }
    }

    private func createRoundedTexture(from image: UIImage, size: CGSize = CGSize(width: 192, height: 270), cornerRadius: CGFloat = 28) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            path.addClip()
            let imgAspect = image.size.width / image.size.height
            let canvasAspect = size.width / size.height
            var drawRect = rect
            if imgAspect > canvasAspect {
                let newWidth = size.height * imgAspect
                drawRect = CGRect(x: (size.width - newWidth) / 2, y: 0, width: newWidth, height: size.height)
            } else {
                let newHeight = size.width / imgAspect
                drawRect = CGRect(x: 0, y: (size.height - newHeight) / 2, width: size.width, height: newHeight)
            }
            image.draw(in: drawRect)
        }
    }

    // MARK: - Starfield (250 white dots drifting downward)

    private func createStarfield(in scene: SCNScene) {
        let starRoot = SCNNode()
        starRoot.name = "starfield"
        scene.rootNode.addChildNode(starRoot)

        let spread = Config.starSpread
        let sphere = SCNSphere(radius: Config.starSize)
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.white
        mat.lightingModel = .constant
        mat.transparency = Config.starOpacity
        mat.writesToDepthBuffer = false
        sphere.materials = [mat]
        self.starMaterial = mat

        for _ in 0..<Config.starCount {
            let node = SCNNode(geometry: sphere.copy() as? SCNGeometry)
            let x = Float.random(in: -spread...spread)
            let y = Float.random(in: -spread / 2...spread / 2)
            let z = Float.random(in: -spread / 2 - 20...spread / 2 - 20)
            node.position = SCNVector3(x, y, z)
            starRoot.addChildNode(node)
            starNodes.append(node)
            starSpeeds.append(0.003 + Float.random(in: 0...0.012))
        }
    }

    // MARK: - Helix Spine Tube (#30217C at 15% opacity)

    private func createHelixSpineTube(in scene: SCNScene) {
        let SL = Config.streamLength
        let SR = Config.streamRadius
        let pointCount = Config.spinePoints

        // Build spine curve points
        var spinePoints: [SCNVector3] = []
        for i in 0..<pointCount {
            let t = Float(i) / Float(pointCount - 1)
            let x = (t - 0.5) * SL
            let angle = t * Float.pi * 11
            let y = cos(angle) * SR * 0.25
            let z = sin(angle) * SR * 0.22
            spinePoints.append(SCNVector3(x, y, z))
        }

        // Build a thin tube approximation using SCNCylinder segments
        // SceneKit doesn't have TubeGeometry, so we chain short cylinder segments
        let spineRoot = SCNNode()
        spineRoot.name = "helixSpine"

        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(hex: "#30217C").withAlphaComponent(0.15)
        mat.lightingModel = .constant
        mat.isDoubleSided = true
        mat.writesToDepthBuffer = false
        mat.transparency = 1.0

        let segmentSkip = 2 // draw every 2nd segment for performance
        for i in stride(from: 0, to: spinePoints.count - segmentSkip, by: segmentSkip) {
            let a = spinePoints[i]
            let b = spinePoints[min(i + segmentSkip, spinePoints.count - 1)]

            let dx = b.x - a.x
            let dy = b.y - a.y
            let dz = b.z - a.z
            let len = sqrt(dx * dx + dy * dy + dz * dz)
            guard len > 0.001 else { continue }

            let cyl = SCNCylinder(radius: 0.04, height: CGFloat(len))
            cyl.radialSegmentCount = 6
            cyl.materials = [mat]

            let segNode = SCNNode(geometry: cyl)
            segNode.position = SCNVector3(
                (a.x + b.x) / 2,
                (a.y + b.y) / 2,
                (a.z + b.z) / 2
            )

            // Orient cylinder along the segment direction
            let dir = SCNVector3(dx / len, dy / len, dz / len)
            let up = SCNVector3(0, 1, 0)
            let dot = up.x * dir.x + up.y * dir.y + up.z * dir.z
            let crossX = up.y * dir.z - up.z * dir.y
            let crossY = up.z * dir.x - up.x * dir.z
            let crossZ = up.x * dir.y - up.y * dir.x
            let crossLen = sqrt(crossX * crossX + crossY * crossY + crossZ * crossZ)
            if crossLen > 0.0001 {
                let angle = acos(max(-1, min(1, dot)))
                segNode.rotation = SCNVector4(crossX / crossLen, crossY / crossLen, crossZ / crossLen, angle)
            }

            spineRoot.addChildNode(segNode)
        }

        scene.rootNode.addChildNode(spineRoot)
        self.spineNode = spineRoot
    }

    // MARK: - Timeline Group

    private func createTimeline(in scene: SCNScene) {
        let SL = Config.streamLength
        let halfSL = SL / 2
        let group = SCNNode()
        group.name = "timelineGroup"

        // Main horizontal line (white 15% opacity)
        let lineGeo = SCNBox(width: CGFloat(SL * 1.1), height: 0.06, length: 0.06, chamferRadius: 0)
        let lineMat = SCNMaterial()
        lineMat.diffuse.contents = UIColor.white.withAlphaComponent(0.15)
        lineMat.lightingModel = .constant
        lineMat.writesToDepthBuffer = false
        lineGeo.materials = [lineMat]
        let lineNode = SCNNode(geometry: lineGeo)
        lineNode.position = SCNVector3(0, 0, 0)
        group.addChildNode(lineNode)
        self.tlLineMaterial = lineMat

        // Purple glow under line (#30217C 6% opacity)
        let glowGeo = SCNBox(width: CGFloat(SL * 1.1), height: 0.6, length: 0.6, chamferRadius: 0)
        let glowMat = SCNMaterial()
        glowMat.diffuse.contents = UIColor(hex: "#30217C").withAlphaComponent(0.06)
        glowMat.lightingModel = .constant
        glowMat.writesToDepthBuffer = false
        glowGeo.materials = [glowMat]
        let glowNode = SCNNode(geometry: glowGeo)
        group.addChildNode(glowNode)
        self.tlGlowMaterial = glowMat

        // Date formatter
        let inputFmt = DateFormatter()
        inputFmt.dateFormat = "yyyy-MM-dd"
        let displayFmt = DateFormatter()
        displayFmt.dateFormat = "MMM d"

        guard let tlStartDate = inputFmt.date(from: Config.tlStart),
              let tlEndDate = inputFmt.date(from: Config.tlEnd) else { return }
        let tlRange = tlEndDate.timeIntervalSince(tlStartDate)

        // Tick marks + date labels
        for dateStr in Config.tickDates {
            guard let date = inputFmt.date(from: dateStr) else { continue }
            let pct = Float(date.timeIntervalSince(tlStartDate) / tlRange)
            let x = -halfSL + pct * SL

            // Tick
            let tickGeo = SCNBox(width: 0.06, height: 1.0, length: 0.06, chamferRadius: 0)
            let tickMat = SCNMaterial()
            tickMat.diffuse.contents = UIColor.white.withAlphaComponent(0.1)
            tickMat.lightingModel = .constant
            tickMat.writesToDepthBuffer = false
            tickGeo.materials = [tickMat]
            let tickNode = SCNNode(geometry: tickGeo)
            tickNode.position = SCNVector3(x, 0, 0)
            group.addChildNode(tickNode)

            // Date label (rendered as text sprite)
            let labelStr = displayFmt.string(from: date).uppercased()
            let labelNode = createTextSprite(text: labelStr, fontSize: 14, color: UIColor.white.withAlphaComponent(0.3), bold: false)
            labelNode.position = SCNVector3(x, -1.5, 0)
            labelNode.scale = SCNVector3(5, 1.25, 1)
            group.addChildNode(labelNode)
        }

        // PAST / FUTURE labels
        for (i, text) in ["PAST", "FUTURE"].enumerated() {
            let labelNode = createTextSprite(text: text, fontSize: 16, color: UIColor.white.withAlphaComponent(0.15), bold: true)
            let x: Float = i == 0 ? -halfSL - 6 : halfSL + 6
            labelNode.position = SCNVector3(x, 0, 0)
            labelNode.scale = SCNVector3(6, 1.5, 1)
            group.addChildNode(labelNode)
        }

        // Event diamond markers
        for evt in kTimelineEvents {
            guard let date = inputFmt.date(from: evt.date) else { continue }
            let pct = Float(date.timeIntervalSince(tlStartDate) / tlRange)
            let x = -halfSL + pct * SL

            let diamondGeo = SCNBox(width: 0.5, height: 0.5, length: 0.15, chamferRadius: 0)
            let diamondMat = SCNMaterial()
            diamondMat.diffuse.contents = UIColor(hex: "#30217C").withAlphaComponent(0.6)
            diamondMat.lightingModel = .constant
            diamondMat.writesToDepthBuffer = false
            diamondGeo.materials = [diamondMat]
            let diamond = SCNNode(geometry: diamondGeo)
            diamond.position = SCNVector3(x, 0, 0)
            diamond.eulerAngles = SCNVector3(0, 0, Float.pi / 4)
            group.addChildNode(diamond)
        }

        // "NOW" marker — vertical line at current date position
        let nowDateStr = "2026-03-26"
        if let nowDate = inputFmt.date(from: nowDateStr) {
            let nowPct = Float(nowDate.timeIntervalSince(tlStartDate) / tlRange)
            let nowX = -halfSL + nowPct * SL

            // Vertical NOW line
            let nowLineGeo = SCNBox(width: 0.08, height: 3.0, length: 0.08, chamferRadius: 0)
            let nowLineMat = SCNMaterial()
            nowLineMat.diffuse.contents = UIColor.white.withAlphaComponent(0.6)
            nowLineMat.lightingModel = .constant
            nowLineMat.writesToDepthBuffer = false
            nowLineGeo.materials = [nowLineMat]
            let nowLine = SCNNode(geometry: nowLineGeo)
            nowLine.position = SCNVector3(nowX, 0, 0)
            group.addChildNode(nowLine)

            // "NOW" label
            let nowLabel = createTextSprite(text: "NOW", fontSize: 14, color: UIColor.white.withAlphaComponent(0.8), bold: true)
            nowLabel.position = SCNVector3(nowX, 2.0, 0)
            nowLabel.scale = SCNVector3(4, 1.0, 1)
            group.addChildNode(nowLabel)

            // Pulsing glow on NOW marker
            let glowSphere = SCNSphere(radius: 0.3)
            let glowSphereMat = SCNMaterial()
            glowSphereMat.diffuse.contents = UIColor.white.withAlphaComponent(0.3)
            glowSphereMat.lightingModel = .constant
            glowSphereMat.writesToDepthBuffer = false
            glowSphere.materials = [glowSphereMat]
            let glowNode = SCNNode(geometry: glowSphere)
            glowNode.position = SCNVector3(nowX, 0, 0)
            group.addChildNode(glowNode)

            let glowPulse = CABasicAnimation(keyPath: "scale")
            glowPulse.fromValue = NSValue(scnVector3: SCNVector3(1.0, 1.0, 1.0))
            glowPulse.toValue = NSValue(scnVector3: SCNVector3(1.8, 1.8, 1.8))
            glowPulse.duration = 2.0
            glowPulse.autoreverses = true
            glowPulse.repeatCount = .infinity
            glowPulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            glowNode.addAnimation(glowPulse, forKey: "nowPulse")
        }

        // Future prediction diamond markers (pulsing glow)
        let futurePredictionEvents: [(label: String, date: String)] = [
            ("AI: TREND VIDEO", "2026-03-28"),
            ("AI: CAROUSEL RECAP", "2026-03-30"),
            ("AI: COFFEE DAY", "2026-04-01"),
            ("AI: PEAK WINDOW", "2026-04-03"),
            ("AI: CONTENT GAP", "2026-04-05"),
            ("AI: COLLAB", "2026-04-07"),
        ]

        // Extend timeline end to cover future dates
        let extendedEndStr = "2026-04-10"
        let extendedEndDate = inputFmt.date(from: extendedEndStr) ?? tlEndDate
        let extendedRange = extendedEndDate.timeIntervalSince(tlStartDate)

        for evt in futurePredictionEvents {
            guard let date = inputFmt.date(from: evt.date) else { continue }
            let pct = Float(date.timeIntervalSince(tlStartDate) / extendedRange)
            let x = -halfSL + pct * SL * Float(extendedRange / tlRange)

            // Diamond marker with pulsing glow
            let diamondGeo = SCNBox(width: 0.45, height: 0.45, length: 0.12, chamferRadius: 0)
            let diamondMat = SCNMaterial()
            diamondMat.diffuse.contents = UIColor(hex: "#30217C").withAlphaComponent(0.8)
            diamondMat.lightingModel = .constant
            diamondMat.writesToDepthBuffer = false
            diamondGeo.materials = [diamondMat]
            let diamond = SCNNode(geometry: diamondGeo)
            diamond.position = SCNVector3(x, 0, 0)
            diamond.eulerAngles = SCNVector3(0, 0, Float.pi / 4)
            group.addChildNode(diamond)

            // Pulsing animation on future diamonds
            let diamondPulse = CABasicAnimation(keyPath: "scale")
            diamondPulse.fromValue = NSValue(scnVector3: SCNVector3(1.0, 1.0, 1.0))
            diamondPulse.toValue = NSValue(scnVector3: SCNVector3(1.3, 1.3, 1.3))
            diamondPulse.duration = 1.5
            diamondPulse.autoreverses = true
            diamondPulse.repeatCount = .infinity
            diamondPulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            diamond.addAnimation(diamondPulse, forKey: "futureDiamondPulse")

            // Label (white/50 for future vs white/30 for past)
            let label = createTextSprite(text: evt.label, fontSize: 11, color: UIColor.white.withAlphaComponent(0.5), bold: true)
            label.position = SCNVector3(x, -1.5, 0)
            label.scale = SCNVector3(5, 1.25, 1)
            group.addChildNode(label)
        }

        // Position timeline at y = -8 to sit below helix
        group.position = SCNVector3(0, -8, 0)
        scene.rootNode.addChildNode(group)
        self.timelineGroup = group
    }

    /// Creates a sprite node with rendered text (SceneKit equivalent of Three.js CanvasTexture sprites)
    private func createTextSprite(text: String, fontSize: CGFloat, color: UIColor, bold: Bool) -> SCNNode {
        let canvasSize = CGSize(width: 256, height: 64)
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        let image = renderer.image { ctx in
            let fontName = bold ? "SpaceMono-Bold" : "SpaceMono-Regular"
            let font = UIFont(name: fontName, size: fontSize) ?? UIFont.monospacedSystemFont(ofSize: fontSize, weight: bold ? .bold : .regular)

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraphStyle
            ]
            let textRect = CGRect(x: 0, y: (canvasSize.height - fontSize * 1.5) / 2, width: canvasSize.width, height: fontSize * 2)
            text.draw(in: textRect, withAttributes: attrs)
        }

        let plane = SCNPlane(width: 1, height: 0.25)
        let mat = SCNMaterial()
        mat.diffuse.contents = image
        mat.lightingModel = .constant
        mat.isDoubleSided = true
        mat.writesToDepthBuffer = false
        mat.transparencyMode = .aOne
        plane.materials = [mat]

        let node = SCNNode(geometry: plane)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = [.X, .Y]
        node.constraints = [billboard]
        return node
    }

    // MARK: - Content Piece Creation

    private func createContentPieces(in scene: SCNScene) {
        let count = Config.contentPieceCount
        let allPieces = ContentLibrary.pieces
        let contentCount = allPieces.count  // 14 past + 6 future = 20
        let imageNames = ContentLibrary.imageNames
        let textureCount = imageNames.count  // 14 unique textures

        // Build image name → texture index lookup
        var imageNameToTexIndex: [String: Int] = [:]
        for (idx, name) in imageNames.enumerated() {
            imageNameToTexIndex[name] = idx
        }

        // Map each content piece to its texture index
        let pieceTexIndices: [Int] = allPieces.map { piece in
            imageNameToTexIndex[piece.imageName] ?? 0
        }

        // Prepare rounded textures (matching React's 192x270 @ r=28)
        var roundedTextures: [UIImage] = []
        for tex in textures {
            roundedTextures.append(createRoundedTexture(from: tex))
        }

        // Per-content-piece arrays
        streamTs = (0..<count).map { _ in Float.random(in: 0...1) }
        phases = (0..<count).map { _ in Float.random(in: 0...(Float.pi * 2)) }
        baseSizes = (0..<count).map { _ in 0.3 + Float.random(in: 0...0.6) }
        contentIndices = (0..<count).map { $0 % contentCount }
        positions = Array(repeating: SCNVector3Zero, count: count)
        isFutureNode = (0..<count).map { allPieces[$0 % contentCount].isFuture }

        // Shared geometry: vertical plane aspect ~1:1.4 (matching React)
        let planeGeometry = SCNPlane(width: 1.0, height: 1.4)

        // Materials (one per texture for normal and future variants)
        var materials: [SCNMaterial] = []
        var futureMaterials: [SCNMaterial] = []
        for i in 0..<textureCount {
            let roundedTex = roundedTextures[i]

            let mat = SCNMaterial()
            mat.diffuse.contents = roundedTex
            mat.isDoubleSided = true
            mat.lightingModel = .constant
            mat.transparencyMode = .aOne
            mat.writesToDepthBuffer = false
            mat.readsFromDepthBuffer = true
            materials.append(mat)

            // Future material: same texture but 50% opacity base
            let futMat = SCNMaterial()
            futMat.diffuse.contents = roundedTex
            futMat.isDoubleSided = true
            futMat.lightingModel = .constant
            futMat.transparencyMode = .aOne
            futMat.writesToDepthBuffer = false
            futMat.readsFromDepthBuffer = true
            futMat.transparency = 0.5
            futureMaterials.append(futMat)
        }

        // Container node
        let helixRoot = SCNNode()
        helixRoot.name = "helixRoot"
        scene.rootNode.addChildNode(helixRoot)

        // Create content piece nodes
        contentPieceNodes = []
        for i in 0..<count {
            let node = SCNNode(geometry: planeGeometry.copy() as? SCNGeometry)
            let ci = contentIndices[i]
            let texIdx = pieceTexIndices[ci]
            let isFuture = isFutureNode[i]

            node.geometry?.materials = [isFuture ? futureMaterials[texIdx] : materials[texIdx]]
            node.name = "content_\(i)"

            let pos = helixPosition(t: streamTs[i], phase: phases[i], elapsed: 0)
            node.position = pos
            positions[i] = pos

            // Future pieces are 0.8x normal size
            let sizeMult: Float = isFuture ? 0.8 : 1.0
            let s = CGFloat(baseSizes[i] * Config.size * sizeMult)
            node.scale = SCNVector3(s, s, s)

            let billboard = SCNBillboardConstraint()
            billboard.freeAxes = [.X, .Y]
            node.constraints = [billboard]

            node.opacity = CGFloat(fadeOpacity(t: streamTs[i]))

            // Future pieces get a pulsing opacity animation
            if isFuture {
                let pulse = CABasicAnimation(keyPath: "opacity")
                pulse.fromValue = 0.35
                pulse.toValue = 0.55
                pulse.duration = 2.0
                pulse.autoreverses = true
                pulse.repeatCount = .infinity
                pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                node.addAnimation(pulse, forKey: "futurePulse")
            }

            helixRoot.addChildNode(node)
            contentPieceNodes.append(node)
        }
    }

    // MARK: - Connection Lines

    private func createConnectionLines(in scene: SCNScene) {
        let contentIDs = ContentLibrary.pieces.map { $0.id }
        let count = Config.contentPieceCount

        // Build nodeIndex → first content piece index lookup
        var nodeFirstPiece: [Int: Int] = [:]
        for i in 0..<count {
            let ni = contentIndices[i]
            if nodeFirstPiece[ni] == nil {
                nodeFirstPiece[ni] = i
            }
        }

        // Build link pairs connecting representative content pieces
        linkPairs = []
        for link in kContentLinks {
            guard let srcIdx = contentIDs.firstIndex(of: link.source),
                  let tgtIdx = contentIDs.firstIndex(of: link.target) else { continue }

            // Find up to 2 content pieces of each type
            let srcPieces = (0..<count).filter { contentIndices[$0] == srcIdx }.prefix(2)
            let tgtPieces = (0..<count).filter { contentIndices[$0] == tgtIdx }.prefix(2)

            for s in srcPieces {
                for t in tgtPieces {
                    linkPairs.append((s, t))
                }
            }
        }

        // Create thin line nodes for each pair
        let lineMat = SCNMaterial()
        lineMat.diffuse.contents = UIColor.white.withAlphaComponent(0.04)
        lineMat.lightingModel = .constant
        lineMat.writesToDepthBuffer = false

        let selLineMat = SCNMaterial()
        selLineMat.diffuse.contents = UIColor.white.withAlphaComponent(0.15)
        selLineMat.lightingModel = .constant
        selLineMat.writesToDepthBuffer = false

        for _ in linkPairs {
            // Use a thin cylinder as a line segment
            let cyl = SCNCylinder(radius: 0.015, height: 1)
            cyl.radialSegmentCount = 4
            cyl.materials = [lineMat]
            let node = SCNNode(geometry: cyl)
            node.isHidden = false
            scene.rootNode.addChildNode(node)
            linkLineNodes.append(node)

            // Selected highlight line
            let selCyl = SCNCylinder(radius: 0.025, height: 1)
            selCyl.radialSegmentCount = 4
            selCyl.materials = [selLineMat]
            let selNode = SCNNode(geometry: selCyl)
            selNode.isHidden = true
            scene.rootNode.addChildNode(selNode)
            selectedLinkLineNodes.append(selNode)
        }
    }

    /// Updates a cylinder node to connect two world positions
    private func orientCylinder(_ node: SCNNode, from a: SCNVector3, to b: SCNVector3) {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let dz = b.z - a.z
        let len = sqrt(dx * dx + dy * dy + dz * dz)
        guard len > 0.001 else {
            node.isHidden = true
            return
        }

        node.isHidden = false
        node.position = SCNVector3(
            (a.x + b.x) / 2,
            (a.y + b.y) / 2,
            (a.z + b.z) / 2
        )

        // Update height
        if let cyl = node.geometry as? SCNCylinder {
            cyl.height = CGFloat(len)
        }

        // Orient
        let dir = SCNVector3(dx / len, dy / len, dz / len)
        let up = SCNVector3(0, 1, 0)
        let dotP = up.x * dir.x + up.y * dir.y + up.z * dir.z
        let crossX = up.y * dir.z - up.z * dir.y
        let crossY = up.z * dir.x - up.x * dir.z
        let crossZ = up.x * dir.y - up.y * dir.x
        let crossLen = sqrt(crossX * crossX + crossY * crossY + crossZ * crossZ)
        if crossLen > 0.0001 {
            let angle = acos(max(-1, min(1, dotP)))
            node.rotation = SCNVector4(crossX / crossLen, crossY / crossLen, crossZ / crossLen, angle)
        } else if dotP < 0 {
            node.rotation = SCNVector4(1, 0, 0, Float.pi)
        } else {
            node.rotation = SCNVector4(0, 0, 0, 0)
        }
    }

    // MARK: - Helix Math

    /// Computes the 3D position on the horizontal helix for a parameter t ∈ [0,1].
    /// Matches React exactly: angle = t * π * 11 + phase + elapsed * 0.15
    private func helixPosition(t: Float, phase: Float, elapsed: Float) -> SCNVector3 {
        let SL = Config.streamLength
        let SR = Config.streamRadius

        let x = (t - 0.5) * SL
        let angle = t * Float.pi * 11 + phase + elapsed * 0.15
        let rBase = SR * (0.6 + 0.4 * sin(t * Float.pi))
        let rMod = 0.7 + 0.3 * sin(phase)
        let r = rBase * rMod

        let y = cos(angle) * r * 0.5 + sin(phase * 2 + elapsed * 0.1) * 0.6
        let z = sin(angle) * r * 0.45

        return SCNVector3(x, y, z)
    }

    /// Spiral mode position (vertical coil) — matches React exactly
    private func spiralPosition(t: Float, phase: Float, rMod: Float) -> SCNVector3 {
        let SL = Config.streamLength
        let spiralX = cos(t * Float.pi * 8 + phase) * (3 + rMod * 4)
        let spiralY = (t - 0.5) * SL * 0.6
        let spiralZ = sin(t * Float.pi * 8 + phase) * (3 + rMod * 4)
        return SCNVector3(spiralX, spiralY, spiralZ)
    }

    /// Edge-fade opacity: content pieces near start/end of helix fade out.
    private func fadeOpacity(t: Float) -> Float {
        let fadeLen = Config.fadeLen
        if t < fadeLen { return t / fadeLen }
        if t > (1.0 - fadeLen) { return (1.0 - t) / fadeLen }
        return 1.0
    }

    // MARK: - Frame Update (SCNSceneRendererDelegate)

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard isSetUp else { return }

        if startTime == 0 { startTime = time }
        let rawElapsed = Float(time - startTime) * Config.speed

        // When paused, freeze elapsed time
        let elapsed: Float
        if isPaused {
            elapsed = pausedElapsed
        } else {
            elapsed = rawElapsed
            pausedElapsed = rawElapsed
        }

        // View mode lerp (smooth transition between stream and spiral)
        let lerpDelta = (viewLerpTarget - viewLerp) * (1.0 / 60.0)
        viewLerp += lerpDelta
        if viewLerp < 0.001 { viewLerp = 0 }
        if viewLerp > 0.999 { viewLerp = 1 }
        let vl = viewLerp

        let count = Config.contentPieceCount
        guard let cameraPos = cameraNode?.position else { return }

        let contentIDs = ContentLibrary.pieces.map { $0.id }
        let contentCount = ContentLibrary.pieces.count

        // Content type index lookup for filtering
        let contentTypeForIndex: [ContentType] = ContentLibrary.pieces.map { $0.type }

        let zoomSizeMult = zoomLevel.sizeMultiplier

        // Update content piece positions
        for i in 0..<count {
            var t = streamTs[i] + elapsed * 0.008
            t = t.truncatingRemainder(dividingBy: 1.0)
            if t < 0 { t += 1.0 }

            // Stream position (horizontal coil)
            let streamPos = helixPosition(t: t, phase: phases[i], elapsed: elapsed)

            // Spiral position (vertical coil)
            let rMod = 0.7 + 0.3 * sin(phases[i])
            let spiralPos = spiralPosition(t: t, phase: phases[i], rMod: rMod)

            // Lerp between modes
            let pos = SCNVector3(
                streamPos.x + (spiralPos.x - streamPos.x) * vl,
                streamPos.y + (spiralPos.y - streamPos.y) * vl,
                streamPos.z + (spiralPos.z - streamPos.z) * vl
            )
            contentPieceNodes[i].position = pos
            positions[i] = pos

            // Depth-based scale
            let dx = cameraPos.x - pos.x
            let dy = cameraPos.y - pos.y
            let dz = cameraPos.z - pos.z
            let dist = sqrt(dx * dx + dy * dy + dz * dz)
            let depthScale = 1.0 / (1.0 + dist * Config.sizeDepthBias * 0.02)

            // Selection highlighting + type filtering (matches React exactly)
            let isSelected = selectedContentId != nil
            let contentNodeIdx = contentIndices[i]
            let contentPieceId = contentIDs[contentNodeIdx]
            let isThisContent = contentPieceId == selectedContentId
            let contentPieceType = contentTypeForIndex[contentNodeIdx % contentCount]
            let matchesTypeFilter = activeTypeFilter == nil || contentPieceType == activeTypeFilter

            var sizeMultiplier: Float = 1.0
            if isSelected {
                sizeMultiplier = isThisContent ? 1.5 : 0.3
            } else if activeTypeFilter != nil {
                sizeMultiplier = matchesTypeFilter ? 1.4 : 0.15
            }

            // Future pieces render at 0.8x normal size
            let futureSizeMult: Float = isFutureNode[i] ? 0.8 : 1.0

            let s = CGFloat(baseSizes[i] * Config.size * (0.7 + depthScale * 0.3) * zoomSizeMult * sizeMultiplier * futureSizeMult)
            contentPieceNodes[i].scale = SCNVector3(s, s, s)

            // Edge fade (future pieces capped at 50% base opacity; pulse animation handles the rest)
            let baseFade = fadeOpacity(t: t)
            if isFutureNode[i] {
                contentPieceNodes[i].opacity = CGFloat(baseFade * 0.5)
            } else {
                contentPieceNodes[i].opacity = CGFloat(baseFade)
            }
        }

        // Spine rotation (matches React: spineMesh.rotation.x = elapsed * 0.015)
        spineNode?.eulerAngles.x = elapsed * 0.015

        // Timeline drift (moves with content flow)
        let flowShift = (elapsed * 0.008).truncatingRemainder(dividingBy: 1.0) * Config.streamLength
        timelineGroup?.position.x = -flowShift

        // Update connection lines
        let selId = selectedContentId
        for (li, pair) in linkPairs.enumerated() {
            let (a, b) = pair
            guard a < positions.count, b < positions.count else { continue }
            let posA = positions[a]
            let posB = positions[b]

            // Regular line
            if li < linkLineNodes.count {
                orientCylinder(linkLineNodes[li], from: posA, to: posB)
            }

            // Selected highlight
            if li < selectedLinkLineNodes.count {
                let nodeIdA = contentIDs[contentIndices[a]]
                let nodeIdB = contentIDs[contentIndices[b]]
                let isConn = selId != nil && (nodeIdA == selId || nodeIdB == selId)
                if isConn {
                    orientCylinder(selectedLinkLineNodes[li], from: posA, to: posB)
                    selectedLinkLineNodes[li].isHidden = false
                } else {
                    selectedLinkLineNodes[li].isHidden = true
                }
            }
        }

        // Drift stars downward
        let spread = Config.starSpread
        for i in 0..<starNodes.count {
            var pos = starNodes[i].position
            pos.y -= starSpeeds[i]
            if pos.y < -spread / 2 {
                pos.y = spread / 2
                pos.x = Float.random(in: -spread...spread)
            }
            starNodes[i].position = pos
        }

        // Camera system
        updateCamera(elapsed: elapsed, vl: vl)
    }

    // MARK: - Camera System

    private func updateCamera(elapsed: Float, vl: Float) {
        guard let camera = cameraNode else { return }

        let camLerp: Float = 0.035

        if let targetPos = targetCamPos, let targetLook = targetLookAt {
            // Zoomed into a selected content piece
            camera.position.x += (targetPos.x - camera.position.x) * camLerp
            camera.position.y += (targetPos.y - camera.position.y) * camLerp
            camera.position.z += (targetPos.z - camera.position.z) * camLerp
            camera.look(at: SCNVector3(targetLook.x, targetLook.y, targetLook.z))
        } else if isScrubbing || (userControlling && timePosition != 0.5) {
            // Scrubbing: slide along X axis only
            let streamOffset = (timePosition - 0.5) * Config.streamLength * 0.6
            let lookX = streamOffset * (1 - vl)
            let dx = lookX - camera.position.x + Config.cameraPos.x
            camera.position.x += dx * 0.08
            camera.look(at: SCNVector3(lookX, 0, 0))
        } else if !userControlling {
            // Full auto camera: position + zoom level + gentle drift
            let streamOffset = (timePosition - 0.5) * Config.streamLength * 0.6
            let zoomDist = zoomLevel.cameraDistance

            let camStreamX = Config.cameraPos.x + streamOffset + sin(elapsed * 0.12) * 0.3
            let camStreamY = Config.cameraPos.y + cos(elapsed * 0.08) * 0.2
            let camStreamZ = Float(zoomDist)
            let camSpiralX: Float = 12
            let camSpiralY = streamOffset * 0.5
            let camSpiralZ = Float(zoomDist) * 0.5

            let targetX = camStreamX + (camSpiralX - camStreamX) * vl
            let targetY = camStreamY + (camSpiralY - camStreamY) * vl
            let targetZ = camStreamZ + (camSpiralZ - camStreamZ) * vl

            camera.position.x += (targetX - camera.position.x) * camLerp
            camera.position.y += (targetY - camera.position.y) * camLerp
            camera.position.z += (targetZ - camera.position.z) * camLerp

            let lookX = streamOffset * (1 - vl)
            let lookY = streamOffset * 0.3 * vl
            camera.look(at: SCNVector3(lookX, lookY, 0))
        }
    }

    // MARK: - View Mode Toggle

    func setViewMode(_ mode: ExplorerViewMode) {
        viewMode = mode
        viewLerpTarget = mode == .spiral ? 1 : 0
    }

    // MARK: - Light Mode Support

    private func updateLightMode() {
        if lightMode {
            scene?.background.contents = UIColor(hex: "#F0F0F0")
            starMaterial?.diffuse.contents = UIColor(hex: "#222222")
            starMaterial?.transparency = 0.35
            tlLineMaterial?.diffuse.contents = UIColor.black.withAlphaComponent(0.12)
            tlGlowMaterial?.diffuse.contents = UIColor(hex: "#30217C").withAlphaComponent(0.08)
        } else {
            scene?.background.contents = UIColor.black
            starMaterial?.diffuse.contents = UIColor.white
            starMaterial?.transparency = CGFloat(Config.starOpacity)
            tlLineMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.15)
            tlGlowMaterial?.diffuse.contents = UIColor(hex: "#30217C").withAlphaComponent(0.06)
        }
    }

    // MARK: - Reset Camera

    func resetCamera() {
        selectedContentId = nil
        isPaused = false
        targetCamPos = nil
        targetLookAt = nil
        userControlling = false
    }

    // MARK: - Tap Handling

    @objc func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        guard let scnView = scnView else { return }

        let location = gestureRecognizer.location(in: scnView)

        // Hit-test SceneKit nodes first
        let hitResults = scnView.hitTest(location, options: [
            .searchMode: NSNumber(value: SCNHitTestSearchMode.all.rawValue),
            .sortResults: NSNumber(value: true)
        ])

        for hit in hitResults {
            if let nodeName = hit.node.name, nodeName.hasPrefix("content_") {
                let indexStr = nodeName.replacingOccurrences(of: "content_", with: "")
                if let pieceIndex = Int(indexStr), pieceIndex < contentIndices.count {
                    let contentIndex = contentIndices[pieceIndex]
                    let contentId = ContentLibrary.pieces[contentIndex].id

                    // Pause and zoom to content piece
                    isPaused = true
                    let px = positions[pieceIndex]
                    let dist: Float = 8
                    targetLookAt = px
                    targetCamPos = SCNVector3(px.x + dist * 0.3, px.y + dist * 0.2, px.z + dist)
                    selectedContentId = contentId

                    DispatchQueue.main.async { [weak self] in
                        self?.onNodeTapped?(contentId)
                    }
                    return
                }
            }
        }

        // Fallback: project all content pieces to screen and find nearest
        guard cameraNode != nil else { return }

        var bestDist: CGFloat = .greatestFiniteMagnitude
        var bestIndex: Int = -1

        for i in 0..<contentPieceNodes.count {
            let worldPos = contentPieceNodes[i].worldPosition
            let projected = scnView.projectPoint(worldPos)
            if projected.z > 1 { continue }
            let screenPoint = CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
            let dx = screenPoint.x - location.x
            let dy = screenPoint.y - location.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist < bestDist {
                bestDist = dist
                bestIndex = i
            }
        }

        let tapThreshold: CGFloat = 40
        if bestIndex >= 0 && bestDist < tapThreshold {
            let contentIndex = contentIndices[bestIndex]
            let contentId = ContentLibrary.pieces[contentIndex].id

            // Pause and zoom to content piece
            isPaused = true
            let px = positions[bestIndex]
            let dist: Float = 8
            targetLookAt = px
            targetCamPos = SCNVector3(px.x + dist * 0.3, px.y + dist * 0.2, px.z + dist)
            selectedContentId = contentId

            DispatchQueue.main.async { [weak self] in
                self?.onNodeTapped?(contentId)
            }
        }
    }
}

// MARK: - SCNVector3 helpers

private extension SCNVector3 {
    static var zero: SCNVector3 { SCNVector3(0, 0, 0) }
}
