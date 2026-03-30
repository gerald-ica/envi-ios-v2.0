import SwiftUI
import UIKit

/// SwiftUI wrapper for presenting the UIKit editor from SwiftUI flows.
struct EditorContainerView: UIViewControllerRepresentable {
    let contentPiece: ContentPiece?
    let contentItem: ContentItem?

    init(contentPiece: ContentPiece) {
        self.contentPiece = contentPiece
        self.contentItem = nil
    }

    init(contentItem: ContentItem) {
        self.contentPiece = nil
        self.contentItem = contentItem
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        let editor = EditorViewController(contentItem: contentItem, contentPiece: contentPiece)
        let navigationController = UINavigationController(rootViewController: editor)
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.modalPresentationStyle = .fullScreen
        return navigationController
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}
