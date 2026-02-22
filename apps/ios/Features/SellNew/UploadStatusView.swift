import SwiftUI

struct UploadStatusView: View {
    let assetId: String
    @Environment(\.dismiss) var dismiss

    @State private var asset: ModelAssetResponse?
    @State private var isLoading = true
    @State private var isPolling = true
    @State private var pollTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Theme.Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: Theme.Spacing.xl) {
                Spacer()

                // Status circle
                ZStack {
                    Circle()
                        .stroke(Theme.Colors.bgSecondary, lineWidth: 8)
                        .frame(width: 120, height: 120)

                    Circle()
                        .trim(from: 0, to: progressValue)
                        .stroke(statusColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: progressValue)

                    Image(systemName: statusIcon)
                        .font(.system(size: 40))
                        .foregroundColor(statusColor)
                }

                // Status text
                VStack(spacing: Theme.Spacing.sm) {
                    Text(statusTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.Colors.textPrimary)

                    Text(statusDescription)
                        .font(.subheadline)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Action button for terminal states
                if let status = asset?.status, isTerminalStatus(status) {
                    PrimaryButton(
                        title: status == "FAILED" ? "다시 시도" : "확인",
                        showGlow: status != "FAILED"
                    ) {
                        dismiss()
                    }
                    .padding(.bottom, Theme.Spacing.xl)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
        }
        .navigationTitle("업로드 상태")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            startPolling()
        }
        .onDisappear {
            stopPolling()
        }
    }

    // MARK: - Computed

    private var progressValue: CGFloat {
        guard let status = asset?.status else { return 0 }
        switch status {
        case "INITIATED": return 0.1
        case "UPLOADING": return 0.4
        case "READY": return 1.0
        case "PUBLISHED": return 1.0
        case "FAILED": return 1.0
        default: return 0
        }
    }

    private var statusColor: Color {
        guard let status = asset?.status else { return Theme.Colors.textMuted }
        switch status {
        case "READY", "PUBLISHED": return .green
        case "FAILED": return .red
        default: return Theme.Colors.violetAccent
        }
    }

    private var statusIcon: String {
        guard let status = asset?.status else { return "arrow.clockwise" }
        switch status {
        case "INITIATED": return "arrow.up.circle"
        case "UPLOADING": return "arrow.up.circle.fill"
        case "READY": return "checkmark.circle.fill"
        case "PUBLISHED": return "checkmark.seal.fill"
        case "FAILED": return "xmark.circle.fill"
        default: return "questionmark.circle"
        }
    }

    private var statusTitle: String {
        guard let status = asset?.status else { return "로딩 중..." }
        switch status {
        case "INITIATED": return "업로드 준비 중"
        case "UPLOADING": return "업로드 중..."
        case "READY": return "업로드 완료"
        case "PUBLISHED": return "게시 완료"
        case "FAILED": return "업로드 실패"
        default: return status
        }
    }

    private var statusDescription: String {
        guard let status = asset?.status else { return "에셋 상태를 확인하고 있습니다." }
        switch status {
        case "INITIATED": return "서버에서 업로드 준비를 하고 있습니다."
        case "UPLOADING": return "모델 파일을 업로드하고 있습니다."
        case "READY": return "모델이 준비되었습니다. 게시할 수 있습니다."
        case "PUBLISHED": return "상품이 마켓플레이스에 게시되었습니다."
        case "FAILED": return "업로드 중 오류가 발생했습니다. 다시 시도해주세요."
        default: return ""
        }
    }

    private func isTerminalStatus(_ status: String) -> Bool {
        ["READY", "PUBLISHED", "FAILED"].contains(status)
    }

    // MARK: - Polling

    private func startPolling() {
        pollTask = Task {
            while !Task.isCancelled && isPolling {
                await fetchAssetStatus()

                if let status = asset?.status, isTerminalStatus(status) {
                    isPolling = false
                    return
                }

                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            }
        }
    }

    private func stopPolling() {
        isPolling = false
        pollTask?.cancel()
        pollTask = nil
    }

    private func fetchAssetStatus() async {
        do {
            let response: ModelAssetResponse = try await APIClient.shared.request(
                endpoint: "/model-assets/\(assetId)"
            )
            await MainActor.run {
                self.asset = response
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}
