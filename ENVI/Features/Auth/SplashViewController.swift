import UIKit

/// Full-screen splash screen with animated spiral and ENVI wordmark.
final class SplashViewController: UIViewController {

    var onComplete: (() -> Void)?

    private let spiralView = SplashSpiralView()
    // Phase 19 Plan 05 — wordmark asset unified with `ENVIWordmark`.
    // UIKit can't embed a SwiftUI view without a hosting controller and
    // the splash is a narrowly-scoped boot screen, so we match the
    // ENVIWordmark's canonical rendering (SpaceMonoBold 48 pt, tracking
    // -2.0, white on black) manually via NSAttributedString rather than
    // adopting UIHostingConfiguration here.
    private let helloLabel: UILabel = {
        let label = UILabel()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.spaceMonoBold(48),
            .foregroundColor: UIColor.white,
            .kern: -2.0
        ]
        label.attributedText = NSAttributedString(string: "ENVI", attributes: attrs)
        label.textAlignment = .center
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private var transitionWorkItem: DispatchWorkItem?
    private var didFinishTransition = false

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
        transitionWorkItem?.cancel()
        transitionWorkItem = nil
    }

    private func setupUI() {
        spiralView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spiralView)

        view.addSubview(helloLabel)

        NSLayoutConstraint.activate([
            spiralView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            spiralView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            spiralView.topAnchor.constraint(equalTo: view.topAnchor),
            spiralView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            helloLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            helloLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -72),
        ])
    }

    private func animateHelloText() {
        UIView.animate(withDuration: 1.5, delay: 2.0, options: .curveEaseOut) {
            self.helloLabel.alpha = 1
        }
    }

    private func scheduleTransition() {
        guard !didFinishTransition, transitionWorkItem == nil else { return }

        let workItem = DispatchWorkItem { [weak self] in
            self?.performTransition()
        }
        transitionWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: workItem)
    }

    private func performTransition() {
        guard !didFinishTransition else { return }
        didFinishTransition = true
        transitionWorkItem?.cancel()
        transitionWorkItem = nil

        UIView.animate(withDuration: 0.5, animations: {
            self.view.alpha = 0
        }) { _ in
            self.onComplete?()
        }
    }
}
