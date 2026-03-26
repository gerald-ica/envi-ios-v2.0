import UIKit
import SwiftUI

extension UIViewController {
    /// Embed a SwiftUI view inside this UIKit view controller.
    func hostSwiftUIView<V: View>(_ view: V) {
        let hostingController = UIHostingController(rootView: view)
        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: self.view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
        ])
        hostingController.didMove(toParent: self)
    }

    /// Set the background color to ENVI dark theme
    func setENVIDarkBackground() {
        view.backgroundColor = ENVITheme.UIKit.backgroundDark
    }
}
