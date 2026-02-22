import SwiftUI

struct AnimatedScanIcon: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            Image(systemName: "cube.fill")
                .font(.system(size: 80))
                .foregroundColor(Theme.Colors.violetAccent.opacity(0.4))
            
            Circle()
                .trim(from: 0.0, to: 0.3)
                .stroke(Theme.Colors.violetAccent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(rotation))
                .shadow(color: Theme.Colors.neonGlow, radius: 10)
        }
        .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}
