import SwiftUI
import RealityKit

// NOTE: Native ObjectCaptureView requires iOS 17+.
// This file acts as a mock wrapper since we can't fully compile RealityKit ObjectCaptureSession without target device.
// capturedFolderURL remains nil in mock mode, which signals SellNewViewModel
// to use the simulator/mock code path (generates a dummy 4KB USDZ file).

struct NativeCaptureViewMock: View {
    @Bindable var viewModel: SellNewViewModel
    
    var body: some View {
        ZStack {
            // Camera Feed Mock
            Color.black.ignoresSafeArea()
            
            // Reticle / Guide Ring Mock (Apple HIG)
            Circle()
                .strokeBorder(Theme.Colors.violetAccent, style: StrokeStyle(lineWidth: 3, dash: [10, 5]))
                .frame(width: 250, height: 250)
                .rotationEffect(.degrees(viewModel.processingProgress * 360))
                .animation(.linear(duration: 10).repeatForever(autoreverses: false), value: viewModel.processingProgress)
            
            VStack {
                // Coachmark (HIG)
                Text("Slowly move around the object")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.bgSecondary.opacity(0.8))
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.top, 60)
                
                Spacer()
                
                // Bottom Controls
                HStack(spacing: Theme.Spacing.xl) {
                    Button("Cancel") {
                        viewModel.reset()
                    }
                    .foregroundColor(Theme.Colors.textSecondary)
                    
                    Button(action: {
                        viewModel.finishCaptureAndStartModeling()
                    }) {
                        Image(systemName: "largecircle.fill.circle")
                            .font(.system(size: 70))
                            .foregroundColor(.white)
                    }
                    
                    Button("Manual") {
                        // Manual capture mode
                    }
                    .foregroundColor(Theme.Colors.textSecondary)
                }
                .padding(.bottom, 40)
            }
        }
    }
}
