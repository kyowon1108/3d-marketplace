import SwiftUI

public struct CustomSegmentedPicker: View {
    let options: [String]
    @Binding var selection: String
    @Namespace private var animation
    
    public init(options: [String], selection: Binding<String>) {
        self.options = options
        self._selection = selection
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection = option
                    }
                }) {
                    VStack(spacing: 8) {
                        Text(option)
                            .font(.system(size: 16, weight: selection == option ? .bold : .medium))
                            .foregroundColor(selection == option ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                        
                        if selection == option {
                            Rectangle()
                                .fill(Theme.Colors.violetAccent)
                                .frame(height: 3)
                                .matchedGeometryEffect(id: "TabIndicator", in: animation)
                        } else {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 3)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, Theme.Spacing.md)
        .background(
            VStack {
                Spacer()
                Rectangle()
                    .fill(Theme.Colors.glassBorder)
                    .frame(height: 1)
            }
        )
    }
}
