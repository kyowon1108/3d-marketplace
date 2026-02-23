import SwiftUI
import UIKit // for haptic feedback
import SceneKit

struct ProductDetailView: View {
    let productId: UUID
    @Environment(\.dismiss) var dismiss
    @StateObject private var authManager = AuthManager.shared

    // Product state
    @State private var isLoading = true
    @State private var productDetail: ProductResponse?
    @State private var isArPresented = false
    @State private var showArTutorial = false

    // R1: AR asset download
    @State private var arAsset: ArAssetResponse?
    @State private var arAvailability: String = "NONE"
    @State private var downloadedModelURL: URL?
    @State private var isDownloadingModel = false
    @State private var wallSnapEnabled = false
    @State private var useQuickLookFallback = true

    // R2: Like toggle
    @State private var isLiked: Bool = false
    @State private var likesCount: Int = 0
    @State private var isTogglingLike = false

    // R3: Chat room creation
    @State private var isCreatingChat = false
    @State private var showChatRoom = false
    @State private var createdChatRoom: ChatRoomResponse?

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.Colors.bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // 1. Hero Image / 3D Viewer Area
                    heroSection()

                    // 2. Seller Profile Row
                    sellerProfileSection()
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.md)

                    Divider().background(Color.white.opacity(0.1))

                    // 3. Product Info Section
                    productInfoSection()
                        .padding(Theme.Spacing.md)

                    // Bottom padding to avoid action bar overlap
                    Spacer().frame(height: 100)
                }
            }
            .ignoresSafeArea(edges: .top)

            // Top Navigation Bar (Floating Back & Share)
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .frame(width: 40, height: 40)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    }
                    Spacer()
                    if let product = productDetail, let url = URL(string: "3dmarket://products/\(product.id)") {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Theme.Colors.textPrimary)
                                .frame(width: 40, height: 40)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                // Use safe area inset for top
                .padding(.top, safeAreaTop() + Theme.Spacing.sm)
                Spacer()
            }

            // 4. Floating Bottom Action Bar (C2C Style)
            bottomActionBar()
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $isArPresented) {
            arOverlayView()
        }
        .sheet(isPresented: $showChatRoom) {
            if let room = createdChatRoom {
                NavigationStack {
                    ChatRoomView(room: room)
                }
            }
        }
        .tutorialModal(
            isPresented: $showArTutorial,
            title: "AR 공간 배치",
            description: "원하는 바닥을 비춰주세요. 탭하면 3D 물체가 나타나고, 두 손가락으로 크기를 조절할 수 있습니다.",
            iconAnimation: AnyView(AnimatedPanPinchIcon()),
            userDefaultsKey: "hasSeenArTutorial_v1"
        )
        .onAppear {
            fetchProductDetail()
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private func heroSection() -> some View {
        ZStack(alignment: .bottomTrailing) {
            TabView {
                ZStack {
                    Theme.Colors.bgSecondary
                    if isLoading {
                        ProgressView().tint(Theme.Colors.violetAccent).scaleEffect(1.5)
                    } else if let modelURL = downloadedModelURL {
                        // iOS 17 Native 3D Rendering (using SceneKit for UI embed)
                        Inline3DPreview(url: modelURL)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if arAvailability == "READY" && !isDownloadingModel {
                        VStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "cube.transparent")
                                .font(.system(size: 80))
                                .foregroundColor(Theme.Colors.violetAccent.opacity(0.8))
                                .shadow(color: Theme.Colors.violetAccent.opacity(0.3), radius: 10)
                            
                            Text("3D 모델 렌더링 준비됨")
                                .font(.headline)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    } else if isDownloadingModel {
                        VStack(spacing: Theme.Spacing.md) {
                            ProgressView().tint(Theme.Colors.violetAccent).scaleEffect(1.5)
                            Text("3D 에셋 불러오는 중...")
                                .font(.subheadline)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    } else {
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 80))
                            .foregroundColor(Theme.Colors.violetAccent.opacity(0.2))
                    }
                }
            }
            .tabViewStyle(PageTabViewStyle())
            .frame(height: UIScreen.main.bounds.width * 1.2) // ~400+ pt
            .background(Color.black)

            // AR Call to Action inside the image
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                if downloadedModelURL != nil {
                    isArPresented = true
                } else if arAvailability == "READY" {
                    downloadArModel()
                }
            }) {
                HStack(spacing: 8) {
                    if isDownloadingModel {
                        ProgressView().tint(.white).scaleEffect(0.8)
                        Text("다운로드 중...")
                    } else {
                        Image(systemName: "arkit")
                            .font(.system(size: 16, weight: .bold))
                        Text(downloadedModelURL != nil ? "AR로 보기" : (arAvailability == "READY" ? "3D 모델 불러오기" : "AR 사용 불가"))
                    }
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.6))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Theme.Colors.violetAccent.opacity(0.5), lineWidth: 1))
                .shadow(color: Theme.Colors.violetAccent.opacity(0.3), radius: 10, x: 0, y: 0)
            }
            .padding(Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.md)
            .disabled(productDetail == nil || arAvailability == "NONE" || isDownloadingModel)
        }
    }

    @ViewBuilder
    private func sellerProfileSection() -> some View {
        HStack(spacing: Theme.Spacing.md) {
            // Avatar
            AsyncImage(url: URL(string: productDetail?.seller_avatar_url ?? "")) { phase in
                switch phase {
                case .empty:
                    Circle().fill(Theme.Colors.bgSecondary)
                case .success(let img):
                    img.resizable().scaledToFill().clipShape(Circle())
                case .failure:
                    Circle().fill(Theme.Colors.bgSecondary).overlay(
                        Image(systemName: "person.fill").foregroundColor(Theme.Colors.textMuted)
                    )
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 48, height: 48)

            // Name and Location
            VStack(alignment: .leading, spacing: 4) {
                Text(productDetail?.seller_name ?? "알 수 없는 판매자")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(productDetail?.seller_location_name ?? "지역 정보 없음")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Colors.textSecondary)
            }

        }
    }

    @ViewBuilder
    private func productInfoSection() -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if let product = productDetail {
                // Title
                Text(product.title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)

                // Category and Time
                Text(relativeTime(from: product.created_at))
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Colors.textSecondary)

                // Description
                if let description = product.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 16))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineSpacing(6)
                        .padding(.top, Theme.Spacing.sm)
                }
                
                // Status / Chat Count metrics
                HStack(spacing: 8) {
                    if product.status == "RESERVED" {
                        Text("예약중")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .cornerRadius(4)
                    } else if product.status == "SOLD_OUT" {
                        Text("판매완료")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray)
                            .cornerRadius(4)
                    }

                    Text("조회 \(product.views_count ?? 0)")
                    Text("·")
                    Text("채팅 \(product.chat_count ?? 0)")
                    Text("·")
                    Text("관심 \(product.likes_count ?? 0)")
                }
                .font(.system(size: 13))
                .foregroundColor(Theme.Colors.textSecondary)
                .padding(.top, Theme.Spacing.md)

                // Trust metrics
                if let dimsTrust = arAsset?.dims_trust {
                    HStack(spacing: 6) {
                        Image(systemName: dimsTrust == "high" ? "checkmark.seal.fill" : "info.circle")
                            .font(.system(size: 12))
                            .foregroundColor(dimsTrust == "high" ? .green : .orange)
                        Text(dimsTrust == "high" ? "LiDAR 정밀 스캔 인증됨" : "수동 측정 (오차 가능)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Theme.Colors.bgSecondary)
                    .cornerRadius(8)
                    .padding(.top, Theme.Spacing.sm)
                }
            } else if !isLoading {
                Text("상품 정보를 로드할 수 없습니다.")
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func bottomActionBar() -> some View {
        VStack(spacing: 0) {
            Divider().background(Color.white.opacity(0.1))
            HStack(spacing: Theme.Spacing.md) {
                // Like Button
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    toggleLike()
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 24, weight: .regular))
                            .foregroundColor(isLiked ? .red : Theme.Colors.textSecondary)
                    }
                    .frame(width: 44)
                }
                .disabled(isTogglingLike || !authManager.isAuthenticated)

                // Divider Line replacing the thick padding divider
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 1, height: 40)
                    .padding(.horizontal, 4)

                // Price
                if let product = productDetail {
                    Text(formatPrice(product.price_cents))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Theme.Colors.textPrimary)
                } else {
                    Text("가격 정보 없음")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.Colors.textSecondary)
                }

                Spacer()

                // Chat CTA
                if let product = productDetail, authManager.isAuthenticated, authManager.currentUser?.id != product.seller_id {
                    Button(action: createChatRoom) {
                        HStack {
                            if isCreatingChat {
                                ProgressView().tint(.white).scaleEffect(0.8)
                            }
                            Text(isCreatingChat ? "열리는 중..." : "채팅하기")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(minWidth: 100)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.violetAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .disabled(isCreatingChat || product.status == "SOLD_OUT")
                } else if authManager.isAuthenticated {
                    Text("내 상품")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, safeAreaBottom() + Theme.Spacing.sm)
        }
        .background(Theme.Colors.bgPrimary.opacity(0.95))
    }

    @ViewBuilder
    private func arOverlayView() -> some View {
        if let modelURL = downloadedModelURL {
            ZStack {
                if #available(iOS 17.0, *), !useQuickLookFallback {
                    ARPlacementView(
                        modelURL: modelURL,
                        wallSnapEnabled: $wallSnapEnabled,
                        onDismiss: { isArPresented = false },
                        onError: { message in
                            NotificationCenter.default.post(
                                name: .showToast,
                                object: Toast(message: message, style: .error)
                            )
                            useQuickLookFallback = true
                        }
                    )
                    .ignoresSafeArea()

                    // Wall snap toggle
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: { wallSnapEnabled.toggle() }) {
                                Label(
                                    wallSnapEnabled ? "벽면" : "바닥",
                                    systemImage: wallSnapEnabled ? "square.split.bottomrightquarter" : "square.split.bottomrightquarter.fill"
                                )
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                            }
                            .padding()
                        }
                        Spacer()
                    }
                } else {
                    ARQuickLookView(modelURL: modelURL, isPresented: $isArPresented)
                        .edgesIgnoringSafeArea(.all)
                }

                // Close button
                VStack {
                    HStack {
                        Button(action: { isArPresented = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .shadow(radius: 5)
                        }
                        .padding()
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Helpers

    private func safeAreaTop() -> CGFloat {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return windowScene.windows.first?.safeAreaInsets.top ?? 44
        }
        return 44
    }

    private func safeAreaBottom() -> CGFloat {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return windowScene.windows.first?.safeAreaInsets.bottom ?? 34
        }
        return 34
    }

    // MARK: - Networking

    private func fetchProductDetail() {
        Task {
            do {
                let response: ProductResponse = try await APIClient.shared.request(
                    endpoint: "/products/\(productId.uuidString)",
                    needsAuth: false
                )
                await MainActor.run {
                    self.productDetail = response
                    self.isLiked = response.is_liked ?? false
                    self.likesCount = response.likes_count ?? 0
                    self.isLoading = false
                }
                await fetchArAsset()
            } catch {
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .showToast,
                        object: Toast(message: (error as? APIError)?.userMessage ?? "정보를 불러오지 못했습니다.", style: .error)
                    )
                    self.isLoading = false
                }
            }
        }
    }

    private func fetchArAsset() async {
        do {
            let response: ArAssetResponse = try await APIClient.shared.request(
                endpoint: "/products/\(productId.uuidString)/ar-asset"
            )
            await MainActor.run {
                self.arAsset = response
                self.arAvailability = response.availability
            }
        } catch {
            await MainActor.run {
                self.arAvailability = "NONE"
            }
        }
    }

    private func downloadArModel() {
        guard let arAsset = arAsset else { return }
        guard let usdzFile = arAsset.files.first(where: { $0.role == "MODEL_USDZ" }) else {
            NotificationCenter.default.post(
                name: .showToast,
                object: Toast(message: "USDZ 모델 파일을 찾을 수 없습니다.", style: .error)
            )
            return
        }

        isDownloadingModel = true
        let assetId = arAsset.asset_id ?? productId.uuidString
        let destURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(assetId).usdz")

        if FileManager.default.fileExists(atPath: destURL.path) {
            downloadedModelURL = destURL
            isDownloadingModel = false
            return
        }

        Task {
            do {
                guard let downloadURL = URL(string: usdzFile.url) else {
                    throw APIError.invalidURL
                }
                let (tempURL, _) = try await URLSession.shared.download(from: downloadURL)
                try? FileManager.default.removeItem(at: destURL)
                try FileManager.default.moveItem(at: tempURL, to: destURL)
                await MainActor.run {
                    self.downloadedModelURL = destURL
                    self.isDownloadingModel = false
                }
            } catch {
                await MainActor.run {
                    self.isDownloadingModel = false
                    NotificationCenter.default.post(
                        name: .showToast,
                        object: Toast(message: "모델 다운로드에 실패했습니다.", style: .error)
                    )
                }
            }
        }
    }

    private func toggleLike() {
        guard authManager.isAuthenticated else { return }
        let previousLiked = isLiked
        let previousCount = likesCount
        isLiked.toggle()
        likesCount += isLiked ? 1 : -1
        isTogglingLike = true

        Task {
            do {
                let response: LikeToggleResponse = try await APIClient.shared.request(
                    endpoint: "/products/\(productId.uuidString)/like",
                    method: "POST"
                )
                await MainActor.run {
                    self.isLiked = response.liked
                    self.likesCount = response.likes_count
                    self.isTogglingLike = false
                }
            } catch {
                await MainActor.run {
                    self.isLiked = previousLiked
                    self.likesCount = previousCount
                    self.isTogglingLike = false
                    NotificationCenter.default.post(
                        name: .showToast,
                        object: Toast(message: "좋아요 처리에 실패했습니다.", style: .error)
                    )
                }
            }
        }
    }

    private func createChatRoom() {
        guard let product = productDetail else { return }
        isCreatingChat = true

        Task {
            do {
                let request = CreateChatRoomRequest(subject: "\(product.title)에 대한 문의")
                let encodedBody = try JSONEncoder().encode(request)
                let room: ChatRoomResponse = try await APIClient.shared.request(
                    endpoint: "/products/\(productId.uuidString)/chat-rooms",
                    method: "POST",
                    body: encodedBody
                )
                await MainActor.run {
                    self.createdChatRoom = room
                    self.isCreatingChat = false
                    self.showChatRoom = true
                }
            } catch {
                await MainActor.run {
                    self.isCreatingChat = false
                    NotificationCenter.default.post(
                        name: .showToast,
                        object: Toast(message: (error as? APIError)?.userMessage ?? "채팅방 생성에 실패했습니다.", style: .error)
                    )
                }
            }
        }
    }
}

// MARK: - Dedicated Inline 3D Preview (SceneKit)
private struct Inline3DPreview: View {
    let url: URL
    @State private var scene: SCNScene?
    
    var body: some View {
        ZStack {
            if let scene = scene {
                SceneView(
                    scene: scene,
                    options: [.allowsCameraControl, .autoenablesDefaultLighting]
                )
            } else {
                ProgressView()
                    .tint(Theme.Colors.violetAccent)
                    .onAppear {
                        loadScene()
                    }
            }
        }
    }
    
    private func loadScene() {
        Task.detached {
            do {
                let loadedScene = try SCNScene(url: url, options: nil)
                await MainActor.run {
                    self.scene = loadedScene
                }
            } catch {
                #if DEBUG
                print("Failed to load scene: \(error)")
                #endif
            }
        }
    }
}
