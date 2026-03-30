import UIKit

/// Custom UIKit bottom sheet presentation controller.
final class ENVIBottomSheetController: UIPresentationController {

    private let dimmingView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        view.alpha = 0
        return view
    }()

    private let sheetHeight: CGFloat

    init(presentedViewController: UIViewController,
         presenting presentingViewController: UIViewController?,
         height: CGFloat = 400) {
        self.sheetHeight = height
        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
    }

    override var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView else { return .zero }
        return CGRect(
            x: 0,
            y: containerView.bounds.height - sheetHeight,
            width: containerView.bounds.width,
            height: sheetHeight
        )
    }

    override func presentationTransitionWillBegin() {
        guard let containerView else { return }

        dimmingView.frame = containerView.bounds
        containerView.insertSubview(dimmingView, at: 0)

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissSheet))
        dimmingView.addGestureRecognizer(tap)

        presentedViewController.transitionCoordinator?.animate(alongsideTransition: { _ in
            self.dimmingView.alpha = 1
        })

        // Round top corners
        presentedView?.layer.cornerRadius = ENVIRadius.xl
        presentedView?.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        presentedView?.clipsToBounds = true

        // Drag-to-dismiss gesture
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        presentedView?.addGestureRecognizer(pan)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let presentedView, let containerView else { return }

        let translation = gesture.translation(in: containerView)
        let velocity = gesture.velocity(in: containerView)
        let sheetOriginY = containerView.bounds.height - sheetHeight

        switch gesture.state {
        case .changed:
            // Only allow dragging downward (positive Y translation)
            let newY = max(sheetOriginY, sheetOriginY + translation.y)
            presentedView.frame.origin.y = newY

            // Fade dimming view proportionally
            let progress = translation.y / sheetHeight
            dimmingView.alpha = 1 - min(max(progress, 0), 1)

        case .ended, .cancelled:
            let dismissThreshold = sheetHeight * 0.3
            let shouldDismiss = translation.y > dismissThreshold || velocity.y > 1000

            if shouldDismiss {
                presentedViewController.dismiss(animated: true)
            } else {
                // Snap back to original position
                UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
                    presentedView.frame.origin.y = sheetOriginY
                    self.dimmingView.alpha = 1
                }
            }

        default:
            break
        }
    }

    override func dismissalTransitionWillBegin() {
        presentedViewController.transitionCoordinator?.animate(alongsideTransition: { _ in
            self.dimmingView.alpha = 0
        })
    }

    override func dismissalTransitionDidEnd(_ completed: Bool) {
        if completed {
            dimmingView.removeFromSuperview()
        }
    }

    @objc private func dismissSheet() {
        presentedViewController.dismiss(animated: true)
    }
}

/// Transition delegate for bottom sheet presentation.
final class ENVIBottomSheetTransitionDelegate: NSObject, UIViewControllerTransitioningDelegate {
    let height: CGFloat

    init(height: CGFloat = 400) {
        self.height = height
    }

    func presentationController(forPresented presented: UIViewController,
                                presenting: UIViewController?,
                                source: UIViewController) -> UIPresentationController? {
        ENVIBottomSheetController(
            presentedViewController: presented,
            presenting: presenting,
            height: height
        )
    }
}
