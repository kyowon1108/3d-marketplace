import SwiftUI

struct AuthenticationView: View {
    @StateObject private var authManager = AuthManager.shared
    
    @State private var isLoginMode = true
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.bgPrimary.ignoresSafeArea()
                
                VStack(spacing: Theme.Spacing.xl) {
                    Spacer()
                    
                    // Logo / Brand
                    VStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "arkit")
                            .font(.system(size: 60, weight: .thin))
                            .foregroundColor(Theme.Colors.violetAccent)
                            .shadow(color: Theme.Colors.neonGlow, radius: 10)
                        
                        Text("3D Marketplace")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                    .padding(.bottom, Theme.Spacing.lg)
                    
                    // Forms
                    VStack(spacing: Theme.Spacing.md) {
                        if !isLoginMode {
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(Theme.Colors.textMuted)
                                TextField("닉네임", text: $name)
                                    .foregroundColor(Theme.Colors.textPrimary)
                            }
                            .padding()
                            .glassCardStyle()
                        }
                        
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(Theme.Colors.textMuted)
                            TextField("이메일", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .foregroundColor(Theme.Colors.textPrimary)
                        }
                        .padding()
                        .glassCardStyle()
                        
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(Theme.Colors.textMuted)
                            SecureField("비밀번호", text: $password)
                                .foregroundColor(Theme.Colors.textPrimary)
                        }
                        .padding()
                        .glassCardStyle()
                    }
                    
                    // Primary CTA
                    PrimaryButton(
                        title: isLoginMode ? "로그인" : "회원가입",
                        isLoading: isLoading,
                        showGlow: true
                    ) {
                        handleAuthAction()
                    }
                    .padding(.top, Theme.Spacing.sm)
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Theme.Colors.glassBorder)
                            .frame(height: 1)
                        Text("또는")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textMuted)
                        Rectangle()
                            .fill(Theme.Colors.glassBorder)
                            .frame(height: 1)
                    }
                    .padding(.vertical, Theme.Spacing.xs)

                    // Google Sign-In
                    Button(action: handleGoogleSignIn) {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "g.circle.fill")
                                .font(.system(size: 20))
                            Text("Google로 계속하기")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(Theme.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .glassCardStyle()
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                    }

                    // Toggle Mode
                    Button(action: {
                        withAnimation {
                            isLoginMode.toggle()
                        }
                    }) {
                        Text(isLoginMode ? "계정이 없으신가요? 회원가입" : "이미 계정이 있으신가요? 로그인")
                            .font(.subheadline)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.xl)
            }
        }
    }
    
    private func handleGoogleSignIn() {
        isLoading = true
        // Use ASWebAuthenticationSession to initiate Google OAuth flow
        guard URL(string: "\(AppEnvironment.current.apiBaseURL)/auth/oauth/google/authorize") != nil else {
            isLoading = false
            return
        }

        Task {
            do {
                // For now, use the token endpoint directly with a placeholder.
                // Real implementation: ASWebAuthenticationSession → callback → exchange code
                NotificationCenter.default.post(
                    name: .showToast,
                    object: Toast(message: "Google 로그인은 준비 중입니다.", style: .info)
                )
                isLoading = false
            }
        }
    }

    private func handleAuthAction() {
        guard !email.isEmpty else {
            NotificationCenter.default.post(
                name: .showToast,
                object: Toast(message: "이메일을 입력해주세요.", style: .error)
            )
            return
        }

        let displayName = isLoginMode ? email.components(separatedBy: "@").first ?? "User" : name.isEmpty ? "User" : name

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
                    NotificationCenter.default.post(
                        name: .showToast,
                        object: Toast(message: (error as? APIError)?.userMessage ?? "인증에 실패했습니다.", style: .error)
                    )
                }
            }
        }
    }
}
