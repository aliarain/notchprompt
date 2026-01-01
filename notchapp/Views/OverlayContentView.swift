import SwiftUI

struct NotchOverlayView: View {
    @ObservedObject var scriptStorage: ScriptStorage
    @ObservedObject var scrollingController: ScrollingController
    @State private var isHovering = false

    @AppStorage("overlay.fontSize") private var fontSize: Double = 18
    @AppStorage("overlay.textColor") private var textColorHex: String = "#FFFFFF"

    private let notchWidth: CGFloat = 180

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Notch-shaped background
                NotchShape(notchWidth: notchWidth, notchHeight: 0)
                    .fill(.black)

                // Content
                VStack(spacing: 0) {
                    // Script text area
                    ScrollView(.vertical, showsIndicators: false) {
                        Text(scriptStorage.currentScript?.content ?? "No script loaded")
                            .font(.system(size: fontSize, weight: .medium, design: .rounded))
                            .foregroundColor(Color(hex: textColorHex))
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .padding(.bottom, 8)
                            .frame(maxWidth: .infinity)
                    }
                    .offset(y: -scrollingController.scrollOffset)
                    .clipped()

                    // Minimal controls - only show on hover
                    if isHovering {
                        HStack(spacing: 20) {
                            Button(action: { scrollingController.scrollUp() }) {
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .buttonStyle(MinimalButtonStyle())

                            Button(action: { scrollingController.toggleAutoScroll() }) {
                                Image(systemName: scrollingController.isScrolling ? "pause.fill" : "play.fill")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .buttonStyle(MinimalButtonStyle())

                            Button(action: { scrollingController.scrollDown() }) {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .buttonStyle(MinimalButtonStyle())
                        }
                        .padding(.bottom, 8)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
            }
            .clipShape(NotchShape(notchWidth: notchWidth, notchHeight: 0))
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .onAppear {
            setupKeyboardShortcuts()
        }
    }

    private func setupKeyboardShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 126: // Up arrow
                scrollingController.scrollUp()
                return nil
            case 125: // Down arrow
                scrollingController.scrollDown()
                return nil
            case 49: // Space
                scrollingController.toggleAutoScroll()
                return nil
            default:
                return event
            }
        }
    }
}

// Custom shape that creates a notch-like appearance
struct NotchShape: Shape {
    let notchWidth: CGFloat
    let notchHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerRadius: CGFloat = 18

        // Start from top-left, go around
        path.move(to: CGPoint(x: 0, y: cornerRadius))

        // Top-left corner
        path.addQuadCurve(
            to: CGPoint(x: cornerRadius, y: 0),
            control: CGPoint(x: 0, y: 0)
        )

        // Top edge to top-right corner
        path.addLine(to: CGPoint(x: rect.width - cornerRadius, y: 0))

        // Top-right corner
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: cornerRadius),
            control: CGPoint(x: rect.width, y: 0)
        )

        // Right edge
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - cornerRadius))

        // Bottom-right corner
        path.addQuadCurve(
            to: CGPoint(x: rect.width - cornerRadius, y: rect.height),
            control: CGPoint(x: rect.width, y: rect.height)
        )

        // Bottom edge
        path.addLine(to: CGPoint(x: cornerRadius, y: rect.height))

        // Bottom-left corner
        path.addQuadCurve(
            to: CGPoint(x: 0, y: rect.height - cornerRadius),
            control: CGPoint(x: 0, y: rect.height)
        )

        // Left edge back to start
        path.addLine(to: CGPoint(x: 0, y: cornerRadius))

        return path
    }
}

struct MinimalButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white.opacity(configuration.isPressed ? 0.5 : 0.7))
            .frame(width: 24, height: 24)
            .background(
                Circle()
                    .fill(.white.opacity(configuration.isPressed ? 0.2 : 0.1))
            )
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 255, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
