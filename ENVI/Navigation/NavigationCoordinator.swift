import UIKit

/// Protocol for the coordinator pattern.
@MainActor
protocol Coordinator: AnyObject {
    var navigationController: UINavigationController { get }
    func start()
}

/// Child coordinator support.
@MainActor
protocol ParentCoordinator: Coordinator {
    var childCoordinators: [Coordinator] { get set }
    func addChild(_ coordinator: Coordinator)
    func removeChild(_ coordinator: Coordinator)
}

extension ParentCoordinator {
    func addChild(_ coordinator: Coordinator) {
        childCoordinators.append(coordinator)
    }

    func removeChild(_ coordinator: Coordinator) {
        childCoordinators.removeAll { $0 === coordinator }
    }
}
