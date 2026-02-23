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
                    ZStack {
                        ObjectCaptureView(session: session)
                            .ignoresSafeArea()
                            .task {
                                for await state in session.stateUpdates {
                                    if case .completed = state {
                                        viewModel.capturedFolderURL = engine.imagesDirectory
                                        viewModel.finishCaptureAndStartModeling()
                                    }
                                }
                            }
                        
                        VStack {
                            HStack {
                                Spacer()
                                Button(action: {
                                    engine.cancel()
                                    viewModel.reset()
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(Color.white.opacity(0.8))
                                        .background(Circle().fill(Color.black.opacity(0.4)))
                                }
                                .padding()
                                .padding(.top, 40)
                            }
                            Spacer()
                        }
                        
                        VStack {
                            Spacer()
                            captureControls(session: session)
                        }
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
            if case .ready = session.state {
                Button(action: { _ = session.startDetecting() }) {
                    Text("계속하기")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Theme.Colors.violetAccent)
                        .clipShape(Capsule())
                }
            } else if case .detecting = session.state {
                Button(action: { session.startCapturing() }) {
                    Image(systemName: "record.circle")
                        .font(.system(size: 70))
                        .foregroundColor(.red)
                        .background(Circle().fill(Color.white))
                        .clipShape(Circle())
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
                            .background(Circle().fill(Color.white))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(.bottom, 60)
    }

    private func finalizeCapture() {
        guard !isFinalizingCapture else { return }
        isFinalizingCapture = true
        shouldCancelOnDisappear = false

        Task {
            do {
                try await engine.finishAndAwaitCompletion()
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
