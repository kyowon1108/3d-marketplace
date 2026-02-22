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
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(selectedCategory == category ? .white : Theme.Colors.textSecondary)
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.sm)
                            .background(
                                Capsule()
                                    .fill(selectedCategory == category ? Theme.Colors.violetAccent : Theme.Colors.bgSecondary)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(selectedCategory == category ? Theme.Colors.neonGlow.opacity(0.5) : Theme.Colors.glassBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .pressableScaleEffect()
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
    }
}
