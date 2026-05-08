import UIKit

// MARK: - Star data
private struct Star {
    let angle: CGFloat
    let distance: CGFloat
    let rotDir: CGFloat
    let expRate: CGFloat
    let finalScale: CGFloat
    let dx: CGFloat
    let dy: CGFloat
    let spiralLoc: CGFloat
    let z: CGFloat
    let swFactor: CGFloat
}

/// Full particle-based spiral animation matching the ENVI web preview exactly.
/// Uses CADisplayLink + Core Graphics for a 3000-star system with 3D projection,
/// elastic easing, spiral path, and camera travel.
final class SplashSpiralView: UIView {
    // MARK: - Constants (identical to JS)
    private let changeEventTime: CGFloat = 0.32
    private let cameraZ: CGFloat = -400
    private let cameraTravelDistance: CGFloat = 3400
    private let startDotYOffset: CGFloat = 28
    private let viewZoom: CGFloat = 100
    private let numberOfStars = 3000
    private let trailLength = 80
    private let animDuration: CGFloat = 15

    // MARK: - State
    private var stars: [Star] = []
    private var animTime: CGFloat = 0
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
        createStars()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Seeded random (same seed=1234 as JS)
    private var seed: UInt64 = 1234

    private func seededRandom() -> CGFloat {
        seed = (seed &* 9301 &+ 49297) % 233280
        return CGFloat(seed) / 233280.0
    }

    // MARK: - Create stars (deterministic, matches JS exactly)
    private func createStars() {
        seed = 1234
        stars.reserveCapacity(numberOfStars)
        for _ in 0..<numberOfStars {
            let angle = seededRandom() * .pi * 2
            let distance = 30 * seededRandom() + 15
            let rotDir: CGFloat = seededRandom() > 0.5 ? 1 : -1
            let expRate = 1.2 + seededRandom() * 0.8
            let finalScale = 0.7 + seededRandom() * 0.6
            let dx = distance * cos(angle)
            let dy = distance * sin(angle)
            let spiralLoc = (1 - pow(1 - seededRandom(), 3.0)) / 1.3
            var z = (0.5 * cameraZ) + seededRandom() * (cameraTravelDistance + cameraZ - 0.5 * cameraZ)
            z = lerp(z, cameraTravelDistance / 2, 0.3 * spiralLoc)
            let swFactor = pow(seededRandom(), 2.0)
            stars.append(Star(
                angle: angle,
                distance: distance,
                rotDir: rotDir,
                expRate: expRate,
                finalScale: finalScale,
                dx: dx,
                dy: dy,
                spiralLoc: spiralLoc,
                z: z,
                swFactor: swFactor
            ))
        }
    }

    // MARK: - Easing functions (identical to JS)
    private func ease(_ p: CGFloat, _ g: CGFloat) -> CGFloat {
        if p < 0.5 {
            return 0.5 * pow(2 * p, g)
        } else {
            return 1 - 0.5 * pow(2 * (1 - p), g)
        }
    }

    private func easeOutElastic(_ x: CGFloat) -> CGFloat {
        let c4 = (2 * .pi) / 4.5
        if x <= 0 { return 0 }
        if x >= 1 { return 1 }
        return pow(2, -8 * x) * sin((x * 8 - 0.75) * c4) + 1
    }

    private func map(_ value: CGFloat, _ s1: CGFloat, _ e1: CGFloat, _ s2: CGFloat, _ e2: CGFloat) -> CGFloat {
        s2 + (e2 - s2) * ((value - s1) / (e1 - s1))
    }

    private func constrain(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        min(max(v, lo), hi)
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a * (1 - t) + b * t
    }

    // MARK: - Spiral path (identical to JS)
    private func spiralPath(_ p: CGFloat) -> CGPoint {
        var p = constrain(1.2 * p, 0, 1)
        p = ease(p, 1.8)
        let turns: CGFloat = 6
        let theta = 2 * .pi * turns * sqrt(p)
        let r = 170 * sqrt(p)
        return CGPoint(x: r * cos(theta), y: r * sin(theta) + startDotYOffset)
    }

    // MARK: - 3D -> 2D projection (identical to JS)
    private func showProjectedDot(_ context: CGContext, px: CGFloat, py: CGFloat, pz: CGFloat, sizeFactor: CGFloat) {
        let t2 = constrain(map(animTime, changeEventTime, 1, 0, 1), 0, 1)
        let newCamZ = cameraZ + ease(pow(t2, 1.2), 1.8) * cameraTravelDistance
        guard pz > newCamZ else { return }
        let depth = pz - newCamZ
        let x = viewZoom * px / depth
        let y = viewZoom * py / depth
        let sw = 400 * sizeFactor / depth
        let radius = max(sw / 2, 0.3)
        context.fillEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
    }

    // MARK: - Render star (identical to JS)
    private func renderStar(_ context: CGContext, star: Star, p: CGFloat) {
        let sp = spiralPath(star.spiralLoc)
        let q = p - star.spiralLoc
        guard q > 0 else { return }

        let dp = constrain(4 * q, 0, 1)
        let linE = dp
        let elE = easeOutElastic(dp)
        let powE = pow(dp, 2)

        let easing: CGFloat
        if dp < 0.3 {
            easing = lerp(linE, powE, dp / 0.3)
        } else if dp < 0.7 {
            easing = lerp(powE, elE, (dp - 0.3) / 0.4)
        } else {
            easing = elE
        }

        let sx: CGFloat
        let sy: CGFloat

        if dp < 0.3 {
            sx = lerp(sp.x, sp.x + star.dx * 0.3, easing / 0.3)
            sy = lerp(sp.y, sp.y + star.dy * 0.3, easing / 0.3)
        } else if dp < 0.7 {
            let mp = (dp - 0.3) / 0.4
            let cs = sin(mp * .pi) * star.rotDir * 1.5
            let bx = sp.x + star.dx * 0.3
            let by = sp.y + star.dy * 0.3
            let tx = sp.x + star.dx * 0.7
            let ty = sp.y + star.dy * 0.7
            let px = -star.dy * 0.4 * cs
            let py = star.dx * 0.4 * cs
            sx = lerp(bx, tx, mp) + px * mp
            sy = lerp(by, ty, mp) + py * mp
        } else {
            let fp = (dp - 0.7) / 0.3
            let bx = sp.x + star.dx * 0.7
            let by = sp.y + star.dy * 0.7
            let td = star.distance * star.expRate * 1.5
            let st = 1.2 * star.rotDir
            let sa = star.angle + st * fp * .pi
            let tx = sp.x + td * cos(sa)
            let ty = sp.y + td * sin(sa)
            sx = lerp(bx, tx, fp)
            sy = lerp(by, ty, fp)
        }

        let vx = (star.z - cameraZ) * sx / viewZoom
        let vy = (star.z - cameraZ) * sy / viewZoom

        let szMul: CGFloat
        if dp < 0.6 {
            szMul = 1 + dp * 0.2
        } else {
            let t = (dp - 0.6) / 0.4
            szMul = 1.2 * (1 - t) + star.finalScale * t
        }
        let dotSize = 8.5 * star.swFactor * szMul
        showProjectedDot(context, px: vx, py: vy, pz: star.z, sizeFactor: dotSize)
    }

    // MARK: - Main draw (identical to JS render())
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let size = bounds.width

        context.setFillColor(UIColor.black.cgColor)
        context.fill(rect)

        context.saveGState()
        context.translateBy(x: size / 2, y: size / 2)

        let t1 = constrain(map(animTime, 0, changeEventTime + 0.25, 0, 1), 0, 1)
        let t2 = constrain(map(animTime, changeEventTime, 1, 0, 1), 0, 1)

        context.rotate(by: -.pi * ease(t2, 2.7))

        context.setFillColor(UIColor.white.cgColor)
        for i in 0..<trailLength {
            let f = map(CGFloat(i), 0, CGFloat(trailLength), 1.1, 0.1)
            let sw = (1.3 * (1 - t1) + 3.0 * sin(.pi * t1)) * f
            let pathTime = t1 - 0.00015 * CGFloat(i)
            let pos = spiralPath(pathTime)
            let alpha = constrain(f, 0, 1)
            context.setAlpha(alpha)
            let radius = max(sw / 2, 0.3)
            context.fillEllipse(in: CGRect(x: pos.x - radius, y: pos.y - radius, width: radius * 2, height: radius * 2))
        }

        context.setAlpha(1)
        context.setFillColor(UIColor.white.cgColor)
        for star in stars {
            renderStar(context, star: star, p: t1)
        }

        if animTime > changeEventTime {
            let dy = cameraZ * startDotYOffset / viewZoom
            showProjectedDot(context, px: 0, py: dy, pz: cameraTravelDistance, sizeFactor: 2.5)
        }

        context.restoreGState()
    }

    // MARK: - Animation control
    func startAnimation() {
        guard displayLink == nil else { return }
        lastTimestamp = 0
        animTime = 0
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stopAnimation() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = link.timestamp
        }
        let dt = link.timestamp - lastTimestamp
        lastTimestamp = link.timestamp
        animTime = fmod(animTime + CGFloat(dt) / animDuration, 1.0)
        setNeedsDisplay()
    }

    deinit {
        MainActor.assumeIsolated {
            stopAnimation()
        }
    }
}
