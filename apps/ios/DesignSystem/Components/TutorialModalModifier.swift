import SwiftUI

public struct TutorialModalModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let description: String
    let iconAnimation: AnyView // Allow passing custom animated views (e.g. Lottie/SF Symbols)
    
    // UserDefaults key to avoid showing again if requested
    let userDefaultsKey: String?
    @State private var dontShowAgain: Bool = false
    
    public func body(content: Content) -> some View {
        ZStack {
            content
            
            if isPresented {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        dismiss()
                    }
                
                VStack(spacing: 0) {
                    // Header Area with Icon
                    ZStack {
                        Theme.Colors.bgSecondary
                        iconAnimation
                            .padding(.vertical, 40)
                    }
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl))
                    .padding(Theme.Spacing.md)
                    
                    // Content Area
                    VStack(spacing: Theme.Spacing.md) {
                        Text(title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                        
                        Text(description)
                            .font(.body)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                        
                        // Checkbox for "Don't show again"
                        if userDefaultsKey != nil {
                            Button(action: {
                                dontShowAgain.toggle()
                            }) {
                                HStack(spacing: Theme.Spacing.xs) {
                                    Image(systemName: dontShowAgain ? "checkmark.square.fill" : "square")
                                        .foregroundColor(dontShowAgain ? Theme.Colors.violetAccent : Theme.Colors.textMuted)
                                    Text("다시 보지 않기")
                                        .font(.subheadline)
                                        .foregroundColor(Theme.Colors.textSecondary)
                                }
                            }
                            .padding(.top, Theme.Spacing.sm)
                        }
                        
                        PrimaryButton(title: "시작하기", showGlow: false) {
                            dismiss()
                        }
                        .padding(.top, Theme.Spacing.sm)
                    }
                    .padding(Theme.Spacing.xl)
                }
                .background(Theme.Colors.bgPrimary)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl))
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                .padding(.horizontal, Theme.Spacing.lg)
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPresented)
        .onAppear {
            checkUserDefaults()
        }
    }
    
    private func checkUserDefaults() {
        if let key = userDefaultsKey, UserDefaults.standard.bool(forKey: key) {
            // Already requested not to show
            isPresented = false
        }
    }
    
    private func dismiss() {
        if let key = userDefaultsKey, dontShowAgain {
            UserDefaults.standard.set(true, forKey: key)
        }
        withAnimation {
            isPresented = false
        }
    }
}

public extension View {
    func tutorialModal(
        isPresented: Binding<Bool>,
        title: String,
        description: String,
        iconAnimation: AnyView,
        userDefaultsKey: String? = nil
    ) -> some View {
        self.modifier(TutorialModalModifier(
            isPresented: isPresented,
            title: title,
            description: description,
            iconAnimation: iconAnimation,
            userDefaultsKey: userDefaultsKey
        ))
    }
}
