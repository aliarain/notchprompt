import AppKit
import SwiftUI
import DynamicNotchKit

@MainActor
final class OverlayPanelController {
    private var notch: (any DynamicNotchControllable)?
    private let scriptStorage: ScriptStorage
    private let scrollingController: ScrollingController
    private var onCloseHandler: (() -> Void)?

    private var isExpanded = false

    var isVisible: Bool {
        isExpanded
    }

    init(scriptStorage: ScriptStorage, scrollingController: ScrollingController) {
        self.scriptStorage = scriptStorage
        self.scrollingController = scrollingController
    }

    func show() {
        if notch == nil {
            createNotch()
        }

        Task {
            await notch?.expand(on: NSScreen.main ?? NSScreen.screens[0])
            isExpanded = true

            // Find the window and set sharingType = .none for screen share invisibility
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let window = NSApp.windows.first(where: { $0.level == .screenSaver && $0 is NSPanel }) as? NSPanel {
                    window.sharingType = .none
                }
            }
        }
    }

    func hide() {
        Task {
            await notch?.hide()
            isExpanded = false
        }
    }

    func toggle() {
        if isExpanded {
            hide()
        } else {
            show()
        }
    }

    private func createNotch() {
        let contentView = NotchContentView(
            scriptStorage: scriptStorage,
            scrollingController: scrollingController,
            onClose: { [weak self] in
                self?.hide()
            }
        )

        notch = DynamicNotch(
            hoverBehavior: [.keepVisible, .hapticFeedback],
            style: .auto
        ) {
            contentView
        }
    }
}
