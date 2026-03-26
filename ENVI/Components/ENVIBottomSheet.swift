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
