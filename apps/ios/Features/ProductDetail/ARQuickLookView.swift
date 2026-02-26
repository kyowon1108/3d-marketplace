import SwiftUI
@preconcurrency import QuickLook
import ARKit

struct ARQuickLookView: UIViewControllerRepresentable {
    var modelURL: URL
    @Binding var isPresented: Bool

    // CTA banner parameters (AR Quick Look URL fragment API)
    var callToAction: String? = nil
    var productTitle: String? = nil
    var sellerName: String? = nil
    var price: String? = nil

    /// Called when the user taps the CTA button in the AR Quick Look banner
    var onCallToAction: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator

        let nav = UINavigationController(rootViewController: controller)
        nav.isNavigationBarHidden = true
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    /// Builds a USDZ URL with AR Quick Look fragment parameters for CTA banner.
    /// Apple AR Quick Look reads the URL fragment to display a banner overlay.
    func buildPreviewURL() -> URL {
        guard callToAction != nil || productTitle != nil else {
            return modelURL
        }

        var fragments: [String] = []

        if let cta = callToAction,
           let encoded = cta.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            fragments.append("callToAction=\(encoded)")
        }
        if let title = productTitle,
           let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            fragments.append("checkoutTitle=\(encoded)")
        }
        if let subtitle = sellerName,
           let encoded = subtitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            fragments.append("checkoutSubtitle=\(encoded)")
        }
        if let price = price,
           let encoded = price.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            fragments.append("price=\(encoded)")
        }

        let fragment = fragments.joined(separator: "&")
        var components = URLComponents(url: modelURL, resolvingAgainstBaseURL: false)!
        components.fragment = fragment
        return components.url ?? modelURL
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource, @preconcurrency QLPreviewControllerDelegate {
        let parent: ARQuickLookView
        private var didFireCTA = false

        init(_ parent: ARQuickLookView) {
            self.parent = parent
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            let previewURL = parent.buildPreviewURL()

            // Use ARQuickLookPreviewItem for proper AR Quick Look integration
            let item = ARQuickLookPreviewItem(fileAt: previewURL)
            item.allowsContentScaling = true

            // canonicalWebPageURL: When CTA is tapped, iOS opens this URL.
            // We use a custom URL scheme that the app can intercept.
            if parent.callToAction != nil {
                item.canonicalWebPageURL = URL(string: "marketplace://ar-inquiry")
            }

            return item
        }

        @MainActor func previewControllerDidDismiss(_ controller: QLPreviewController) {
            parent.isPresented = false
        }

        // MARK: - CTA tap via URL open

        /// Called when Quick Look wants to open a URL (e.g., canonicalWebPageURL on CTA tap).
        /// Return true to handle it ourselves instead of opening Safari.
        @MainActor
        func previewController(
            _ controller: QLPreviewController,
            shouldOpen url: URL,
            for item: QLPreviewItem
        ) -> Bool {
            if url.scheme == "marketplace" && url.host == "ar-inquiry" {
                if !didFireCTA {
                    didFireCTA = true
                    parent.onCallToAction?()
                }
                return false // Don't open in Safari
            }
            return true
        }
    }
}
