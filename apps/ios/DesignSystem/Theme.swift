import SwiftUI

// MARK: - Theme Engine
public enum Theme {
    
    // MARK: - Colors
    public enum Colors {
        // Core Web Parity
        public static let bgPrimary = Color(hex: "#09090b") // Zinc-950
        public static let bgSecondary = Color(hex: "#18181b") // Zinc-900 (Cards, Modals, Sidebar)
        
        // Brand & Accent
        public static let violetAccent = Color(hex: "#7c3aed") // Violet-600
        
        // Glow / Neon
        public static let neonGlow = Color.purple.opacity(0.3)
        
        // Borders
        public static let glassBorder = Color.white.opacity(0.08)
        
        // Text
        public static let textPrimary = Color.white
        public static let textSecondary = Color(hex: "#a1a1aa") // Zinc-400
        public static let textMuted = Color(hex: "#52525b") // Zinc-600
        
        // System
        public static let success = Color.green
        public static let error = Color.red
    }
    
    // MARK: - Spacing
    public enum Spacing {
        public static let xss: CGFloat = 4
        public static let xs: CGFloat = 8
        public static let sm: CGFloat = 12
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let xl: CGFloat = 32
        public static let xxl: CGFloat = 48
    }
    
    // MARK: - Radius
    public enum Radius {
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16 // rounded-xl parity
        public static let xl: CGFloat = 24
        public static let full: CGFloat = 9999
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
