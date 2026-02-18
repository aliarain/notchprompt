import SwiftUI

struct TeleprompterContentView: View {
    @ObservedObject var scriptStorage: ScriptStorage
    @ObservedObject var scrollingController: ScrollingController
    var onClose: () -> Void

    @State private var isHovering = false
    @State private var showControls = true
    @State private var keyMonitor: Any?
    @State private var scriptTitle: String = ""
    @State private var showTitleFlash = false

    @AppStorage("overlay.fontSize") private var fontSize: Double = 16
    @AppStorage("overlay.textColor") private var textColorHex: String = "#FFFFFF"

    private var lines: [String] {
        scriptStorage.currentScript?.lines ?? []
    }

    var body: some View {
        ZStack {
            if scrollingController.isCountingDown {
                CountdownView(value: scrollingController.countdownValue)
                    .transition(.scale.combined(with: .opacity))
            } else {
                VStack(spacing: 0) {
                    scriptContent
                    progressBar
                    controlBar
                }
            }

            if showTitleFlash {
                titleFlashOverlay
            }
        }
        .frame(width: 500, height: 200)
        .clipped()
        .onAppear {
            scrollingController.setTotalLines(lines.count)
            installKeyMonitor()
        }
        .onDisappear {
            removeKeyMonitor()
        }
        .onChange(of: scriptStorage.currentScript?.id) { _, _ in
            scrollingController.reset()
            scrollingController.setTotalLines(lines.count)
            flashTitle()
        }
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                scrollingController.hoverPause()
                withAnimation(Theme.quickSpring) { showControls = true }
            } else {
                scrollingController.hoverResume()
            }
        }
        .animation(Theme.springAnimation, value: scrollingController.isCountingDown)
    }

    private var scriptContent: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 6) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        lineView(line, at: index)
                            .id(index)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .mask(edgeFadeMask)
            .onChange(of: scrollingController.scrollOffset) { _, _ in
                let targetLine = min(lines.count - 1, max(0, Int(scrollingController.scrollOffset / 30)))
                if targetLine != scrollingController.currentLineIndex {
                    scrollingController.currentLineIndex = targetLine
                }
                withAnimation(Theme.smoothEase) {
                    proxy.scrollTo(targetLine, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func lineView(_ line: String, at index: Int) -> some View {
        let isFocused = index == scrollingController.currentLineIndex
        let distance = abs(index - scrollingController.currentLineIndex)
        let opacity = isFocused ? 1.0 : max(0.25, 1.0 - Double(distance) * 0.25)

        if let cue = CueType.parse(line) {
            cueBadge(cue)
                .opacity(opacity)
                .animation(Theme.smoothEase, value: scrollingController.currentLineIndex)
        } else {
            Text(line)
                .font(.system(size: fontSize, weight: isFocused ? .semibold : .regular, design: .rounded))
                .foregroundColor(Color(hex: textColorHex).opacity(opacity))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)
                .background(
                    isFocused
                        ? RoundedRectangle(cornerRadius: 6)
                            .fill(Theme.accentPrimary.opacity(0.12))
                            .shadow(color: Theme.accentPrimary.opacity(0.15), radius: 8)
                        : nil
                )
                .scaleEffect(isFocused ? 1.02 : 1.0)
                .animation(Theme.springAnimation, value: isFocused)
                .animation(Theme.smoothEase, value: scrollingController.currentLineIndex)
        }
    }

    private func cueBadge(_ cue: CueType) -> some View {
        Text(cue.label)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color(hex: cue.color).opacity(0.85))
            )
    }

    private var edgeFadeMask: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, .white], startPoint: .top, endPoint: .bottom)
                .frame(height: 20)
            Color.white
            LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 20)
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.1))
                Capsule()
                    .fill(Theme.accentGradient)
                    .frame(width: geo.size.width * scrollingController.progress)
                    .animation(Theme.smoothEase, value: scrollingController.progress)
            }
        }
        .frame(height: 3)
        .padding(.horizontal, 20)
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            // Navigation controls
            Button(action: { scrollingController.scrollUp() }) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(GlassButtonStyle())

            Button(action: { scrollingController.toggleAutoScroll() }) {
                Image(systemName: scrollingController.isScrolling ? "pause.fill" : "play.fill")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(GlassButtonStyle())

            Button(action: { scrollingController.scrollDown() }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(GlassButtonStyle())

            // Speed controls (visible during auto/voice scroll)
            if scrollingController.mode != .manual {
                Divider()
                    .frame(height: 20)
                    .opacity(0.3)

                Button(action: { scrollingController.adjustSpeed(delta: -10) }) {
                    Image(systemName: "minus")
                        .font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(GlassButtonStyle())

                Text("\(Int(scrollingController.wordsPerMinute))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 32)
                    .animation(Theme.quickSpring, value: scrollingController.wordsPerMinute)

                Button(action: { scrollingController.adjustSpeed(delta: 10) }) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(GlassButtonStyle())
            }

            Spacer()

            if scrollingController.isPausedByHover {
                Text("PAUSED")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.cuePause)
                    .transition(.opacity)
            }

            // Line position indicator
            if lines.count > 0 {
                Text("\(scrollingController.currentLineIndex + 1)/\(lines.count)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }

            Button(action: { scrollingController.reset() }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(GlassButtonStyle())

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(GlassButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .animation(Theme.quickSpring, value: scrollingController.isPausedByHover)
        .animation(Theme.quickSpring, value: scrollingController.mode)
    }

    private var titleFlashOverlay: some View {
        Text(scriptStorage.currentScript?.title ?? "")
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
            )
            .transition(.opacity.combined(with: .scale(scale: 0.8)))
    }

    private func flashTitle() {
        withAnimation(Theme.springAnimation) { showTitleFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(Theme.smoothEase) { showTitleFlash = false }
        }
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            switch event.keyCode {
            case 126: scrollingController.scrollUp(); return nil
            case 125: scrollingController.scrollDown(); return nil
            case 49: scrollingController.toggleAutoScroll(); return nil
            case 53: onClose(); return nil
            default: return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
}

struct CountdownView: View {
    let value: Int

    @State private var animateScale = false

    var body: some View {
        Text("\(value)")
            .font(.system(size: 48, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.accentGradient)
            .scaleEffect(animateScale ? 1.0 : 0.3)
            .opacity(animateScale ? 1.0 : 0.0)
            .onAppear {
                withAnimation(Theme.springAnimation) { animateScale = true }
            }
            .onChange(of: value) { _, _ in
                animateScale = false
                withAnimation(Theme.springAnimation) { animateScale = true }
            }
    }
}
