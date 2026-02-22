import SwiftUI
@preconcurrency import QuickLook
import ARKit

struct ARQuickLookView: UIViewControllerRepresentable {
    var modelURL: URL
    @Binding var isPresented: Bool

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator

        let nav = UINavigationController(rootViewController: controller)
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    class Coordinator: NSObject, QLPreviewControllerDataSource, @preconcurrency QLPreviewControllerDelegate {
        let parent: ARQuickLookView

        init(_ parent: ARQuickLookView) {
            self.parent = parent
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return parent.modelURL as QLPreviewItem
        }

        @MainActor func previewControllerDidDismiss(_ controller: QLPreviewController) {
            parent.isPresented = false
        }
    }
}
