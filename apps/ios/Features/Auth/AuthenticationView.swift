import SwiftUI
import GoogleSignIn

struct AuthenticationView: View {
    @StateObject private var authManager = AuthManager.shared

    @State private var isLoading = false
    @State private var showDevLogin = false

    // Dev login fields
    @State private var email = ""
    @State private var name = ""

    // Auto-scrolling carousel state
    @State private var scrollPosition: Int? = 1500
    private let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(red: 0.04, green: 0.04, blue: 0.05).ignoresSafeArea() // Very dark #0A0A0C
                
                // Subtle purple background glow
                RadialGradient(
                    colors: [Theme.Colors.violetAccent.opacity(0.15), .clear],
                    center: .top,
                    startRadius: 50,
                    endRadius: 400
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer().frame(height: 20)
                    
                    // Logo / Brand
                    VStack(spacing: 12) {
                        ZStack {
                            Image(systemName: "hexagon")
                                .font(.system(size: 64, weight: .ultraLight))
                                .foregroundColor(Theme.Colors.violetAccent.opacity(0.6))
                            
                            Image(systemName: "arkit")
                                .font(.system(size: 32, weight: .light))
                                .foregroundColor(Theme.Colors.violetAccent)
                        }
                        .shadow(color: Theme.Colors.violetAccent.opacity(0.5), radius: 10)

                        Text("3D Marketplace")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Theme.Colors.textPrimary)

                        Text("AR로 만나는 새로운 쇼핑")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .padding(.bottom, 30)

                    // Hero Onboarding Carousel (Infinite Peeking Auto-scrolling)
                    GeometryReader { proxy in
                        let cardWidth: CGFloat = 240
                        let horizontalPadding = (proxy.size.width - cardWidth) / 2
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 16) {
                                ForEach(0..<3000, id: \.self) { index in
                                    let realIndex = index % 3
                                    Group {
                                        if realIndex == 0 {
                                            arPromotionCard()
                                        } else if realIndex == 1 {
                                            scanPromotionCard()
                                        } else {
                                            tradePromotionCard()
                                        }
                                    }
                                    .scaleEffect(scrollPosition == index ? 1.0 : 0.9)
                                    .opacity(scrollPosition == index ? 1.0 : 0.5)
                                    .animation(.easeOut(duration: 0.4), value: scrollPosition)
                                    .id(index)
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.viewAligned)
                        .safeAreaPadding(.horizontal, horizontalPadding) // Perfectly aligns the cards to the center
                        .scrollPosition(id: $scrollPosition)
                        .onReceive(timer) { _ in
                            if let current = scrollPosition {
                                withAnimation(.easeOut(duration: 0.8)) {
                                    scrollPosition = current + 1
                                }
                            }
                        }
                    }
                    .frame(height: 380)
                    .padding(.bottom, 20)

                    Spacer()

                    // Google Login Button (Matching mockup: Capsule, dark bg, purple stroke)
                    Button(action: handleGoogleSignIn) {
                        HStack(spacing: 12) {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.9)
                            } else {
                                GoogleLogoView(size: 18)
                            }
                            Text("구글로 계속하기")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(red: 0.1, green: 0.1, blue: 0.12))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Theme.Colors.violetAccent.opacity(0.6), lineWidth: 1)
                        )
                    }
                    .disabled(isLoading)
                    .padding(.horizontal, 40)
                    
                    // Dev Login is at the very bottom
                    Spacer().frame(height: 40)

                    // ── Dev Login (DEBUG only) ──
                    #if DEBUG
                    VStack(spacing: Theme.Spacing.sm) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showDevLogin.toggle()
                            }
                        }) {
                            HStack {
                                Rectangle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 1)
                                Image(systemName: "hammer.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.Colors.textMuted)
                                Text("개발자 로그인")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Theme.Colors.textMuted)
                                Rectangle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 1)
                            }
                        }

                        if showDevLogin {
                            VStack(spacing: Theme.Spacing.sm) {
                                HStack(spacing: 8) {
                                    TextField("이메일", text: $email)
                                        .textInputAutocapitalization(.never)
                                        .keyboardType(.emailAddress)
                                        .font(.system(size: 14))
                                        .foregroundColor(Theme.Colors.textPrimary)
                                        .padding(10)
                                        .background(Theme.Colors.bgSecondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))

                                    TextField("닉네임", text: $name)
                                        .font(.system(size: 14))
                                        .foregroundColor(Theme.Colors.textPrimary)
                                        .padding(10)
                                        .background(Theme.Colors.bgSecondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }

                                Button(action: handleDevLogin) {
                                    Text("Dev 로그인")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Theme.Colors.violetAccent.opacity(0.7))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .disabled(email.isEmpty)
                            }
                            .padding(.horizontal, Theme.Spacing.sm)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.bottom, safeAreaBottom() + Theme.Spacing.md)
                    #endif
                }
            }
        }
    }
    
    // MARK: - Onboarding Cards
    
    @ViewBuilder
    private func arPromotionCard() -> some View {
        ZStack(alignment: .bottomLeading) {
            // Background Image (Premium dark minimalist interior)
            AsyncImage(url: URL(string: "https://images.unsplash.com/photo-1616486338812-3dadae4b4ace?q=80&w=600&auto=format&fit=crop")) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 240, height: 350)
            } placeholder: {
                Color(red: 0.1, green: 0.1, blue: 0.12)
                    .frame(width: 240, height: 350)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            
            // Subtle inner glow + border
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
            
            // Purple subtle outline on the card to simulate AR selection
            RoundedRectangle(cornerRadius: 24)
                .stroke(Theme.Colors.violetAccent.opacity(0.6), lineWidth: 1.5)
                .shadow(color: Theme.Colors.violetAccent.opacity(0.8), radius: 12)
                .clipShape(RoundedRectangle(cornerRadius: 24))
            
            // Bottom Gradient for text readability
            LinearGradient(
                colors: [.black, .black.opacity(0.7), .clear],
                startPoint: .bottom,
                endPoint: .center
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            
            // Text Content
            VStack(alignment: .leading, spacing: 8) {
                Text("AR Ready")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.violetAccent)
                    .clipShape(Capsule())
                
                Text("실물 크기로\n미리 배치해보기")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)
                    .lineSpacing(4)
            }
            .padding(24)
        }
        .frame(width: 240, height: 350)
    }
    
    @ViewBuilder
    private func scanPromotionCard() -> some View {
        ZStack(alignment: .bottomLeading) {
            // Background Image (Dark abstract 3D purple shape)
            AsyncImage(url: URL(string: "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=600&auto=format&fit=crop")) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 240, height: 350)
            } placeholder: {
                Color(red: 0.1, green: 0.1, blue: 0.12)
                    .frame(width: 240, height: 350)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            
            // Gradient Overlay
            LinearGradient(
                colors: [.black, .black.opacity(0.5), .clear],
                startPoint: .bottom,
                endPoint: .top
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            
            VStack(spacing: 20) {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Theme.Colors.violetAccent.opacity(0.2))
                        .frame(width: 90, height: 90)
                        .blur(radius: 20)
                    
                    Image(systemName: "viewfinder")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.white)
                        .shadow(color: Theme.Colors.violetAccent, radius: 10)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            
            // Text Content
            VStack(alignment: .leading, spacing: 8) {
                Text("쉬운 3D 스캔\n& 업로드")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)
                    .lineSpacing(4)
            }
            .padding(24)
        }
        .frame(width: 240, height: 350)
    }
    
    @ViewBuilder
    private func tradePromotionCard() -> some View {
        ZStack(alignment: .bottomLeading) {
            // Background Image (Dark abstract geometric layers)
            AsyncImage(url: URL(string: "https://images.unsplash.com/photo-1633526543814-9710c77c86aa?q=80&w=600&auto=format&fit=crop")) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 240, height: 350)
            } placeholder: {
                Color(red: 0.1, green: 0.1, blue: 0.12)
                    .frame(width: 240, height: 350)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            
            // Gradient Overlay
            LinearGradient(
                colors: [.black, .black.opacity(0.5), .clear],
                startPoint: .bottom,
                endPoint: .top
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            
            VStack(spacing: 20) {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 90, height: 90)
                        .blur(radius: 20)
                    
                    Image(systemName: "lock.shield")
                        .font(.system(size: 44, weight: .light))
                        .foregroundColor(Color.blue)
                        .shadow(color: Color.blue.opacity(0.8), radius: 12)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            
            // Text Content
            VStack(alignment: .leading, spacing: 8) {
                Text("빠르고 안전한\n1:1 중고거래")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)
                    .lineSpacing(4)
            }
            .padding(24)
        }
        .frame(width: 240, height: 350)
    }

    // MARK: - Google Sign-In

    private func handleGoogleSignIn() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            AppToast(message: "로그인 화면을 찾을 수 없습니다.", style: .error)
            return
        }

        isLoading = true

        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { result, error in
            // Extract Sendable values before entering Task to avoid capturing non-Sendable SDK types.
            let cancelled = (error as NSError?)?.code == GIDSignInError.canceled.rawValue
            let errorDescription = error?.localizedDescription
            let idToken = result?.user.idToken?.tokenString

            Task { @MainActor in
                // User cancelled
                if cancelled {
                    isLoading = false
                    return
                }

                // Other errors
                if let errorDescription {
                    isLoading = false
                    AppToast(message: "Google 로그인 실패: \(errorDescription)", style: .error)
                    return
                }

                // Get id_token
                guard let idToken else {
                    isLoading = false
                    AppToast(message: "Google 토큰을 가져오지 못했습니다.", style: .error)
                    return
                }

                // Exchange with backend
                await exchangeGoogleToken(idToken)
            }
        }
    }

    private func exchangeGoogleToken(_ idToken: String) async {
        do {
            let body = GoogleTokenRequest(id_token: idToken)
            let encoded = try JSONEncoder().encode(body)
            let response: AuthTokenResponse = try await APIClient.shared.request(
                endpoint: "/auth/oauth/google/token",
                method: "POST",
                body: encoded,
                needsAuth: false
            )

            isLoading = false
            authManager.saveTokens(
                accessToken: response.access_token,
                refreshToken: response.refresh_token
            )
            AppToast(message: "환영합니다, \(response.user.name)!", style: .success)
        } catch {
            isLoading = false
            let message = (error as? APIError)?.userMessage ?? "로그인에 실패했습니다."
            AppToast(message: message, style: .error)
        }
    }

    // MARK: - Dev Login

    private func handleDevLogin() {
        let displayName = name.isEmpty ? email.components(separatedBy: "@").first ?? "User" : name
        isLoading = true

        Task {
            do {
                let code = "\(email):\(displayName)"
                let encoded = code.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? code
                let response: AuthTokenResponse = try await APIClient.shared.request(
                    endpoint: "/auth/oauth/dev/callback?code=\(encoded)",
                    needsAuth: false
                )
                await MainActor.run {
                    isLoading = false
                    authManager.saveTokens(
                        accessToken: response.access_token,
                        refreshToken: response.refresh_token
                    )
                    AppToast(message: "환영합니다, \(response.user.name)!", style: .success)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    AppToast(message: (error as? APIError)?.userMessage ?? "인증에 실패했습니다.", style: .error)
                }
            }
        }
    }

    private func safeAreaBottom() -> CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 0
    }
}
