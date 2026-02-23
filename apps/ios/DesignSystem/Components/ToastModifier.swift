import SwiftUI

public enum ToastStyle {
    case success
    case error
    case info
    
    var themeColor: Color {
        switch self {
        case .success: return Theme.Colors.success
        case .error: return Theme.Colors.error
        case .info: return Theme.Colors.violetAccent
        }
    }
    
    var iconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

public struct Toast: Equatable {
    var id = UUID()
    var message: String
    var style: ToastStyle
    var duration: TimeInterval = 3.0
    
    public init(message: String, style: ToastStyle = .info, duration: TimeInterval = 3.0) {
        self.message = message
        self.style = style
        self.duration = duration
    }
}

public struct ToastModifier: ViewModifier {
    @Binding var toast: Toast?
    @State private var workItem: DispatchWorkItem?
    
    public func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                ZStack {
                    mainToastView()
                        .offset(y: toast == nil ? -100 : 0)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: toast)
                , alignment: .top
            )
            .onChange(of: toast) {
                showToast()
            }
    }
    
    @ViewBuilder private func mainToastView() -> some View {
        if let toast = toast {
            HStack(alignment: .center, spacing: Theme.Spacing.sm) {
                Image(systemName: toast.style.iconName)
                    .foregroundColor(toast.style.themeColor)
                    .font(.system(size: 16))
                
                Text(toast.message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(2)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Colors.bgSecondary.opacity(0.95))
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Theme.Colors.glassBorder, lineWidth: 1)
            )
            .padding(.top, 50) // Safe area inset approx
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
            .onTapGesture {
                dismissToast()
            }
        }
    }
    
    private func showToast() {
        guard let toast = toast else { return }
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        workItem?.cancel()
        
        let task = DispatchWorkItem {
            dismissToast()
        }
        
        workItem = task
        DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration, execute: task)
    }
    
    private func dismissToast() {
        withAnimation {
            toast = nil
        }
        workItem?.cancel()
        workItem = nil
    }
}

public extension View {
    func toastView(toast: Binding<Toast?>) -> some View {
        self.modifier(ToastModifier(toast: toast))
    }
}
