import UIKit

/// Full-screen splash screen with animated spiral and "hello" text.
/// Auto-transitions to onboarding after 5 seconds.
final class SplashViewController: UIViewController {

    var onComplete: (() -> Void)?

    private let spiralView = SplashSpiralView()
    private let helloLabel: UILabel = {
        let label = UILabel()
        label.text = "ENVI"
        label.font = .spaceMonoBold(48)
        label.textColor = .white
        label.textAlignment = .center
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private var transitionTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        navigationController?.setNavigationBarHidden(true, animated: false)
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        spiralView.startAnimation()
        animateHelloText()
        scheduleTransition()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        spiralView.stopAnimation()
        transitionTimer?.invalidate()
    }

    private func setupUI() {
        // Spiral
        spiralView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spiralView)

        // Hello label
        view.addSubview(helloLabel)

        NSLayoutConstraint.activate([
            spiralView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spiralView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            spiralView.widthAnchor.constraint(equalToConstant: 300),
            spiralView.heightAnchor.constraint(equalToConstant: 300),

            helloLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            helloLabel.topAnchor.constraint(equalTo: spiralView.bottomAnchor, constant: 24),
        ])
    }

    private func animateHelloText() {
        UIView.animate(withDuration: 1.5, delay: 2.0, options: .curveEaseOut) {
            self.helloLabel.alpha = 1
        }
    }

    private func scheduleTransition() {
        transitionTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.performTransition()
        }
    }

    private func performTransition() {
        UIView.animate(withDuration: 0.5, animations: {
            self.view.alpha = 0
        }) { _ in
            self.onComplete?()
        }
    }
}
