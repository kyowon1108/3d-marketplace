import SwiftUI

struct ProductEditView: View {
    let product: ProductResponse
    var onSave: ((ProductResponse) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var description: String
    @State private var priceText: String
    @State private var isSaving = false

    init(product: ProductResponse, onSave: ((ProductResponse) -> Void)? = nil) {
        self.product = product
        self.onSave = onSave
        _title = State(initialValue: product.title)
        _description = State(initialValue: product.description ?? "")
        _priceText = State(initialValue: "\(product.price_cents)")
    }

    var body: some View {
        Form {
            Section(header: Text("상품 정보")) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("제목")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    TextField("상품 제목", text: $title)
                        .textFieldStyle(.plain)
                        .foregroundColor(Theme.Colors.textPrimary)
                }
                .listRowBackground(Theme.Colors.bgSecondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("가격 (원)")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    TextField("가격", text: $priceText)
                        .textFieldStyle(.plain)
                        .keyboardType(.numberPad)
                        .foregroundColor(Theme.Colors.textPrimary)
                }
                .listRowBackground(Theme.Colors.bgSecondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("설명")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    TextEditor(text: $description)
                        .frame(minHeight: 120)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .scrollContentBackground(.hidden)
                }
                .listRowBackground(Theme.Colors.bgSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.bgPrimary)
        .navigationTitle("상품 수정")
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
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Int(priceText) ?? 0) > 0
    }

    private func save() {
        guard let priceCents = Int(priceText), priceCents > 0 else { return }
        isSaving = true

        Task {
            do {
                let request = ProductUpdateRequest(
                    title: title.trimmingCharacters(in: .whitespaces),
                    description: description.trimmingCharacters(in: .whitespaces).isEmpty ? nil : description.trimmingCharacters(in: .whitespaces),
                    price_cents: priceCents
                )
                let body = try JSONEncoder().encode(request)
                let response: ProductResponse = try await APIClient.shared.request(
                    endpoint: "/products/\(product.id)",
                    method: "PATCH",
                    body: body
                )
                await MainActor.run {
                    isSaving = false
                    onSave?(response)
                    AppToast(message: "상품이 수정되었습니다.", style: .success)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    AppToast(message: (error as? APIError)?.userMessage ?? "수정에 실패했습니다.", style: .error)
                }
            }
        }
    }
}
