import SwiftUI

/// Violet glowing primary CTA button corresponding to Codyssey style.
public struct PrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isDisabled: Bool = false
    var isLoading: Bool = false
    var showGlow: Bool = true

    public init(
        title: String,
        icon: String? = nil,
        isDisabled: Bool = false,
        isLoading: Bool = false,
        showGlow: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isDisabled = isDisabled
        self.isLoading = isLoading
        self.showGlow = showGlow
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                isDisabled ? Theme.Colors.bgSecondary : Theme.Colors.violetAccent
            )
            .foregroundColor(
                isDisabled ? Theme.Colors.textMuted : Theme.Colors.textPrimary
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            // Apply Neon Glow conditionally
            .shadow(
                color: (showGlow && !isDisabled) ? Theme.Colors.neonGlow : .clear,
                radius: 15,
                x: 0,
                y: 8
            )
        }
        .disabled(isDisabled || isLoading)
        .pressableScaleEffect()
    }
}
