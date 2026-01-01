import SwiftUI

struct TeleprompterContentView: View {
    @ObservedObject var scriptStorage: ScriptStorage
    @ObservedObject var scrollingController: ScrollingController
    var onClose: () -> Void

    @State private var isHovering = false

    @AppStorage("overlay.fontSize") private var fontSize: Double = 14
    @AppStorage("overlay.textColor") private var textColorHex: String = "#FFFFFF"

    var body: some View {
        VStack(spacing: 12) {
            // Script text content
            Text(scriptStorage.currentScript?.content ?? "Welcome to NotchPrompt! Add a script to get started.")
                .font(.system(size: fontSize, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: textColorHex))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .lineLimit(4)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .offset(y: -scrollingController.scrollOffset.truncatingRemainder(dividingBy: 100))

            // Controls
            HStack(spacing: 20) {
                Button(action: { scrollingController.scrollUp() }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(TeleprompterButtonStyle())

                Button(action: { scrollingController.toggleAutoScroll() }) {
                    Image(systemName: scrollingController.isScrolling ? "pause.fill" : "play.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(TeleprompterButtonStyle())

                Button(action: { scrollingController.scrollDown() }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(TeleprompterButtonStyle())

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(TeleprompterButtonStyle())
            }
            .padding(.bottom, 8)
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
            case 53: onClose(); return nil
            default: return event
            }
        }
    }
}

struct TeleprompterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white.opacity(configuration.isPressed ? 0.5 : 0.8))
            .frame(width: 28, height: 28)
            .background(Circle().fill(.white.opacity(0.15)))
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
