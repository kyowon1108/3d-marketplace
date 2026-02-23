import SwiftUI

@main
struct MarketplaceApp: App {
    @State private var toast: Toast? = nil
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .toastView(toast: $toast)
                .onReceive(NotificationCenter.default.publisher(for: .showToast)) { notification in
                    if let newToast = notification.object as? Toast {
                        self.toast = newToast
                    }
                }
        }
    }
}

// Global Toast Notification Helper
extension Notification.Name {
    static let showToast = Notification.Name("showToast")
    static let switchToHomeTab = Notification.Name("switchToHomeTab")
}

func AppToast(message: String, style: ToastStyle = .info) {
    let toast = Toast(message: message, style: style)
    NotificationCenter.default.post(name: .showToast, object: toast)
}
