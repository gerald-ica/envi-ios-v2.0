import UIKit

/// CALayer-based spiral animation using CAReplicatorLayer.
/// Creates a mesmerizing spiral of white dots that rotates continuously.
final class SplashSpiralView: UIView {

    private let replicatorLayer = CAReplicatorLayer()
    private let dotLayer = CAShapeLayer()
    private var displayLink: CADisplayLink?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        setupSpiral()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        replicatorLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
    }

    private func setupSpiral() {
        let instanceCount = 100
        let dotSize: CGFloat = 3.0

        // Configure replicator
        replicatorLayer.instanceCount = instanceCount
        replicatorLayer.instanceDelay = 0.02

        // Each instance is slightly rotated and scaled
        let angle = (2 * CGFloat.pi * 3) / CGFloat(instanceCount) // 3 full rotations
        var transform = CATransform3DIdentity
        transform = CATransform3DRotate(transform, angle, 0, 0, 1)
        transform = CATransform3DTranslate(transform, 0.8, 0.8, 0)
        transform = CATransform3DScale(transform, 0.99, 0.99, 1)
        replicatorLayer.instanceTransform = transform

        // Fade each instance slightly
        replicatorLayer.instanceAlphaOffset = -0.008

        // Dot shape
        dotLayer.frame = CGRect(x: 0, y: 0, width: dotSize, height: dotSize)
        dotLayer.backgroundColor = UIColor.white.cgColor
        dotLayer.cornerRadius = dotSize / 2
        dotLayer.position = CGPoint(x: 80, y: 0) // offset from center

        replicatorLayer.addSublayer(dotLayer)
        layer.addSublayer(replicatorLayer)
    }

    func startAnimation() {
        // Rotation animation
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = CGFloat.pi * 2
        rotation.duration = 8.0
        rotation.repeatCount = .infinity
        rotation.timingFunction = CAMediaTimingFunction(name: .linear)
        replicatorLayer.add(rotation, forKey: "rotation")

        // Scale pulse
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.9
        scale.toValue = 1.1
        scale.duration = 3.0
        scale.autoreverses = true
        scale.repeatCount = .infinity
        scale.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        replicatorLayer.add(scale, forKey: "scale")

        // Dot opacity pulse
        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 0.3
        opacity.toValue = 1.0
        opacity.duration = 1.5
        opacity.autoreverses = true
        opacity.repeatCount = .infinity
        dotLayer.add(opacity, forKey: "opacity")
    }

    func stopAnimation() {
        replicatorLayer.removeAllAnimations()
        dotLayer.removeAllAnimations()
        displayLink?.invalidate()
        displayLink = nil
    }

    deinit {
        stopAnimation()
    }
}
