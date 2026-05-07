import AppKit
import SwiftUI
import DynamicNotchKit

@MainActor
final class OverlayPanelController {
    private var notch: DynamicNotch<TeleprompterContentView, EmptyView, EmptyView>?
    private var floatingPanel: NSPanel?
    private var fullscreenPanel: NSPanel?

    private let scriptStorage: ScriptStorage
    private let scrollingController: ScrollingController
    private let speechManager: SpeechRecognitionManager

    @AppStorage("overlay.followMouse") private var followMouse: Bool = true
    @AppStorage("overlay.useTransparency") private var useTransparency: Bool = false

    private var isExpanded = false

    var isVisible: Bool { isExpanded }

    init(scriptStorage: ScriptStorage,
         scrollingController: ScrollingController,
         speechManager: SpeechRecognitionManager) {
        self.scriptStorage = scriptStorage
        self.scrollingController = scrollingController
        self.speechManager = speechManager
    }

    func show() {
        switch scrollingController.overlayDisplayMode {
        case .notch:
            showNotch()
        case .floating:
            showFloating()
        case .fullscreen:
            showFullscreen()
        }
    }

    func hide() {
        speechManager.forceStop()
        scrollingController.stopAutoScroll()
        isExpanded = false

        switch scrollingController.overlayDisplayMode {
        case .notch:
            Task {
                await notch?.hide()
                notch = nil
            }
        case .floating:
            floatingPanel?.orderOut(nil)
            floatingPanel = nil
        case .fullscreen:
            fullscreenPanel?.orderOut(nil)
            fullscreenPanel = nil
        }
    }

    func toggle() {
        if isExpanded { hide() } else { show() }
    }

    // MARK: - Notch Mode

    private func showNotch() {
        createNotch()

        Task {
            guard let notch else { return }
            await notch.expand()
            isExpanded = true

            // Make overlay invisible in screen shares
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                for window in NSApp.windows {
                    if window.level == .screenSaver, let panel = window as? NSPanel {
                        panel.sharingType = .none
                    }
                }
            }
        }
    }

    private func createNotch() {
        let storage = scriptStorage
        let controller = scrollingController
        let speech = speechManager

        notch = DynamicNotch(
            hoverBehavior: [.keepVisible, .hapticFeedback],
            style: .auto
        ) {
            TeleprompterContentView(
                scriptStorage: storage,
                scrollingController: controller,
                speechManager: speech,
                onClose: { [weak self] in
                    self?.hide()
                }
            )
        }
    }

    // MARK: - Floating Mode (Feature 6)

    func showFloating() {
        let screen = targetScreen()
        let width: CGFloat = 400
        let height: CGFloat = 220
        let x = screen.frame.midX - width / 2
        let y = screen.frame.midY - height / 2

        let panel = NSPanel(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.isMovableByWindowBackground = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.sharingType = .none
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        let storage = scriptStorage
        let controller = scrollingController
        let speech = speechManager

        let contentView = ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black)
            TeleprompterContentView(
                scriptStorage: storage,
                scrollingController: controller,
                speechManager: speech,
                onClose: { [weak self] in
                    self?.hide()
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .frame(width: width, height: height)

        panel.contentView = NSHostingView(rootView: contentView)
        panel.makeKeyAndOrderFront(nil)
        floatingPanel = panel
        isExpanded = true
    }

    // MARK: - Fullscreen Mode (Feature 7)

    func showFullscreen() {
        let screen = targetScreen()

        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = true
        panel.backgroundColor = .black
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.sharingType = .none

        let storage = scriptStorage
        let controller = scrollingController
        let speech = speechManager

        let contentView = ZStack {
            Color.black
            TeleprompterContentView(
                scriptStorage: storage,
                scrollingController: controller,
                speechManager: speech,
                onClose: { [weak self] in
                    self?.hide()
                }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        panel.contentView = NSHostingView(rootView: contentView)
        panel.makeKeyAndOrderFront(nil)
        fullscreenPanel = panel
        isExpanded = true
    }

    // MARK: - Multi-Display Support (Feature 18)

    private func targetScreen() -> NSScreen {
        if followMouse {
            let mouse = NSEvent.mouseLocation
            return NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
                ?? NSScreen.main
                ?? NSScreen.screens[0]
        }
        return NSScreen.main ?? NSScreen.screens[0]
    }
}
