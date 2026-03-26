import UIKit

/// UIKit view that manages a stack of swipeable cards.
/// Uses UIPanGestureRecognizer with an 80pt threshold for pass/approve actions.
final class SwipeableCardStack: UIView {

    var onSwipeLeft: ((Int) -> Void)?   // Pass
    var onSwipeRight: ((Int) -> Void)?  // Approve

    private var cardViews: [UIView] = []
    private var currentIndex = 0
    private let swipeThreshold: CGFloat = 80.0

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Load a set of card views into the stack.
    func loadCards(_ cards: [UIView]) {
        // Remove old cards
        cardViews.forEach { $0.removeFromSuperview() }
        cardViews = cards
        currentIndex = 0

        // Add in reverse so first card is on top
        for (index, card) in cards.enumerated().reversed() {
            addSubview(card)
            card.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                card.topAnchor.constraint(equalTo: topAnchor, constant: CGFloat(index) * 4),
                card.leadingAnchor.constraint(equalTo: leadingAnchor, constant: CGFloat(index) * 2),
                card.trailingAnchor.constraint(equalTo: trailingAnchor, constant: CGFloat(index) * -2),
                card.bottomAnchor.constraint(equalTo: bottomAnchor, constant: CGFloat(index) * -4),
            ])

            // Scale down background cards slightly
            let scale = 1.0 - (CGFloat(index) * 0.03)
            card.transform = CGAffineTransform(scaleX: scale, y: scale)
            card.alpha = index == 0 ? 1.0 : 0.85

            // Only the top card gets gesture
            if index == 0 {
                let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
                card.addGestureRecognizer(pan)
                card.isUserInteractionEnabled = true
            }
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let card = gesture.view else { return }
        let translation = gesture.point(in: self).x - bounds.midX

        switch gesture.state {
        case .changed:
            let normalizedX = translation / bounds.width
            let rotation = normalizedX * 0.15
            card.transform = CGAffineTransform(translationX: translation, y: 0)
                .rotated(by: rotation)

            // Show pass/approve overlay
            if let contentCard = card as? ContentCardView {
                contentCard.passOverlay.alpha = max(0, -translation / swipeThreshold) * 0.8
                contentCard.approveOverlay.alpha = max(0, translation / swipeThreshold) * 0.8
            } else if let textCard = card as? TextPostCardView {
                textCard.passOverlay.alpha = max(0, -translation / swipeThreshold) * 0.8
                textCard.approveOverlay.alpha = max(0, translation / swipeThreshold) * 0.8
            }

        case .ended:
            let velocity = gesture.velocity(in: self).x
            if translation > swipeThreshold || velocity > 500 {
                animateCardOff(card, direction: .right)
            } else if translation < -swipeThreshold || velocity < -500 {
                animateCardOff(card, direction: .left)
            } else {
                springBack(card)
            }

        default:
            break
        }
    }

    private enum SwipeDirection { case left, right }

    private func animateCardOff(_ card: UIView, direction: SwipeDirection) {
        let targetX: CGFloat = direction == .right ? bounds.width * 1.5 : -bounds.width * 1.5
        let rotation: CGFloat = direction == .right ? 0.3 : -0.3

        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            card.transform = CGAffineTransform(translationX: targetX, y: 0).rotated(by: rotation)
            card.alpha = 0
        } completion: { _ in
            card.removeFromSuperview()
            if direction == .left {
                self.onSwipeLeft?(self.currentIndex)
            } else {
                self.onSwipeRight?(self.currentIndex)
            }
            self.currentIndex += 1
            self.promoteNextCard()
        }
    }

    private func springBack(_ card: UIView) {
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.3) {
            card.transform = .identity
            if let contentCard = card as? ContentCardView {
                contentCard.passOverlay.alpha = 0
                contentCard.approveOverlay.alpha = 0
            } else if let textCard = card as? TextPostCardView {
                textCard.passOverlay.alpha = 0
                textCard.approveOverlay.alpha = 0
            }
        }
    }

    private func promoteNextCard() {
        guard let topCard = subviews.last else { return }
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        topCard.addGestureRecognizer(pan)
        topCard.isUserInteractionEnabled = true

        UIView.animate(withDuration: 0.3) {
            topCard.transform = .identity
            topCard.alpha = 1.0
        }
    }
}
