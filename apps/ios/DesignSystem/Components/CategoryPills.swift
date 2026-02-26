import SwiftUI

public struct CategoryPills: View {
    let categories: [String]
    @Binding var selectedCategory: String
    
    public init(categories: [String], selectedCategory: Binding<String>) {
        self.categories = categories
        self._selectedCategory = selectedCategory
    }
    
    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(categories, id: \.self) { category in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedCategory = category
                        }
                    }) {
                        Text(category)
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(selectedCategory == category ? .white : Theme.Colors.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedCategory == category ? Theme.Colors.violetAccent : Theme.Colors.bgSecondary)
                            )
                    }
                    .buttonStyle(.plain)
                    .pressableScaleEffect()
                    .accessibilityLabel("\(category) 정렬")
                    .accessibilityHint("상품 목록을 \(category) 기준으로 정렬합니다.")
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
    }
}
