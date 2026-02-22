import SwiftUI

struct AnimatedPanPinchIcon: View {
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    
    var body: some View {
        ZStack {
            // Background Grid (representing AR Plane)
            Image(systemName: "square.grid.3x3")
                .font(.system(size: 80))
                .foregroundColor(Theme.Colors.violetAccent.opacity(0.2))
                .rotation3DEffect(.degrees(60), axis: (x: 1, y: 0, z: 0))
            
            // Hand/Touch Icon
            Image(systemName: "hand.draw.fill")
                .font(.system(size: 60))
                .foregroundColor(Theme.Colors.violetAccent)
                .scaleEffect(scale)
                .offset(offset)
                .shadow(color: Theme.Colors.neonGlow, radius: 10)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                scale = 1.2
                offset = CGSize(width: 20, height: -20)
            }
        }
    }
}
