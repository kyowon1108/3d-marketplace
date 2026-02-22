import SwiftUI

struct ProcessingGateView: View {
    @Bindable var viewModel: SellNewViewModel
    
    private var hasError: Bool {
        (viewModel.currentStep == .modeling && viewModel.modelingError != nil) ||
        (viewModel.currentStep == .upload && viewModel.uploadError != nil)
    }

    private var errorMessage: String? {
        if viewModel.currentStep == .modeling { return viewModel.modelingError }
        if viewModel.currentStep == .upload { return viewModel.uploadError }
        return nil
    }

    var body: some View {
        ZStack {
            Theme.Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: Theme.Spacing.xl) {
                // Central Graphic
                ZStack {
                    Circle()
                        .stroke(Theme.Colors.bgSecondary, lineWidth: 8)
                        .frame(width: 150, height: 150)

                    if hasError {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.red)
                    } else {
                        Circle()
                            .trim(from: 0, to: CGFloat(viewModel.processingProgress))
                            .stroke(Theme.Colors.violetAccent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 150, height: 150)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.2), value: viewModel.processingProgress)
                            .shadow(color: Theme.Colors.neonGlow, radius: 10)

                        Text("\(Int(viewModel.processingProgress * 100))%")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                }

                VStack(spacing: Theme.Spacing.xs) {
                    Text(viewModel.currentStep == .modeling ? "Local 3D Reconstruction" : "Uploading Asset")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.Colors.textPrimary)

                    Text(viewModel.processingStatusText)
                        .font(.body)
                        .foregroundColor(hasError ? .red : Theme.Colors.textSecondary)
                }

                if hasError {
                    if let message = errorMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Theme.Spacing.lg)
                    }

                    HStack(spacing: Theme.Spacing.md) {
                        Button(action: {
                            if viewModel.currentStep == .modeling {
                                viewModel.retryModeling()
                            } else {
                                viewModel.startUpload()
                            }
                        }) {
                            Label(viewModel.currentStep == .modeling ? "Retry" : "Retry Upload",
                                  systemImage: "arrow.clockwise")
                                .font(.body.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, Theme.Spacing.lg)
                                .padding(.vertical, Theme.Spacing.sm)
                                .background(Theme.Colors.violetAccent)
                                .clipShape(Capsule())
                        }

                        Button(action: { viewModel.reset() }) {
                            Text("Cancel")
                                .font(.body)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .padding(.horizontal, Theme.Spacing.lg)
                                .padding(.vertical, Theme.Spacing.sm)
                        }
                    }
                } else if viewModel.currentStep == .modeling {
                    Text("This process runs securely on your device.\nFeel free to background the app.")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.top, Theme.Spacing.lg)
                }
            }
        }
    }
}
