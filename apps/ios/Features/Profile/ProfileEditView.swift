import SwiftUI

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthManager.shared

    @State private var name: String
    @State private var locationName: String
    @State private var isSaving = false

    init() {
        let user = AuthManager.shared.currentUser
        _name = State(initialValue: user?.name ?? "")
        _locationName = State(initialValue: user?.location_name ?? "")
    }

    var body: some View {
        Form {
            Section(header: Text("프로필 정보")) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("닉네임")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    TextField("닉네임을 입력하세요", text: $name)
                        .textFieldStyle(.plain)
                        .foregroundColor(Theme.Colors.textPrimary)
                }
                .listRowBackground(Theme.Colors.bgSecondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("지역")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    TextField("지역을 입력하세요 (예: 강남구)", text: $locationName)
                        .textFieldStyle(.plain)
                        .foregroundColor(Theme.Colors.textPrimary)
                }
                .listRowBackground(Theme.Colors.bgSecondary)
            }

            if let email = authManager.currentUser?.email {
                Section(header: Text("계정")) {
                    HStack {
                        Text("이메일")
                            .foregroundColor(Theme.Colors.textSecondary)
                        Spacer()
                        Text(email)
                            .foregroundColor(Theme.Colors.textMuted)
                    }
                    .listRowBackground(Theme.Colors.bgSecondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.bgPrimary)
        .navigationTitle("프로필 수정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Theme.Colors.bgPrimary, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("취소") { dismiss() }
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: save) {
                    if isSaving {
                        ProgressView().tint(Theme.Colors.violetAccent)
                    } else {
                        Text("저장")
                            .fontWeight(.bold)
                            .foregroundColor(isValid ? Theme.Colors.violetAccent : Theme.Colors.textMuted)
                    }
                }
                .disabled(!isValid || isSaving)
            }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() {
        isSaving = true

        Task {
            do {
                let request = UserUpdateRequest(
                    name: name.trimmingCharacters(in: .whitespaces),
                    location_name: locationName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : locationName.trimmingCharacters(in: .whitespaces)
                )
                let body = try JSONEncoder().encode(request)
                let response: AuthUserResponse = try await APIClient.shared.request(
                    endpoint: "/auth/me",
                    method: "PATCH",
                    body: body
                )
                await MainActor.run {
                    isSaving = false
                    authManager.currentUser = response
                    AppToast(message: "프로필이 수정되었습니다.", style: .success)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    AppToast(message: (error as? APIError)?.userMessage ?? "프로필 수정에 실패했습니다.", style: .error)
                }
            }
        }
    }
}
