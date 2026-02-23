import SwiftUI

struct SellNewView: View {
    @State private var viewModel = SellNewViewModel()
    @State private var showCaptureTutorial = false
    
    var body: some View {
        Group {
            switch viewModel.currentStep {
            case .publish:
                publishFormView()
            case .intro:
                introView()
            case .capture:
                if #available(iOS 17.0, *) {
                    NativeCaptureView(viewModel: viewModel)
                } else {
                    NativeCaptureViewMock(viewModel: viewModel)
                }
            case .modeling, .upload:
                ProcessingGateView(viewModel: viewModel)
            case .success:
                successView()
            }
        }
        .tutorialModal(
            isPresented: $showCaptureTutorial,
            title: "3D 스캐닝 시작하기",
            description: "1. 밝은 조명 아래에 물체를 두세요.\n2. 물체의 중앙을 기준으로 한 바퀴 천천히 돕니다.\n3. 높이를 다르게 하여 3번 반복 스캔해주세요.",
            iconAnimation: AnyView(AnimatedScanIcon()),
            userDefaultsKey: "hasSeenCaptureTutorial_v1"
        )
        .onChange(of: showCaptureTutorial) {
            // When tutorial is dismissed (and user didn't cancel), start capture
            if !showCaptureTutorial && viewModel.currentStep == .intro {
                withAnimation {
                    viewModel.startCapture()
                }
            }
        }
    }
    
    @ViewBuilder
    private func publishFormView() -> some View {
        NavigationStack {
            ZStack {
                Theme.Colors.bgPrimary.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                        
                        // Image / Asset Section
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("에셋 첨부 (필수)")
                                .font(.headline)
                                .foregroundColor(Theme.Colors.textPrimary)
                            
                            if let uploadedAssetId = viewModel.uploadedAssetId {
                                // Captured 3D Model Card
                                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                                    HStack {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.title3)
                                            .foregroundColor(.green)
                                        VStack(alignment: .leading) {
                                            Text("3D 모델 업로드 완료")
                                                .font(.headline)
                                                .foregroundColor(Theme.Colors.textPrimary)
                                            Text("LiDAR 정밀 스캔")
                                                .font(.caption)
                                                .foregroundColor(Theme.Colors.textSecondary)
                                        }
                                        Spacer()
                                        Button("다시 스캔하기") {
                                            withAnimation {
                                                viewModel.currentStep = .intro
                                            }
                                        }
                                        .font(.subheadline.weight(.bold))
                                        .foregroundColor(Theme.Colors.violetAccent)
                                        .accessibilityLabel("3D 모델 다시 스캔")
                                    }

                                    NavigationLink(destination: UploadStatusView(assetId: uploadedAssetId)) {
                                        HStack {
                                            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                            Text("업로드 상태 보기")
                                        }
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(Theme.Colors.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Theme.Colors.bgPrimary)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    .accessibilityLabel("업로드 상태 보기")
                                    .accessibilityHint("업로드 상태 추적 화면으로 이동합니다.")
                                }
                                .padding()
                                .background(Theme.Colors.bgSecondary)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Theme.Colors.violetAccent.opacity(0.3), lineWidth: 1)
                                )
                            } else {
                                Button(action: {
                                    withAnimation {
                                        viewModel.currentStep = .intro
                                    }
                                }) {
                                    VStack(spacing: Theme.Spacing.md) {
                                        Image(systemName: "camera.viewfinder")
                                            .font(.system(size: 32, weight: .regular))
                                        
                                        VStack(spacing: 4) {
                                            Text("LiDAR 스캐너로 현실 물체 캡처하기")
                                                .font(.headline)
                                            Text("현실 물체를 3D로 스캔하여 상품의 가치를 높이세요.")
                                                .font(.caption)
                                                .foregroundColor(Theme.Colors.textSecondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, Theme.Spacing.xl)
                                    .background(Theme.Colors.bgSecondary)
                                    .foregroundColor(Theme.Colors.violetAccent)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                Theme.Colors.violetAccent.opacity(0.3),
                                                style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                                            )
                                    )
                                }
                                .accessibilityLabel("LiDAR 스캔 시작")
                                .accessibilityHint("현실 물체를 스캔해 3D 모델을 업로드합니다.")
                            }
                        }
                        
                        // Text Form Section
                        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("상품명 *")
                                    .font(.headline)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                TextField("예: 빈티지 필름 카메라", text: $viewModel.publishTitle)
                                    .padding()
                                    .background(Theme.Colors.bgSecondary)
                                    .cornerRadius(12)
                                    .foregroundColor(Theme.Colors.textPrimary)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("가격 (원) *")
                                    .font(.headline)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                TextField("예: 15000", text: $viewModel.publishPrice)
                                    .keyboardType(.numberPad)
                                    .padding()
                                    .background(Theme.Colors.bgSecondary)
                                    .cornerRadius(12)
                                    .foregroundColor(Theme.Colors.textPrimary)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("설명 (선택)")
                                    .font(.headline)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                ZStack(alignment: .topLeading) {
                                    if viewModel.publishDescription.isEmpty {
                                        Text("상품의 상태, 특징 등을 설명해주세요")
                                            .foregroundColor(Theme.Colors.textMuted)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 16)
                                    }
                                    TextEditor(text: $viewModel.publishDescription)
                                        .frame(minHeight: 120)
                                        .padding(8)
                                        .foregroundColor(Theme.Colors.textPrimary)
                                        .scrollContentBackground(.hidden)
                                }
                                .background(Theme.Colors.bgSecondary)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .padding(.bottom, 100)
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
                
                VStack {
                    Spacer()
                    PrimaryButton(
                        title: "상품 등록하기",
                        isLoading: viewModel.isPublishing,
                        showGlow: !viewModel.publishTitle.isEmpty && !viewModel.publishPrice.isEmpty
                    ) {
                        viewModel.publishProduct()
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("상품 등록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.Colors.bgPrimary, for: .navigationBar)
        }
    }
    
    @ViewBuilder
    private func introView() -> some View {
        ZStack {
            Theme.Colors.bgPrimary.ignoresSafeArea()
            
            VStack {
                HStack {
                    Button(action: {
                        withAnimation {
                            viewModel.currentStep = .publish
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .padding()
                    }
                    Spacer()
                }
                Spacer()
            }
            
            VStack(spacing: Theme.Spacing.lg) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 60))
                    .foregroundColor(Theme.Colors.violetAccent)
                    .shadow(color: Theme.Colors.neonGlow, radius: 20)
                
                Text("새로운 3D 모델 캡처")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text("Object Capture를 사용해 현실 세계의 물체를 스캔하고 고품질 3D 모델을 기기에서 직접 생성합니다.")
                    .font(.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
                
                PrimaryButton(title: "스캔 시작하기", icon: "arkit") {
                    showCaptureTutorial = true
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.lg)
            }
        }
    }
    
    @ViewBuilder
    private func successView() -> some View {
        ZStack {
            Theme.Colors.bgPrimary.ignoresSafeArea()
            VStack(spacing: Theme.Spacing.lg) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(Theme.Colors.success)

                Text("상품 등록 완료!")
                    .font(.largeTitle).bold()
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("잠시 후 홈으로 이동합니다...")
                    .font(.subheadline)
                    .foregroundColor(Theme.Colors.textSecondary)

                Button("바로 이동") {
                    navigateToHome()
                }
                .font(.headline)
                .foregroundColor(Theme.Colors.violetAccent)
            }
        }
        .onAppear {
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if viewModel.currentStep == .success {
                    navigateToHome()
                }
            }
        }
    }

    private func navigateToHome() {
        withAnimation {
            viewModel.reset()
        }
        NotificationCenter.default.post(name: .switchToHomeTab, object: nil)
    }
}
