import SwiftUI

// MARK: - Glassmorphism Card Modifier
public struct GlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let borderOpacity: Double
    let shadowRadius: CGFloat
    let material: Material

    public init(
        cornerRadius: CGFloat = Theme.Radius.lg,
        borderOpacity: Double = 0.08,
        shadowRadius: CGFloat = 15,
        material: Material = .ultraThinMaterial
    ) {
        self.cornerRadius = cornerRadius
        self.borderOpacity = borderOpacity
        self.shadowRadius = shadowRadius
        self.material = material
    }

    public func body(content: Content) -> some View {
        content
            .background(Theme.Colors.bgSecondary) // Base dark layer
            .background(material)                 // Glass effect
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(borderOpacity), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.5), radius: shadowRadius, x: 0, y: 8)
    }
}

public extension View {
    func glassCardStyle(
        cornerRadius: CGFloat = Theme.Radius.lg,
        borderOpacity: Double = 0.08,
        shadowRadius: CGFloat = 15,
        material: Material = .ultraThinMaterial
    ) -> some View {
        self.modifier(GlassCardModifier(
            cornerRadius: cornerRadius,
            borderOpacity: borderOpacity,
            shadowRadius: shadowRadius,
            material: material
        ))
    }
    
    // Button Interaction scale effect parity
    func pressableScaleEffect() -> some View {
        self.buttonStyle(PressStyle())
    }
}

// Custom button style for scaleEffect(0.98) parity with web UI
private struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}
