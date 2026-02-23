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

    @State private var animateGraphic = false
    @State private var scaleBreath = false
    @State private var dragOffset: CGSize = .zero

    private var currentImageName: String? {
        if hasError { return nil }
        if viewModel.currentStep == .modeling {
            return viewModel.processingProgress < 0.35 ? "GraphicCapture" : "GraphicModeling"
        } else {
            return viewModel.processingProgress < 0.85 ? "GraphicUpload" : "GraphicVerify"
        }
    }

    var body: some View {
        ZStack {
            Theme.Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: Theme.Spacing.xl) {
                // Spacer at top to push down slightly from very top edge, but keep it high
                Spacer().frame(height: 60)
                
                // Top Graphic Area
                ZStack {
                    if hasError {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.red)
                            .transition(.scale.combined(with: .opacity))
                    } else if let imgName = currentImageName {
                        ZStack {
                            // FX Underlay
                            if imgName == "GraphicCapture" {
                                Image("FXGlowRing")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 250, height: 250)
                                    .opacity(0.3)
                                    .offset(y: animateGraphic ? -10 : 10)
                            } else if imgName == "GraphicModeling" {
                                Image("FXGlowRing")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 250, height: 250)
                                    .opacity(0.3)
                                    .offset(y: animateGraphic ? -10 : 10)
                            } else if imgName == "GraphicUpload" {
                                Image("FXUploadParticles")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 200, height: 200)
                                    .opacity(0.4)
                                    .offset(y: animateGraphic ? -10 : 10)
                            } else if imgName == "GraphicVerify" {
                                Image("FXVerifySpark")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 200, height: 200)
                                    .opacity(0.4)
                                    .offset(y: animateGraphic ? -10 : 10)
                            }
                            
                            // Main Cover
                            Image(imgName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 180, height: 180)
                        }
                        .offset(x: dragOffset.width, y: (animateGraphic ? -10 : 10) + dragOffset.height)
                        .rotationEffect(.degrees(Double(dragOffset.width / 14 * 5)))
                        .scaleEffect(scaleBreath ? 1.02 : 0.98)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let x = min(max(value.translation.width, -14), 14)
                                    let y = min(max(value.translation.height, -14), 14)
                                    dragOffset = CGSize(width: x, height: y)
                                }
                                .onEnded { _ in
                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                                        dragOffset = .zero
                                    }
                                }
                        )
                        .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: animateGraphic)
                        .animation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true), value: scaleBreath)
                        .transition(.asymmetric(insertion: .scale(scale: 0.92).combined(with: .opacity).animation(.spring(response: 0.45, dampingFraction: 0.78)), removal: .opacity.animation(.easeOut)))
                        .id(imgName) // Forces view recreation on name change to trigger transition
                        .onAppear { 
                            animateGraphic = true
                            scaleBreath = true
                        }
                    }
                }
                .frame(height: 200)

                // Status Texts
                VStack(spacing: Theme.Spacing.sm) {
                    Text(viewModel.currentStep == .modeling ? "3D 모델 생성 중" : "클라우드로 전송 중")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.Colors.textPrimary)

                    Text(viewModel.processingStatusText)
                        .font(.body)
                        .foregroundColor(hasError ? .red : Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.lg)
                }

                // Straight Progress Bar
                if !hasError {
                    VStack(spacing: 8) {
                        ProgressView(value: viewModel.processingProgress)
                            .progressViewStyle(.linear)
                            .tint(Theme.Colors.violetAccent)
                            .background(Theme.Colors.bgSecondary)
                            .scaleEffect(x: 1, y: 1.5, anchor: .center)
                            .clipShape(Capsule())
                        
                        Text("\(Int(viewModel.processingProgress * 100))%")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Theme.Colors.violetAccent)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, Theme.Spacing.md)
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
                            Label(viewModel.currentStep == .modeling ? "재시도" : "업로드 재시도",
                                  systemImage: "arrow.clockwise")
                                .font(.body.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, Theme.Spacing.lg)
                                .padding(.vertical, Theme.Spacing.sm)
                                .background(Theme.Colors.violetAccent)
                                .clipShape(Capsule())
                        }

                        Button(action: { viewModel.reset() }) {
                            Text("취소")
                                .font(.body)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .padding(.horizontal, Theme.Spacing.lg)
                                .padding(.vertical, Theme.Spacing.sm)
                        }
                    }
                } else if viewModel.currentStep == .modeling {
                    Text("이 작업은 기기에서 안전하게 진행됩니다.\n앱을 백그라운드로 전환해도 됩니다.")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.top, Theme.Spacing.lg)
                }
                
                Spacer() // Pushes everything towards top
            }
        }
    }
}
