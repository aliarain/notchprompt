import SwiftUI
import Combine
import AppKit

// MARK: - NotchBlurView (NSVisualEffectView wrapper)

struct NotchBlurView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - ResizeCursorView

struct ResizeCursorView: NSViewRepresentable {
    func makeNSView(context: Context) -> ResizeCursorNSView { ResizeCursorNSView() }
    func updateNSView(_ nsView: ResizeCursorNSView, context: Context) {}
}

class ResizeCursorNSView: NSView {
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeUpDown)
    }
}

// MARK: - Main Teleprompter Overlay

struct TeleprompterContentView: View {
    @ObservedObject var scriptStorage: ScriptStorage
    @ObservedObject var scrollingController: ScrollingController
    @ObservedObject var speechManager: SpeechRecognitionManager
    var onClose: () -> Void

    @State private var isHovering = false
    @State private var showControls = true
    @State private var keyMonitor: Any?
    @State private var showTitleFlash = false
    @State private var timerWordProgress: Double = 0
    @State private var isUserScrolling: Bool = false
    @State private var isPaused: Bool = false

    // Auto-next page
    @AppStorage("overlay.autoNextPage") private var autoNextPage: Bool = false
    @AppStorage("overlay.autoNextPageDelay") private var autoNextPageDelay: Int = 3
    @State private var autoNextCountdown: Int = 0
    @State private var autoNextTimer: Timer? = nil

    // Page picker
    @State private var showPagePicker: Bool = false

    // Resizable height
    @State private var extraHeight: CGFloat = 0
    @State private var isDragHandleHovering: Bool = false

    // Transparency
    @AppStorage("overlay.useTransparency") private var useTransparency: Bool = false
    @AppStorage("overlay.transparencyOpacity") private var transparencyOpacity: Double = 0.85

    private let scrollTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    @AppStorage("overlay.fontSize") private var fontSize: Double = 16
    @AppStorage("overlay.textColor") private var textColorHex: String = "#FFFFFF"
    @AppStorage("overlay.showElapsedTime") private var showElapsedTime: Bool = true

    private var currentPage: String {
        guard let script = scriptStorage.currentScript else { return "" }
        let idx = scrollingController.currentPageIndex
        guard idx < script.pages.count else { return script.pages.first ?? "" }
        return script.pages[idx]
    }

    private var words: [String] {
        splitTextIntoWords(currentPage)
    }

    private var totalCharCount: Int {
        words.joined(separator: " ").count
    }

    private var hasNextPage: Bool {
        guard let script = scriptStorage.currentScript else { return false }
        let nextIdx = scrollingController.currentPageIndex + 1
        return nextIdx < script.pages.count &&
               !script.pages[nextIdx].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var listeningMode: ListeningMode {
        scrollingController.listeningMode
    }

    private var effectiveCharCount: Int {
        switch listeningMode {
        case .wordTracking:
            return speechManager.recognizedCharCount
        case .classic, .silencePaused:
            return charOffsetForWordProgress(timerWordProgress)
        }
    }

    private func charOffsetForWordProgress(_ progress: Double) -> Int {
        let wholeWord = Int(progress)
        let frac = progress - Double(wholeWord)
        var offset = 0
        for i in 0..<min(wholeWord, words.count) {
            offset += words[i].count + 1
        }
        if wholeWord < words.count {
            offset += Int(Double(words[wholeWord].count) * frac)
        }
        return min(offset, totalCharCount)
    }

    private var isDone: Bool {
        totalCharCount > 0 && effectiveCharCount >= totalCharCount
    }

    private var overlayFont: NSFont {
        scrollingController.fontFamilyPreset.font(size: scrollingController.fontSizePreset.pointSize)
    }

    // Cue color from controller
    private var cueColor: Color {
        Color(hex: scrollingController.cueColorHex)
    }

    var body: some View {
        ZStack {
            // Transparency background
            if useTransparency {
                ZStack {
                    NotchBlurView()
                    Color.black.opacity(1.0 - transparencyOpacity)
                }
            }

            if scrollingController.isCountingDown {
                CountdownView(value: scrollingController.countdownValue)
                    .transition(.scale.combined(with: .opacity))
            } else if isDone && hasNextPage {
                nextPageView
                    .transition(.scale.combined(with: .opacity))
            } else {
                VStack(spacing: 0) {
                    // Elapsed time row
                    if showElapsedTime {
                        HStack {
                            Spacer()
                            ElapsedTimeView(fontSize: 11)
                                .padding(.trailing, 12)
                                .padding(.top, 4)
                        }
                        .frame(height: 20)
                    }

                    scriptContent
                    dragHandle
                    progressBar
                    controlBar
                }
            }

            if showTitleFlash {
                titleFlashOverlay
            }

            // Page picker overlay
            if showPagePicker {
                pagePickerOverlay
            }
        }
        .frame(width: 500, height: 200 + extraHeight)
        .clipped()
        .onAppear {
            scrollingController.setTotalLines(words.count)
            installKeyMonitor()
            startSpeechIfNeeded()
        }
        .onDisappear {
            removeKeyMonitor()
            speechManager.forceStop()
            stopAutoNextTimer()
        }
        .onChange(of: scriptStorage.currentScript?.id) { _, _ in
            resetForNewScript()
        }
        .onChange(of: scrollingController.currentPageIndex) { _, _ in
            resetForNewPage()
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
        .onReceive(scrollTimer) { _ in
            guard !isDone, !isUserScrolling else { return }
            let speed = scrollingController.wordsPerSecond
            switch listeningMode {
            case .classic:
                if !isPaused { timerWordProgress += speed * 0.05 }
            case .silencePaused:
                if !isPaused && speechManager.isListening && speechManager.isSpeaking {
                    timerWordProgress += speed * 0.05
                }
            case .wordTracking:
                break
            }
        }
        .onChange(of: isDone) { _, done in
            if done && hasNextPage && autoNextPage {
                startAutoNextTimer()
            }
        }
        .animation(Theme.springAnimation, value: scrollingController.isCountingDown)
        .animation(Theme.springAnimation, value: isDone)
    }

    // MARK: - Script Content

    private var scriptContent: some View {
        SpeechScrollView(
            words: words,
            highlightedCharCount: effectiveCharCount,
            font: overlayFont,
            highlightColor: Color(hex: textColorHex),
            cueColor: cueColor,
            cueUnreadOpacity: scrollingController.cueBrightness.unreadOpacity,
            cueReadOpacity: scrollingController.cueBrightness.readOpacity,
            onWordTap: { charOffset in
                switch listeningMode {
                case .wordTracking:
                    speechManager.jumpTo(charOffset: charOffset)
                case .classic, .silencePaused:
                    timerWordProgress = wordProgressForCharOffset(charOffset)
                }
            },
            onManualScroll: { scrolling, newProgress in
                isUserScrolling = scrolling
                if !scrolling {
                    timerWordProgress = max(0, min(Double(words.count), newProgress))
                }
            },
            smoothScroll: listeningMode != .wordTracking,
            smoothWordProgress: timerWordProgress,
            isListening: listeningMode == .wordTracking ? speechManager.isListening : true
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func wordProgressForCharOffset(_ charOffset: Int) -> Double {
        var offset = 0
        for (i, word) in words.enumerated() {
            let end = offset + word.count
            if charOffset <= end {
                let frac = Double(charOffset - offset) / Double(max(1, word.count))
                return Double(i) + frac
            }
            offset = end + 1
        }
        return Double(words.count)
    }

    // MARK: - Drag Handle

    private var dragHandle: some View {
        ZStack {
            if isDragHandleHovering {
                ResizeCursorView()
                    .frame(height: 16)
            }
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(isDragHandleHovering ? 0.5 : 0.25))
                .frame(width: 36, height: 4)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 16)
        .contentShape(Rectangle())
        .onHover { hovering in
            isDragHandleHovering = hovering
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    let newExtra = extraHeight + value.translation.height
                    extraHeight = max(0, min(300, newExtra))
                }
        )
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1))
                Capsule()
                    .fill(Theme.accentGradient)
                    .frame(width: geo.size.width * progressValue)
                    .animation(Theme.smoothEase, value: progressValue)
            }
        }
        .frame(height: 3)
        .padding(.horizontal, 20)
    }

    private var progressValue: Double {
        guard totalCharCount > 0 else { return 0 }
        return Double(effectiveCharCount) / Double(totalCharCount)
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: 10) {
            // Waveform (when listening)
            if listeningMode != .classic && speechManager.isListening {
                AudioWaveformProgressView(
                    levels: speechManager.audioLevels,
                    progress: progressValue
                )
                .frame(width: 80, height: 20)
                .transition(.opacity)

                // Last spoken words (Feature 3)
                if listeningMode == .wordTracking {
                    Text(speechManager.lastSpokenWords)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                        .truncationMode(.head)
                        .frame(maxWidth: 100, alignment: .leading)
                        .transition(.opacity)
                }
            }

            // Mic toggle (non-classic modes)
            if listeningMode != .classic {
                Button {
                    if speechManager.isListening {
                        speechManager.stop()
                    } else {
                        speechManager.resume()
                    }
                } label: {
                    Image(systemName: speechManager.isListening ? "mic.fill" : "mic.slash.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(speechManager.isListening ? Theme.accentPrimary : .white.opacity(0.4))
                }
                .buttonStyle(GlassButtonStyle())
            }

            // Classic mode controls
            if listeningMode == .classic {
                Button(action: { scrollingController.scrollUp() }) {
                    Image(systemName: "chevron.up").font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(GlassButtonStyle())

                Button(action: { toggleClassicScroll() }) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(GlassButtonStyle())

                Button(action: { scrollingController.scrollDown() }) {
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(GlassButtonStyle())

                Divider().frame(height: 20).opacity(0.3)

                Button(action: { scrollingController.adjustSpeed(delta: -10) }) {
                    Image(systemName: "minus").font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(GlassButtonStyle())

                Text("\(Int(scrollingController.wordsPerMinute))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 32)

                Button(action: { scrollingController.adjustSpeed(delta: 10) }) {
                    Image(systemName: "plus").font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(GlassButtonStyle())
            }

            Spacer()

            // Hover paused indicator
            if scrollingController.isPausedByHover {
                Text("PAUSED")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.cuePause)
                    .transition(.opacity)
            }

            // Page indicator (tappable for page picker) — Feature 2
            if let script = scriptStorage.currentScript, script.pages.count > 1 {
                Text("\(scrollingController.currentPageIndex + 1)/\(script.pages.count)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .contentShape(Rectangle())
                    .onTapGesture { showPagePicker = true }
                    .onLongPressGesture { showPagePicker = true }
            }

            // Reset
            Button(action: { resetForNewPage() }) {
                Image(systemName: "arrow.counterclockwise").font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(GlassButtonStyle())

            // Close
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(GlassButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .animation(Theme.quickSpring, value: scrollingController.isPausedByHover)
        .animation(Theme.quickSpring, value: listeningMode)
        .animation(Theme.quickSpring, value: speechManager.isListening)
    }

    // MARK: - Next Page View (with auto-countdown — Feature 1)

    private var nextPageView: some View {
        VStack(spacing: 12) {
            if autoNextPage && autoNextCountdown > 0 {
                // Countdown mode
                VStack(spacing: 8) {
                    Text("Next page in")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))

                    Text("\(autoNextCountdown)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.accentGradient)
                        .contentTransition(.numericText())
                        .animation(Theme.springAnimation, value: autoNextCountdown)

                    Button {
                        stopAutoNextTimer()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(.ultraThinMaterial))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    markCurrentPageRead()
                    advanceToNextPage()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("Next Page")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Theme.accentPrimary.opacity(0.85))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onClose) {
                    Text("Done")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Page Picker Overlay (Feature 2)

    private var pagePickerOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .contentShape(Rectangle())
                .onTapGesture { showPagePicker = false }

            VStack(spacing: 0) {
                Text("Jump to Page")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.vertical, 10)

                Divider().opacity(0.3)

                ScrollView {
                    VStack(spacing: 0) {
                        if let script = scriptStorage.currentScript {
                            ForEach(Array(script.pages.enumerated()), id: \.offset) { index, page in
                                Button {
                                    scrollingController.currentPageIndex = index
                                    showPagePicker = false
                                } label: {
                                    HStack(spacing: 10) {
                                        Text("\(index + 1)")
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundStyle(scrollingController.currentPageIndex == index ? Theme.accentPrimary : .white.opacity(0.5))
                                            .frame(width: 20)

                                        Text(pagePickerPreview(page))
                                            .font(.system(size: 11))
                                            .foregroundStyle(.white.opacity(0.8))
                                            .lineLimit(1)
                                            .truncationMode(.tail)

                                        Spacer()

                                        if scriptStorage.readPageIndices.contains(index) {
                                            Circle()
                                                .fill(Color.green)
                                                .frame(width: 6, height: 6)
                                        }

                                        if scrollingController.currentPageIndex == index {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(Theme.accentPrimary)
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        scrollingController.currentPageIndex == index
                                            ? Theme.accentPrimary.opacity(0.1)
                                            : Color.clear
                                    )
                                }
                                .buttonStyle(.plain)

                                if index < (scriptStorage.currentScript?.pages.count ?? 1) - 1 {
                                    Divider().opacity(0.15)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 160)
            }
            .frame(width: 280)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func pagePickerPreview(_ page: String) -> String {
        let trimmed = page.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Empty page" }
        let words = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        return words.prefix(8).joined(separator: " ")
    }

    // MARK: - Title Flash

    private var titleFlashOverlay: some View {
        Text(scriptStorage.currentScript?.title ?? "")
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(.ultraThinMaterial))
            .transition(.opacity.combined(with: .scale(scale: 0.8)))
    }

    private func flashTitle() {
        withAnimation(Theme.springAnimation) { showTitleFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(Theme.smoothEase) { showTitleFlash = false }
        }
    }

    // MARK: - Auto Next Page Timer (Feature 1)

    private func startAutoNextTimer() {
        stopAutoNextTimer()
        autoNextCountdown = autoNextPageDelay
        autoNextTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] _ in
            DispatchQueue.main.async {
                if self.autoNextCountdown > 1 {
                    self.autoNextCountdown -= 1
                } else {
                    self.stopAutoNextTimer()
                    self.markCurrentPageRead()
                    self.advanceToNextPage()
                }
            }
        }
    }

    private func stopAutoNextTimer() {
        autoNextTimer?.invalidate()
        autoNextTimer = nil
        autoNextCountdown = 0
    }

    // MARK: - Helpers

    private func startSpeechIfNeeded() {
        switch listeningMode {
        case .wordTracking:
            speechManager.startWordTracking(with: currentPage)
        case .silencePaused:
            speechManager.startListening()
        case .classic:
            break
        }
    }

    private func resetForNewScript() {
        scrollingController.reset()
        scrollingController.currentPageIndex = 0
        timerWordProgress = 0
        isPaused = false
        speechManager.forceStop()
        scrollingController.setTotalLines(words.count)
        startSpeechIfNeeded()
        flashTitle()
        stopAutoNextTimer()
    }

    private func resetForNewPage() {
        timerWordProgress = 0
        isPaused = false
        speechManager.forceStop()
        scrollingController.recognizedCharCount = 0
        scrollingController.setTotalLines(words.count)
        startSpeechIfNeeded()
        stopAutoNextTimer()
    }

    private func markCurrentPageRead() {
        scriptStorage.readPageIndices.insert(scrollingController.currentPageIndex)
    }

    private func advanceToNextPage() {
        guard let script = scriptStorage.currentScript else { return }
        var nextIdx = scrollingController.currentPageIndex + 1
        while nextIdx < script.pages.count {
            if !script.pages[nextIdx].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { break }
            nextIdx += 1
        }
        guard nextIdx < script.pages.count else { return }
        scrollingController.currentPageIndex = nextIdx
    }

    private func toggleClassicScroll() {
        isPaused.toggle()
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            switch event.keyCode {
            case 126: scrollingController.scrollUp(); return nil
            case 125: scrollingController.scrollDown(); return nil
            case 49:  // Space
                if listeningMode == .classic { toggleClassicScroll() }
                return nil
            case 53: // ESC
                if showPagePicker { showPagePicker = false; return nil }
                onClose(); return nil
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

// MARK: - Countdown View

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
