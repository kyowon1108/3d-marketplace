import SwiftUI
import RealityKit

@available(iOS 17.0, *)
struct NativeCaptureView: View {
    @Bindable var viewModel: SellNewViewModel

    @State private var engine = SweepCaptureEngine()
    @State private var isFinalizingCapture = false
    @State private var shouldCancelOnDisappear = true

    var body: some View {
        ZStack {
            if ObjectCaptureSession.isSupported {
                switch engine.state {
                case .idle, .initializing:
                    ProgressView("LiDAR 카메라를 준비하는 중...")
                        .tint(Theme.Colors.violetAccent)
                        .onAppear { engine.start() }

                case .ready(let session):
                    ObjectCaptureView(session: session)
                        .ignoresSafeArea()

                    VStack {
                        Spacer()
                        captureControls(session: session)
                    }

                case .failed(let message):
                    VStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                        Text(message)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            } else {
                NativeCaptureViewMock(viewModel: viewModel)
                    .onAppear {
                        NotificationCenter.default.post(
                            name: .showToast,
                            object: Toast(message: "LiDAR 센서가 탑재된 기기에서만 지원됩니다. 데모 모드로 실행합니다.", style: .info)
                        )
                    }
            }
        }
        .onDisappear {
            if shouldCancelOnDisappear {
                engine.cancel()
            }
        }
    }

    @ViewBuilder
    private func captureControls(session: ObjectCaptureSession) -> some View {
        HStack(spacing: Theme.Spacing.xl) {
            Button("Cancel") {
                engine.cancel()
                viewModel.reset()
            }
            .foregroundColor(.white)

            if case .ready = session.state {
                Button(action: { _ = session.startDetecting() }) {
                    Image(systemName: "viewfinder.circle.fill")
                        .font(.system(size: 70))
                        .foregroundColor(Theme.Colors.violetAccent)
                        .shadow(color: Theme.Colors.neonGlow, radius: 10)
                }
            } else if case .detecting = session.state {
                Button(action: { session.startCapturing() }) {
                    Image(systemName: "record.circle")
                        .font(.system(size: 70))
                        .foregroundColor(.red)
                }
            } else if case .capturing = session.state {
                if isFinalizingCapture {
                    ProgressView()
                        .tint(.white)
                } else {
                    Button(action: finalizeCapture) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 70))
                            .foregroundColor(.green)
                    }
                }
            } else {
                ProgressView()
                    .tint(.white)
            }

            Button("수동") {
                // Manual capture toggle placeholder
            }
            .foregroundColor(.white)
        }
        .padding(.bottom, 40)
        .background(
            VStack {
                Spacer()
                Rectangle()
                    .fill(Theme.Colors.bgPrimary.opacity(0.8))
                    .frame(height: 120)
                    .blur(radius: 20)
            }
            .ignoresSafeArea()
        )
    }

    private func finalizeCapture() {
        guard !isFinalizingCapture else { return }
        isFinalizingCapture = true
        shouldCancelOnDisappear = false

        Task {
            do {
                try await engine.finishAndAwaitCompletion()
                viewModel.capturedFolderURL = engine.imagesDirectory
                viewModel.finishCaptureAndStartModeling()
            } catch {
                isFinalizingCapture = false
                shouldCancelOnDisappear = true
                NotificationCenter.default.post(
                    name: .showToast,
                    object: Toast(message: "캡처 마무리에 실패했습니다. 조명을 밝게 하고 다시 시도해주세요.", style: .error)
                )
            }
        }
    }
}
