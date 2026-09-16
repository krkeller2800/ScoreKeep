import SwiftUI
import UIKit

struct GeneratedPDFShareItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
}

struct SystemShareSheet: UIViewControllerRepresentable {
    let itemURL: URL
    let onComplete: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [itemURL], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            DispatchQueue.main.async {
                onComplete()
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
