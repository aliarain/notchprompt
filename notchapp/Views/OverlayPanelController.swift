import AppKit
import SwiftUI

final class OverlayPanelController {
    private var panel: NSPanel?
    private let scriptStorage: ScriptStorage
    private let scrollingController: ScrollingController

    // Notch dimensions (MacBook Pro 14"/16")
    private let notchWidth: CGFloat = 180
    private let notchHeight: CGFloat = 32
    private let panelWidth: CGFloat = 340
    private let panelHeight: CGFloat = 140

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    init(scriptStorage: ScriptStorage, scrollingController: ScrollingController) {
        self.scriptStorage = scriptStorage
        self.scrollingController = scrollingController
        setupPanel()
    }

    private func setupPanel() {
        guard let screen = NSScreen.main else { return }

        // Position: centered horizontally, flush with top of screen (below menu bar)
        let menuBarHeight: CGFloat = NSStatusBar.system.thickness
        let xPos = (screen.frame.width - panelWidth) / 2
        let yPos = screen.frame.height - panelHeight - menuBarHeight

        panel = NSPanel(
            contentRect: NSRect(x: xPos, y: yPos, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        guard let panel else { return }

        // THE MAGIC LINE: Makes overlay invisible in screen shares
        panel.sharingType = .none

        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.ignoresMouseEvents = false
        panel.isMovableByWindowBackground = false

        let contentView = NotchOverlayView(
            scriptStorage: scriptStorage,
            scrollingController: scrollingController
        )
        panel.contentView = NSHostingView(rootView: contentView)
    }

    func show() {
        panel?.orderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }
}
