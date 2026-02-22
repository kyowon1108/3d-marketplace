import SwiftUI

public struct ShimmerModifier: ViewModifier {
    @State private var isAnimating = false

    public func body(content: Content) -> some View {
        content
            .overlay(
                // A subtle violet/white gradient moving across the component
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.0),
                        Color.white.opacity(0.05),
                        Theme.Colors.violetAccent.opacity(0.1),
                        Color.white.opacity(0.05),
                        Color.white.opacity(0.0)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .offset(x: isAnimating ? 400 : -400, y: 0)
                .blendMode(.screen)
            )
            .animation(
                Animation.linear(duration: 1.5)
                    .repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

public extension View {
    func shimmer() -> some View {
        self.modifier(ShimmerModifier())
    }
}
