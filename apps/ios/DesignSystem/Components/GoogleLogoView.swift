import SwiftUI

/// Official Google multicolor 'G' logo rendered as SwiftUI paths.
/// Based on the Google Identity branding guidelines vector paths.
struct GoogleLogoView: View {
    var size: CGFloat = 20

    var body: some View {
        Canvas { context, canvasSize in
            let scale = canvasSize.width / 20.0

            // Blue
            let blue = Path { p in
                p.move(to: CGPoint(x: 19.6 * scale, y: 10.23 * scale))
                p.addCurve(to: CGPoint(x: 19.42 * scale, y: 8.18 * scale),
                           control1: CGPoint(x: 19.6 * scale, y: 9.52 * scale),
                           control2: CGPoint(x: 19.54 * scale, y: 8.84 * scale))
                p.addLine(to: CGPoint(x: 10 * scale, y: 8.18 * scale))
                p.addLine(to: CGPoint(x: 10 * scale, y: 12.05 * scale))
                p.addLine(to: CGPoint(x: 15.38 * scale, y: 12.05 * scale))
                p.addCurve(to: CGPoint(x: 13.39 * scale, y: 15.07 * scale),
                           control1: CGPoint(x: 15.15 * scale, y: 13.3 * scale),
                           control2: CGPoint(x: 14.45 * scale, y: 14.36 * scale))
                p.addLine(to: CGPoint(x: 16.62 * scale, y: 17.58 * scale))
                p.addCurve(to: CGPoint(x: 19.6 * scale, y: 10.23 * scale),
                           control1: CGPoint(x: 18.51 * scale, y: 15.84 * scale),
                           control2: CGPoint(x: 19.6 * scale, y: 13.27 * scale))
                p.closeSubpath()
            }
            context.fill(blue, with: .color(Color(red: 0.259, green: 0.522, blue: 0.957))) // #4285F4

            // Green
            let green = Path { p in
                p.move(to: CGPoint(x: 10 * scale, y: 20 * scale))
                p.addCurve(to: CGPoint(x: 16.62 * scale, y: 17.58 * scale),
                           control1: CGPoint(x: 12.7 * scale, y: 20 * scale),
                           control2: CGPoint(x: 14.96 * scale, y: 19.1 * scale))
                p.addLine(to: CGPoint(x: 13.39 * scale, y: 15.07 * scale))
                p.addCurve(to: CGPoint(x: 10 * scale, y: 16.02 * scale),
                           control1: CGPoint(x: 12.49 * scale, y: 15.67 * scale),
                           control2: CGPoint(x: 11.35 * scale, y: 16.02 * scale))
                p.addCurve(to: CGPoint(x: 4.4 * scale, y: 11.9 * scale),
                           control1: CGPoint(x: 7.4 * scale, y: 16.02 * scale),
                           control2: CGPoint(x: 5.19 * scale, y: 14.26 * scale))
                p.addLine(to: CGPoint(x: 1.06 * scale, y: 14.49 * scale))
                p.addCurve(to: CGPoint(x: 10 * scale, y: 20 * scale),
                           control1: CGPoint(x: 2.71 * scale, y: 17.76 * scale),
                           control2: CGPoint(x: 6.09 * scale, y: 20 * scale))
                p.closeSubpath()
            }
            context.fill(green, with: .color(Color(red: 0.204, green: 0.659, blue: 0.325))) // #34A853

            // Yellow
            let yellow = Path { p in
                p.move(to: CGPoint(x: 4.4 * scale, y: 11.9 * scale))
                p.addCurve(to: CGPoint(x: 4.09 * scale, y: 10 * scale),
                           control1: CGPoint(x: 4.2 * scale, y: 11.3 * scale),
                           control2: CGPoint(x: 4.09 * scale, y: 10.66 * scale))
                p.addCurve(to: CGPoint(x: 4.4 * scale, y: 8.1 * scale),
                           control1: CGPoint(x: 4.09 * scale, y: 9.34 * scale),
                           control2: CGPoint(x: 4.2 * scale, y: 8.7 * scale))
                p.addLine(to: CGPoint(x: 1.06 * scale, y: 5.51 * scale))
                p.addCurve(to: CGPoint(x: 0 * scale, y: 10 * scale),
                           control1: CGPoint(x: 0.39 * scale, y: 6.86 * scale),
                           control2: CGPoint(x: 0 * scale, y: 8.39 * scale))
                p.addCurve(to: CGPoint(x: 1.06 * scale, y: 14.49 * scale),
                           control1: CGPoint(x: 0 * scale, y: 11.61 * scale),
                           control2: CGPoint(x: 0.39 * scale, y: 13.14 * scale))
                p.addLine(to: CGPoint(x: 4.4 * scale, y: 11.9 * scale))
                p.closeSubpath()
            }
            context.fill(yellow, with: .color(Color(red: 0.984, green: 0.737, blue: 0.016))) // #FBBC04

            // Red
            let red = Path { p in
                p.move(to: CGPoint(x: 10 * scale, y: 3.98 * scale))
                p.addCurve(to: CGPoint(x: 13.82 * scale, y: 5.47 * scale),
                           control1: CGPoint(x: 11.47 * scale, y: 3.98 * scale),
                           control2: CGPoint(x: 12.79 * scale, y: 4.48 * scale))
                p.addLine(to: CGPoint(x: 16.69 * scale, y: 2.6 * scale))
                p.addCurve(to: CGPoint(x: 10 * scale, y: 0 * scale),
                           control1: CGPoint(x: 14.96 * scale, y: 0.99 * scale),
                           control2: CGPoint(x: 12.7 * scale, y: 0 * scale))
                p.addCurve(to: CGPoint(x: 1.06 * scale, y: 5.51 * scale),
                           control1: CGPoint(x: 6.09 * scale, y: 0 * scale),
                           control2: CGPoint(x: 2.71 * scale, y: 2.24 * scale))
                p.addLine(to: CGPoint(x: 4.4 * scale, y: 8.1 * scale))
                p.addCurve(to: CGPoint(x: 10 * scale, y: 3.98 * scale),
                           control1: CGPoint(x: 5.19 * scale, y: 5.74 * scale),
                           control2: CGPoint(x: 7.4 * scale, y: 3.98 * scale))
                p.closeSubpath()
            }
            context.fill(red, with: .color(Color(red: 0.914, green: 0.263, blue: 0.208))) // #E94235
        }
        .frame(width: size, height: size)
    }
}
