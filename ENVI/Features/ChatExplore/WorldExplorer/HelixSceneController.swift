import SceneKit
import UIKit

// MARK: - Helix Scene Controller

/// Manages the SceneKit scene: 500 particle nodes arranged in a horizontal helix,
/// continuous animation, camera drift, and tap-to-select hit testing.
final class HelixSceneController: NSObject, SCNSceneRendererDelegate {

    // MARK: - Configuration

    private struct Config {
        static let particleCount: Int = 500
        static let streamLength: Float = 77
        static let streamRadius: Float = 10
        static let nodeSize: Float = 1.1
        static let fadeLen: Float = 0.345
        static let cameraFov: CGFloat = 97
        static let cameraPosition = SCNVector3(-4, 4, 26)
        static let speed: Float = 1.0
        static let sizeDepthBias: Float = 0.89
    }

    // MARK: - Properties

    private weak var scnView: SCNView?
    private var scene: SCNScene?
    private var cameraNode: SCNNode?

    /// Per-particle state
    private var streamTs: [Float] = []          // [0,1] position along helix
    private var phases: [Float] = []            // random per-particle phase offset
    private var baseSizes: [Float] = []         // base scale
    private var contentIndices: [Int] = []      // maps particle → content piece index (0..<14)
    private var particleNodes: [SCNNode] = []   // the plane nodes

    /// Textures loaded from bundle
    private var textures: [UIImage] = []

    /// Callbacks
    var onNodeTapped: ((String) -> Void)?
    var onSceneReady: (() -> Void)?

    /// Animation clock
    private var startTime: TimeInterval = 0
    private var isSetUp = false

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
        cameraNode.position = Config.cameraPosition
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

        // Create particles
        createParticles(in: scene)

        // Assign to SCNView
        scnView.scene = scene
        scnView.delegate = self
        scnView.isPlaying = true

        isSetUp = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.onSceneReady?()
        }
    }

    // MARK: - Texture Loading

    private func loadTextures() {
        textures = ContentLibrary.imageNames.compactMap { name in
            // Try loading from bundle directly
            if let image = UIImage(named: name) {
                return image
            }
            // Try with jpg extension from Images folder
            if let path = Bundle.main.path(forResource: name, ofType: "jpg", inDirectory: "Images") {
                return UIImage(contentsOfFile: path)
            }
            if let path = Bundle.main.path(forResource: name, ofType: "jpg") {
                return UIImage(contentsOfFile: path)
            }
            // Fallback: generate a placeholder
            return generatePlaceholderImage()
        }

        // Ensure we always have 14 textures
        while textures.count < ContentLibrary.imageNames.count {
            textures.append(generatePlaceholderImage())
        }
    }

    private func generatePlaceholderImage() -> UIImage {
        let size = CGSize(width: 128, height: 180)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor(hex: "#1A1A1A").setFill()
            let path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 16)
            path.fill()
        }
    }

    /// Renders a rounded-rect image texture suitable for a SceneKit plane material.
    private func createRoundedTexture(from image: UIImage, size: CGSize = CGSize(width: 128, height: 180), cornerRadius: CGFloat = 16) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            path.addClip()

            // Draw image cover-fit
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

    // MARK: - Particle Creation

    private func createParticles(in scene: SCNScene) {
        let count = Config.particleCount
        let contentCount = ContentLibrary.imageNames.count

        // Prepare rounded textures
        var roundedTextures: [UIImage] = []
        for tex in textures {
            roundedTextures.append(createRoundedTexture(from: tex))
        }

        // Per-particle arrays
        streamTs = (0..<count).map { _ in Float.random(in: 0...1) }
        phases = (0..<count).map { _ in Float.random(in: 0...(Float.pi * 2)) }
        baseSizes = (0..<count).map { _ in 0.3 + Float.random(in: 0...0.6) }
        contentIndices = (0..<count).map { $0 % contentCount }

        // Shared geometry: vertical plane (aspect ~1:1.4 like the React version)
        let planeGeometry = SCNPlane(width: 1.0, height: 1.4)

        // Create materials (one per content piece for texture sharing)
        var materials: [SCNMaterial] = []
        for i in 0..<contentCount {
            let mat = SCNMaterial()
            mat.diffuse.contents = roundedTextures[i]
            mat.isDoubleSided = true
            mat.lightingModel = .constant  // unlit — no shading, consistent brightness
            mat.transparencyMode = .aOne
            mat.writesToDepthBuffer = false
            mat.readsFromDepthBuffer = true
            materials.append(mat)
        }

        // Container node for all particles
        let helixRoot = SCNNode()
        helixRoot.name = "helixRoot"
        scene.rootNode.addChildNode(helixRoot)

        // Create particle nodes
        particleNodes = []
        for i in 0..<count {
            let node = SCNNode(geometry: planeGeometry.copy() as? SCNGeometry)
            node.geometry?.materials = [materials[contentIndices[i]]]
            node.name = "particle_\(i)"

            // Initial position (will be updated in render loop)
            let pos = helixPosition(t: streamTs[i], phase: phases[i], elapsed: 0)
            node.position = pos

            let s = CGFloat(baseSizes[i] * Config.nodeSize)
            node.scale = SCNVector3(s, s, s)

            // Billboard constraint: always face the camera
            let billboard = SCNBillboardConstraint()
            billboard.freeAxes = [.X, .Y]
            node.constraints = [billboard]

            // Apply initial opacity based on fade
            node.opacity = CGFloat(fadeOpacity(t: streamTs[i]))

            helixRoot.addChildNode(node)
            particleNodes.append(node)
        }
    }

    // MARK: - Helix Math

    /// Computes the 3D position on the horizontal helix given a parameter t ∈ [0,1].
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

    /// Edge-fade opacity: particles near the start/end of the helix fade out.
    private func fadeOpacity(t: Float) -> Float {
        let fadeLen = Config.fadeLen
        if t < fadeLen {
            return t / fadeLen
        } else if t > (1.0 - fadeLen) {
            return (1.0 - t) / fadeLen
        }
        return 1.0
    }

    // MARK: - Frame Update (SCNSceneRendererDelegate)

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard isSetUp else { return }

        if startTime == 0 {
            startTime = time
        }
        let elapsed = Float(time - startTime) * Config.speed

        let count = Config.particleCount
        let cameraPos = cameraNode?.position ?? Config.cameraPosition

        for i in 0..<count {
            // Advance parameter along helix
            var t = streamTs[i] + elapsed * 0.008
            t = t.truncatingRemainder(dividingBy: 1.0)
            if t < 0 { t += 1.0 }

            // Compute position
            let pos = helixPosition(t: t, phase: phases[i], elapsed: elapsed)
            particleNodes[i].position = pos

            // Billboard constraint is set once at creation time

            // Depth-based scale
            let dx = cameraPos.x - pos.x
            let dy = cameraPos.y - pos.y
            let dz = cameraPos.z - pos.z
            let dist = sqrt(dx * dx + dy * dy + dz * dz)
            let depthScale = 1.0 / (1.0 + dist * Config.sizeDepthBias * 0.02)
            let s = CGFloat(baseSizes[i] * Config.nodeSize * (0.7 + depthScale * 0.3))
            particleNodes[i].scale = SCNVector3(s, s, s)

            // Edge fade
            particleNodes[i].opacity = CGFloat(fadeOpacity(t: t))
        }

        // Gentle camera drift
        let driftX = sin(elapsed * 0.05) * 0.3
        let driftY = cos(elapsed * 0.07) * 0.2
        cameraNode?.position = SCNVector3(
            Config.cameraPosition.x + Float(driftX),
            Config.cameraPosition.y + Float(driftY),
            Config.cameraPosition.z
        )
    }

    // MARK: - Tap Handling

    @objc func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        guard let scnView = scnView else { return }

        let location = gestureRecognizer.location(in: scnView)
        let hitResults = scnView.hitTest(location, options: [
            .searchMode: NSNumber(value: SCNHitTestSearchMode.all.rawValue),
            .sortResults: NSNumber(value: true)
        ])

        // Find the first hit on a particle node
        for hit in hitResults {
            if let nodeName = hit.node.name, nodeName.hasPrefix("particle_") {
                let indexStr = nodeName.replacingOccurrences(of: "particle_", with: "")
                if let particleIndex = Int(indexStr) {
                    let contentIndex = contentIndices[particleIndex]
                    let contentId = ContentLibrary.pieces[contentIndex].id
                    DispatchQueue.main.async { [weak self] in
                        self?.onNodeTapped?(contentId)
                    }
                    return
                }
            }
        }

        // Fallback: project all particles to screen and find nearest (more reliable for small nodes)
        guard cameraNode != nil else { return }

        var bestDist: CGFloat = .greatestFiniteMagnitude
        var bestIndex: Int = -1

        for i in 0..<particleNodes.count {
            let worldPos = particleNodes[i].worldPosition
            let projected = scnView.projectPoint(worldPos)

            // projected.z > 1 means behind camera
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

        let tapThreshold: CGFloat = 40 // points
        if bestIndex >= 0 && bestDist < tapThreshold {
            let contentIndex = contentIndices[bestIndex]
            let contentId = ContentLibrary.pieces[contentIndex].id
            DispatchQueue.main.async { [weak self] in
                self?.onNodeTapped?(contentId)
            }
        }
    }
}
