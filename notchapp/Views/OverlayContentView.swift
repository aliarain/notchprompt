import SwiftUI

struct NotchContentView: View {
    @ObservedObject var scriptStorage: ScriptStorage
    @ObservedObject var scrollingController: ScrollingController
    var onClose: () -> Void

    @State private var isHovering = false

    @AppStorage("overlay.fontSize") private var fontSize: Double = 14
    @AppStorage("overlay.textColor") private var textColorHex: String = "#FFFFFF"

    var body: some View {
        VStack(spacing: 4) {
            // Top bar with close button (only on hover)
            HStack {
                Spacer()
                if isHovering {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(.white.opacity(0.15)))
                    .transition(.opacity)
                }
            }
            .frame(height: isHovering ? 20 : 4)
            .padding(.horizontal, 8)

            // Script text
            ScrollView(.vertical, showsIndicators: false) {
                Text(scriptStorage.currentScript?.content ?? "No script loaded")
                    .font(.system(size: fontSize, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: textColorHex))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
            }
            .offset(y: -scrollingController.scrollOffset)

            // Bottom controls (only on hover)
            if isHovering {
                HStack(spacing: 12) {
                    Button(action: { scrollingController.scrollUp() }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .buttonStyle(NotchButtonStyle())

                    Button(action: { scrollingController.toggleAutoScroll() }) {
                        Image(systemName: scrollingController.isScrolling ? "pause.fill" : "play.fill")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .buttonStyle(NotchButtonStyle())

                    Button(action: { scrollingController.scrollDown() }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .buttonStyle(NotchButtonStyle())
                }
                .padding(.bottom, 6)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(width: 320, height: 140)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
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
            case 126: scrollingController.scrollUp(); return nil
            case 125: scrollingController.scrollDown(); return nil
            case 49: scrollingController.toggleAutoScroll(); return nil
            case 53: onClose(); return nil // Escape to close
            default: return event
            }
        }
    }
}

struct NotchButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white.opacity(configuration.isPressed ? 0.4 : 0.7))
            .frame(width: 18, height: 18)
            .background(Circle().fill(.white.opacity(0.1)))
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
