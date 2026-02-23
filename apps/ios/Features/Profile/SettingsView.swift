import SwiftUI

struct SettingsView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var showLogoutConfirmation = false

    var body: some View {
        List {
            // Account Management
            Section(header: Text("계정 관리").foregroundColor(Theme.Colors.textSecondary)) {
                NavigationLink {
                    ProfileEditView()
                } label: {
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "person.crop.circle")
                            .foregroundColor(Theme.Colors.textPrimary)
                            .frame(width: 24)
                        Text("프로필 수정")
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                }
                .listRowBackground(Theme.Colors.bgSecondary)

                if let email = authManager.currentUser?.email {
                    HStack {
                        HStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "envelope")
                                .foregroundColor(Theme.Colors.textPrimary)
                                .frame(width: 24)
                            Text("이메일")
                                .foregroundColor(Theme.Colors.textPrimary)
                        }
                        Spacer()
                        Text(email)
                            .font(.subheadline)
                            .foregroundColor(Theme.Colors.textMuted)
                    }
                    .listRowBackground(Theme.Colors.bgSecondary)
                }
            }

            // App Info
            Section(header: Text("앱 정보").foregroundColor(Theme.Colors.textSecondary)) {
                HStack {
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "info.circle")
                            .foregroundColor(Theme.Colors.textPrimary)
                            .frame(width: 24)
                        Text("버전")
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                    Spacer()
                    Text(appVersionString)
                        .font(.subheadline)
                        .foregroundColor(Theme.Colors.textMuted)
                }
                .listRowBackground(Theme.Colors.bgSecondary)
            }

            // Account Actions
            Section(header: Text("계정").foregroundColor(Theme.Colors.textSecondary)) {
                Button(action: { showLogoutConfirmation = true }) {
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                            .frame(width: 24)
                        Text("로그아웃")
                            .foregroundColor(.red)
                    }
                }
                .listRowBackground(Theme.Colors.bgSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.bgPrimary)
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Theme.Colors.bgPrimary, for: .navigationBar)
        .confirmationDialog("로그아웃 하시겠습니까?", isPresented: $showLogoutConfirmation) {
            Button("로그아웃", role: .destructive) {
                authManager.logout()
            }
            Button("취소", role: .cancel) {}
        }
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
