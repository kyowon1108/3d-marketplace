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
    @StateObject private var modelDownloader = ModelDownloader()
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
    @State private var showPurchaseConfirmation = false
    @State private var isPurchasing = false
    @State private var showDragHint = false

    // Seller management
    @State private var showSellerActions = false
    @State private var showDeleteConfirmation = false
    @State private var showStatusPicker = false
    @State private var showEditView = false
    @State private var isDeleting = false

    // AR inquiry
    @State private var arCoordinator: ARPlacementView.Coordinator?
    @State private var isSendingArInquiry = false
    @State private var arShareImage: UIImage?

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
                    Spacer().frame(height: 0)
                }
            }
            .refreshable {
                fetchProductDetail()
            }
            .scrollIndicators(.hidden)

            // Fixed dark status bar background + Floating nav bar
            VStack(spacing: 0) {
                // Status bar dark background - always fixed at top
                LinearGradient(
                    colors: [.black, .black.opacity(0.85), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: safeAreaTop() + 56)
                .ignoresSafeArea(edges: .top)

                Spacer()
            }

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
                    if let product = productDetail {
                        HStack(spacing: Theme.Spacing.sm) {
                            if let url = URL(string: "3dmarket://products/\(product.id)") {
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
                            
                            if authManager.isAuthenticated, authManager.currentUser?.id == product.seller_id {
                                Button(action: { showSellerActions = true }) {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(Theme.Colors.textPrimary)
                                        .frame(width: 40, height: 40)
                                        .background(Color.black.opacity(0.4))
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, safeAreaTop() + Theme.Spacing.sm)
                Spacer()
            }

            // 4. Floating Bottom Action Bar (C2C Style)
            VStack {
                Spacer()
                bottomActionBar()
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .preferredColorScheme(.dark)
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
        .confirmationDialog(
            "상품을 구매하시겠어요?",
            isPresented: $showPurchaseConfirmation,
            titleVisibility: .visible
        ) {
            Button("구매하기") {
                purchaseProduct()
            }
            Button("취소", role: .cancel) {}
        } message: {
            if let product = productDetail {
                Text("\(product.title)을(를) 구매하면 판매완료 처리됩니다.")
            }
        }
        .confirmationDialog("상품 관리", isPresented: $showSellerActions, titleVisibility: .visible) {
            Button("수정하기") { showEditView = true }
            Button("상태 변경") { showStatusPicker = true }
            Button("삭제하기", role: .destructive) { showDeleteConfirmation = true }
            Button("취소", role: .cancel) {}
        }
        .confirmationDialog("정말 삭제하시겠어요?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("삭제", role: .destructive) { deleteProduct() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("삭제된 상품은 복구할 수 없습니다.")
        }
        .confirmationDialog("상태 변경", isPresented: $showStatusPicker, titleVisibility: .visible) {
            if productDetail?.status != "FOR_SALE" {
                Button("판매중으로 변경") { changeStatus("FOR_SALE") }
            }
            if productDetail?.status != "RESERVED" {
                Button("예약중으로 변경") { changeStatus("RESERVED") }
            }
            if productDetail?.status != "SOLD_OUT" {
                Button("판매완료로 변경") { changeStatus("SOLD_OUT") }
            }
            Button("취소", role: .cancel) {}
        }
        .sheet(isPresented: $showEditView) {
            if let product = productDetail {
                NavigationStack {
                    ProductEditView(product: product) { updated in
                        self.productDetail = updated
                    }
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
                    } else if let modelURL = modelDownloader.downloadedURL {
                        // iOS 17 Native 3D Rendering (using SceneKit for UI embed)
                        Inline3DPreview(url: modelURL) {
                            // Show drag hint if not seen before
                            if !UserDefaults.standard.bool(forKey: "hasSeenInline3DHint_v1") {
                                showDragHint = true
                                UserDefaults.standard.set(true, forKey: "hasSeenInline3DHint_v1")
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                    withAnimation { showDragHint = false }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay {
                            if showDragHint {
                                HintOverlay()
                                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                            }
                        }
                    } else {
                        CachedAsyncImage(url: URL(string: productDetail?.thumbnail_url ?? "")) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipped()
                        } placeholder: {
                            ZStack {
                                Color.black
                                ProgressView()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } failure: {
                            ZStack {
                                Color.black
                                Image(systemName: "cube.transparent")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 48, height: 48)
                                    .foregroundColor(Theme.Colors.violetAccent.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
                .overlay {
                    if modelDownloader.isDownloading {
                        VStack(spacing: Theme.Spacing.sm) {
                            Text("3D 에셋 다운로드 중...")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)

                            ProgressView(value: modelDownloader.progress)
                                .progressViewStyle(.linear)
                                .tint(Theme.Colors.violetAccent)
                                .frame(width: 180)

                            Text("\(Int(modelDownloader.progress * 100))%")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(Color.black.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    } else if modelDownloader.downloadedURL == nil && arAvailability == "READY" {
                        Button(action: {
                            downloadArModel()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "view.3d")
                                    .font(.system(size: 16, weight: .bold))
                                Text("3D로 돌려보기")
                            }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                        }
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
                if modelDownloader.downloadedURL != nil {
                    isArPresented = true
                } else if modelDownloader.isDownloading {
                    AppToast(message: "모델 다운로드 중입니다. 잠시만 기다려주세요.", style: .info)
                } else if arAvailability == "READY" {
                    downloadArModel()
                }
            }) {
                HStack(spacing: 8) {
                    if modelDownloader.isDownloading {
                        ProgressView().tint(.white).scaleEffect(0.8)
                        Text("AR 준비 중... \(Int(modelDownloader.progress * 100))%")
                    } else {
                        Image(systemName: "arkit")
                            .font(.system(size: 16, weight: .bold))
                        Text(arAvailability == "NONE" ? "AR 사용 불가" : "AR로 보기")
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
            .disabled(productDetail == nil || arAvailability == "NONE")
            .accessibilityLabel("AR로 보기")
            .accessibilityHint("증강현실 화면으로 이동하거나 모델 다운로드 상태를 확인합니다.")
            .onChange(of: modelDownloader.downloadedURL) { _, newURL in
                if newURL != nil {
                    // Haptic feedback when download completes
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                }
            }
        }
    }

    @ViewBuilder
    private func sellerProfileSection() -> some View {
        HStack(spacing: Theme.Spacing.md) {
            // Avatar
            CachedAsyncImage(url: URL(string: productDetail?.seller_avatar_url ?? "")) { image in
                image.resizable().scaledToFill().clipShape(Circle())
            } placeholder: {
                Circle().fill(Theme.Colors.bgSecondary).overlay(
                    Image(systemName: "person.fill").foregroundColor(Theme.Colors.textMuted)
                )
            }
            .frame(width: 48, height: 48)

            // Name and Location
            VStack(alignment: .leading, spacing: 4) {
                Text(productDetail?.seller_name ?? "알 수 없는 판매자")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 11))
                    Text(productDetail?.seller_location_name ?? "지역 정보 없음")
                }
                .font(.system(size: 13))
                .foregroundColor(Theme.Colors.textSecondary)
                
                // Seller Stats (P0)
                if let joinedAt = productDetail?.seller_joined_at {
                    HStack(spacing: 4) {
                        Text("가입 \(relativeTime(from: joinedAt))")
                        Text("·")
                        Text("거래 \(productDetail?.seller_trade_count ?? 0)회")
                    }
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Colors.textMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func productInfoSection() -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if let product = productDetail {
                HStack(alignment: .bottom) {
                    // Title
                    Text(product.title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                    
                    if let user = authManager.currentUser, user.id != product.seller_id {
                        Spacer()
                        Text("가격 제안은 채팅으로 문의하세요.")
                            .font(.caption2)
                            .foregroundColor(Theme.Colors.textMuted)
                    }
                }

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
                    Text("관심 \(likesCount)")
                }
                .font(.system(size: 13))
                .foregroundColor(Theme.Colors.textSecondary)
                .padding(.top, Theme.Spacing.md)

                // Dimensions card
                if let dimsText = arAsset?.formattedDimsCm {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "ruler")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.Colors.violetAccent)
                            Text("실측 치수")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.Colors.textPrimary)
                        }

                        Text(dimsText)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.Colors.textPrimary)

                        // Trust badge
                        if let dimsTrust = arAsset?.dims_trust {
                            HStack(spacing: 4) {
                                Image(systemName: dimsTrust == "high" ? "checkmark.seal.fill" : "info.circle")
                                    .font(.system(size: 11))
                                    .foregroundColor(dimsTrust == "high" ? .green : .orange)
                                Text(dimsTrust == "high" ? "LiDAR 정밀 측정 (±1cm)" : "수동 측정 (오차 가능)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Colors.bgSecondary)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.Colors.violetAccent.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.top, Theme.Spacing.sm)
                } else if let dimsTrust = arAsset?.dims_trust {
                    // Fallback: show trust badge only (no dims available)
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
                .accessibilityLabel(isLiked ? "좋아요 취소" : "좋아요")
                .accessibilityHint("이 상품의 관심 상태를 변경합니다.")

                // Divider Line replacing the thick padding divider
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 1, height: 40)
                    .padding(.horizontal, 4)

                // Price
                if let product = productDetail {
                    Text(formatPrice(product.price_cents))
                        .font(.title3.weight(.bold))
                        .foregroundColor(Theme.Colors.textPrimary)
                } else {
                    Text("가격 정보 없음")
                        .font(.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                }

                Spacer()

                // Buyer CTAs
                if let product = productDetail, authManager.isAuthenticated, authManager.currentUser?.id != product.seller_id {
                    HStack(spacing: Theme.Spacing.sm) {
                        Button(action: createChatRoom) {
                            HStack {
                                if isCreatingChat {
                                    ProgressView().tint(.white).scaleEffect(0.8)
                                }
                                Text(isCreatingChat ? "열리는 중..." : "채팅")
                            }
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white)
                            .frame(minWidth: 72)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Theme.Colors.violetAccent.opacity(0.85))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .disabled(isCreatingChat || product.status == "SOLD_OUT")
                        .accessibilityLabel("채팅 시작")
                        .accessibilityHint("판매자와 채팅방을 엽니다.")

                        Button(action: {
                            showPurchaseConfirmation = true
                        }) {
                            HStack {
                                if isPurchasing {
                                    ProgressView().tint(.white).scaleEffect(0.8)
                                }
                                Text(
                                    product.status == "SOLD_OUT"
                                    ? "판매완료"
                                    : (isPurchasing ? "구매 중..." : "구매하기")
                                )
                            }
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white)
                            .frame(minWidth: 96)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(product.status == "SOLD_OUT" ? Color.gray : Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .disabled(product.status == "SOLD_OUT" || isPurchasing)
                        .accessibilityLabel(product.status == "SOLD_OUT" ? "판매완료 상품" : "상품 구매")
                        .accessibilityHint(product.status == "SOLD_OUT" ? "이미 판매가 완료된 상품입니다." : "구매를 확인하고 결제를 진행합니다.")
                    }
                } else if authManager.isAuthenticated {
                    // Soft reminder for seller
                    Text("내가 등록한 상품입니다")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .background(Theme.Colors.bgPrimary.ignoresSafeArea(edges: .bottom))
    }

    @ViewBuilder
    private func arOverlayView() -> some View {
        if let modelURL = modelDownloader.downloadedURL {
            ZStack {
                if #available(iOS 17.0, *), !useQuickLookFallback {
                    ARPlacementView(
                        modelURL: modelURL,
                        wallSnapEnabled: $wallSnapEnabled,
                        dims: arAssetDimensions,
                        onDismiss: { isArPresented = false },
                        onError: { message in
                            NotificationCenter.default.post(
                                name: .showToast,
                                object: Toast(message: message, style: .error)
                            )
                            useQuickLookFallback = true
                        },
                        coordinatorRef: { coordinator in
                            self.arCoordinator = coordinator
                        }
                    )
                    .ignoresSafeArea()

                    // Top bar: Close + Wall/Floor toggle
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

                        // Bottom CTA: Role-based
                        arBottomCTA()
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.bottom, safeAreaBottom() + Theme.Spacing.md)
                    }
                } else {
                    let isSeller = productDetail?.seller_id == authManager.currentUser?.id
                    ARQuickLookView(
                        modelURL: modelURL,
                        isPresented: $isArPresented,
                        callToAction: isSeller ? "AR 장면 공유하기" : (authManager.isAuthenticated ? "판매자에게 문의하기" : nil),
                        productTitle: productDetail?.title,
                        sellerName: productDetail?.seller_name,
                        price: productDetail.map { formatPrice($0.price_cents) },
                        onCallToAction: {
                            if isSeller {
                                // Seller: nothing to do in QL (no screenshot API)
                                // Could show a toast suggesting custom AR view
                            } else if authManager.isAuthenticated {
                                // Buyer: close AR and open chat
                                Task {
                                    do {
                                        let room = try await createOrGetChatRoom()
                                        let request = SendMessageRequest(body: "AR에서 확인 후 문의드립니다.", image_url: nil)
                                        let encodedBody = try JSONEncoder().encode(request)
                                        let _: ChatMessageResponse = try await APIClient.shared.request(
                                            endpoint: "/chat-rooms/\(room.id)/messages",
                                            method: "POST",
                                            body: encodedBody
                                        )
                                        await MainActor.run {
                                            isArPresented = false
                                            createdChatRoom = room
                                            showChatRoom = true
                                        }
                                    } catch {
                                        await MainActor.run {
                                            NotificationCenter.default.post(
                                                name: .showToast,
                                                object: Toast(message: "문의 전송에 실패했습니다.", style: .error)
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    )
                    .edgesIgnoringSafeArea(.all)

                    // Close button for QuickLook
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
            .sheet(item: Binding(
                get: { arShareImage.map { IdentifiableImage(image: $0) } },
                set: { if $0 == nil { arShareImage = nil } }
            )) { item in
                ShareSheetView(items: [item.image])
            }
        }
    }

    @ViewBuilder
    private func arBottomCTA() -> some View {
        let isSeller = productDetail?.seller_id == authManager.currentUser?.id

        if isSeller {
            // Seller: Share AR screenshot
            Button(action: {
                captureAndShare()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .bold))
                    Text("AR 장면 공유하기")
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.Colors.violetAccent)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        } else if authManager.isAuthenticated {
            // Buyer: Inquiry to seller
            Button(action: {
                captureAndInquire()
            }) {
                HStack(spacing: 8) {
                    if isSendingArInquiry {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "bubble.left.and.text.bubble.right")
                            .font(.system(size: 16, weight: .bold))
                    }
                    Text("판매자에게 이 부분 문의하기")
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.Colors.violetAccent)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isSendingArInquiry)
        } else {
            // Not logged in
            Button(action: {
                isArPresented = false
                // After dismissing AR, the login prompt in the main view should handle it
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("로그인하고 문의하기")
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.gray.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func captureAndShare() {
        arCoordinator?.captureSnapshot { image in
            guard let image = image else { return }
            arShareImage = image
        }
    }

    private func captureAndInquire() {
        guard !isSendingArInquiry else { return }
        isSendingArInquiry = true

        arCoordinator?.captureSnapshot { capturedImage in
            Task {
                do {
                    var imageURL: String? = nil

                    // Upload screenshot if captured
                    if let image = capturedImage, let jpegData = image.jpegData(compressionQuality: 0.8) {
                        imageURL = try await uploadChatImage(data: jpegData)
                    }

                    // Create or reuse chat room
                    let room = try await createOrGetChatRoom()

                    // Send image message via REST
                    let messageBody = "AR에서 확인 후 문의드립니다."
                    let request = SendMessageRequest(body: messageBody, image_url: imageURL)
                    let encodedBody = try JSONEncoder().encode(request)
                    let _: ChatMessageResponse = try await APIClient.shared.request(
                        endpoint: "/chat-rooms/\(room.id)/messages",
                        method: "POST",
                        body: encodedBody
                    )

                    await MainActor.run {
                        isSendingArInquiry = false
                        isArPresented = false
                        createdChatRoom = room
                        showChatRoom = true
                    }
                } catch {
                    await MainActor.run {
                        isSendingArInquiry = false
                        NotificationCenter.default.post(
                            name: .showToast,
                            object: Toast(message: "문의 전송에 실패했습니다.", style: .error)
                        )
                    }
                }
            }
        }
    }

    private func uploadChatImage(data: Data) async throws -> String {
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "\(AppEnvironment.current.apiBaseURL)/chat-images/upload")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = AuthManager.shared.currentToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"ar_screenshot.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (responseData, _) = try await URLSession.shared.data(for: request)
        let json = try JSONDecoder().decode([String: String].self, from: responseData)
        guard let imageURL = json["image_url"] else {
            throw APIError.invalidResponse
        }
        return imageURL
    }

    private func createOrGetChatRoom() async throws -> ChatRoomResponse {
        if let existingRoom = createdChatRoom {
            return existingRoom
        }
        let request = CreateChatRoomRequest(subject: productDetail?.title ?? "")
        let encodedBody = try JSONEncoder().encode(request)
        let room: ChatRoomResponse = try await APIClient.shared.request(
            endpoint: "/products/\(productId.uuidString)/chat-rooms",
            method: "POST",
            body: encodedBody
        )
        return room
    }

    // MARK: - Computed

    /// Converts ArAssetResponse dims (cm) to ModelDimensions (meters) for AR overlay.
    private var arAssetDimensions: ModelDimensions? {
        guard let w = arAsset?.dims_width, let h = arAsset?.dims_height, let d = arAsset?.dims_depth,
              w > 0, h > 0, d > 0 else { return nil }
        return ModelDimensions(width: w / 100.0, height: h / 100.0, depth: d / 100.0)
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
                    endpoint: "/products/\(productId.uuidString)"
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

        guard let downloadURL = URL(string: usdzFile.url) else {
            NotificationCenter.default.post(
                name: .showToast,
                object: Toast(message: "잘못된 다운로드 URL입니다.", style: .error)
            )
            return
        }

        let assetId = arAsset.asset_id ?? productId.uuidString
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let destURL = cachesDir.appendingPathComponent("\(assetId).usdz")

        modelDownloader.download(from: downloadURL, destination: destURL)
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

    private func purchaseProduct() {
        guard authManager.isAuthenticated else {
            AppToast(message: "로그인이 필요합니다.", style: .error)
            return
        }
        guard let product = productDetail else { return }
        guard authManager.currentUser?.id != product.seller_id else {
            AppToast(message: "내 상품은 구매할 수 없습니다.", style: .info)
            return
        }
        guard product.status != "SOLD_OUT" else {
            AppToast(message: "이미 판매가 완료된 상품입니다.", style: .info)
            return
        }

        isPurchasing = true

        Task {
            do {
                let _: PurchaseResponse = try await APIClient.shared.request(
                    endpoint: "/products/\(productId.uuidString)/purchase",
                    method: "POST"
                )
                await MainActor.run {
                    isPurchasing = false
                    markProductAsSoldOut()
                    NotificationCenter.default.post(
                        name: .productPurchased,
                        object: ProductPurchaseEvent(productId: productId)
                    )
                    AppToast(message: "구매가 완료되었습니다.", style: .success)
                }
            } catch {
                await MainActor.run {
                    isPurchasing = false

                    if case APIError.unauthenticated = error {
                        authManager.logout()
                        AppToast(message: "세션이 만료되었습니다. 다시 로그인해주세요.", style: .error)
                        return
                    }

                    if case APIError.httpError(let code) = error {
                        switch code {
                        case 403:
                            AppToast(message: "내 상품은 구매할 수 없습니다.", style: .error)
                        case 400, 409:
                            markProductAsSoldOut()
                            NotificationCenter.default.post(
                                name: .productPurchased,
                                object: ProductPurchaseEvent(productId: productId)
                            )
                            AppToast(message: "이미 판매가 완료된 상품입니다.", style: .info)
                        default:
                            AppToast(message: (error as? APIError)?.userMessage ?? "구매 처리에 실패했습니다.", style: .error)
                        }
                        return
                    }

                    AppToast(message: (error as? APIError)?.userMessage ?? "구매 처리에 실패했습니다.", style: .error)
                }
            }
        }
    }

    private func deleteProduct() {
        isDeleting = true
        Task {
            do {
                let _: EmptyResponse = try await APIClient.shared.request(
                    endpoint: "/products/\(productId.uuidString)",
                    method: "DELETE"
                )
                await MainActor.run {
                    isDeleting = false
                    AppToast(message: "상품이 삭제되었습니다.", style: .success)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    AppToast(message: (error as? APIError)?.userMessage ?? "삭제에 실패했습니다.", style: .error)
                }
            }
        }
    }

    private func changeStatus(_ newStatus: String) {
        Task {
            do {
                let request = StatusChangeRequest(status: newStatus)
                let body = try JSONEncoder().encode(request)
                let response: ProductResponse = try await APIClient.shared.request(
                    endpoint: "/products/\(productId.uuidString)/status",
                    method: "PATCH",
                    body: body
                )
                await MainActor.run {
                    self.productDetail = response
                    let label = newStatus == "FOR_SALE" ? "판매중" : (newStatus == "RESERVED" ? "예약중" : "판매완료")
                    AppToast(message: "\(label)(으)로 변경되었습니다.", style: .success)
                }
            } catch {
                await MainActor.run {
                    AppToast(message: (error as? APIError)?.userMessage ?? "상태 변경에 실패했습니다.", style: .error)
                }
            }
        }
    }

    private func markProductAsSoldOut() {
        guard let product = productDetail else { return }
        productDetail = ProductResponse(
            id: product.id,
            asset_id: product.asset_id,
            title: product.title,
            description: product.description,
            price_cents: product.price_cents,
            seller_id: product.seller_id,
            seller_name: product.seller_name,
            seller_avatar_url: product.seller_avatar_url,
            seller_location_name: product.seller_location_name,
            seller_joined_at: product.seller_joined_at,
            seller_trade_count: product.seller_trade_count,
            thumbnail_url: product.thumbnail_url,
            status: "SOLD_OUT",
            chat_count: product.chat_count,
            likes_count: likesCount,
            views_count: product.views_count,
            is_liked: isLiked,
            published_at: product.published_at,
            created_at: product.created_at
        )
    }
}

// MARK: - Dedicated Inline 3D Preview (SceneKit)
private struct Inline3DPreview: View {
    let url: URL
    var onSceneLoaded: (() -> Void)? = nil
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
                    self.onSceneLoaded?()
                }
            } catch {
                #if DEBUG
                print("Failed to load scene: \(error)")
                #endif
            }
        }
    }
}

// MARK: - 3D Drag Hint Overlay
private struct HintOverlay: View {
    @State private var swayOffset: CGFloat = -12

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "hand.draw.fill")
                .font(.system(size: 32))
                .offset(x: swayOffset)
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true)
                    ) {
                        swayOffset = 12
                    }
                }
            Text("드래그해서 돌려보세요")
                .font(.subheadline.weight(.semibold))
        }
        .foregroundColor(.white)
        .padding(16)
        .background(Color.black.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
