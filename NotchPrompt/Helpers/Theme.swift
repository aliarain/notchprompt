import SwiftUI

enum Theme {
    // MARK: - Programmatic Colors
    static let accentPrimary = Color(red: 0.36, green: 0.36, blue: 0.90)
    static let accentSecondary = Color(red: 0.58, green: 0.39, blue: 0.92)

    static let accentGradient = LinearGradient(
        colors: [accentPrimary, accentSecondary],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let surfacePrimary = Color(red: 0.08, green: 0.08, blue: 0.12)
    static let surfaceOverlay = Color(red: 0.10, green: 0.10, blue: 0.14)
    static let surfaceElevated = Color(red: 0.14, green: 0.14, blue: 0.18)

    // MARK: - Asset Catalog Colors (light/dark mode aware)
    static let catalogAccent = Color("AccentColor")
    static let catalogAccentSecondary = Color("AccentSecondary")
    static let catalogSurface = Color("SurfacePrimary")
    static let catalogOverlay = Color("SurfaceOverlay")

    // MARK: - Text Hierarchy
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)
    static let textTertiary = Color.white.opacity(0.4)

    // MARK: - Cue Colors
    static let cuePause = Color(red: 1.0, green: 0.58, blue: 0.0)
    static let cueSmile = Color(red: 0.20, green: 0.78, blue: 0.35)
    static let cueCTA = Color(red: 1.0, green: 0.23, blue: 0.19)
    static let cueSection = Color(red: 0.37, green: 0.36, blue: 0.90)

    // MARK: - Animations
    static let springAnimation = Animation.spring(response: 0.35, dampingFraction: 0.75)
    static let quickSpring = Animation.spring(response: 0.25, dampingFraction: 0.8)
    static let smoothEase = Animation.easeInOut(duration: 0.3)
    static let focusGlow = Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true)
    static let gentleBounce = Animation.spring(response: 0.45, dampingFraction: 0.65)
}

struct ScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.92

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(Theme.quickSpring, value: configuration.isPressed)
    }
}

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white.opacity(configuration.isPressed ? 0.5 : 0.9))
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(.ultraThinMaterial)
                    .shadow(color: Theme.accentPrimary.opacity(0.2), radius: configuration.isPressed ? 0 : 4)
            )
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .animation(Theme.quickSpring, value: configuration.isPressed)
    }
}

struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white.opacity(configuration.isPressed ? 0.6 : 0.9))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(Theme.quickSpring, value: configuration.isPressed)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 255, 255, 255)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
