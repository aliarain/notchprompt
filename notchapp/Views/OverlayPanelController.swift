import AppKit
import SwiftUI
import DynamicNotchKit

@MainActor
final class OverlayPanelController {
    private var notch: DynamicNotch<TeleprompterContentView, EmptyView, EmptyView>?
    private let scriptStorage: ScriptStorage
    private let scrollingController: ScrollingController

    private var isExpanded = false

    var isVisible: Bool {
        isExpanded
    }

    init(scriptStorage: ScriptStorage, scrollingController: ScrollingController) {
        self.scriptStorage = scriptStorage
        self.scrollingController = scrollingController
    }

    func show() {
        createNotch()

        Task {
            guard let notch else { return }
            await notch.expand()
            isExpanded = true

            // Set sharingType = .none for screen share invisibility
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                for window in NSApp.windows {
                    if window.level == .screenSaver, let panel = window as? NSPanel {
                        panel.sharingType = .none
                    }
                }
            }
        }
    }

    func hide() {
        // Stop scrolling immediately
        scrollingController.stopAutoScroll()

        // Mark as hidden right away so UI responds instantly
        isExpanded = false

        // Then animate the notch closed
        Task {
            await notch?.hide()
            notch = nil
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
        let storage = scriptStorage
        let controller = scrollingController

        notch = DynamicNotch(
            hoverBehavior: [.keepVisible, .hapticFeedback],
            style: .auto
        ) {
            TeleprompterContentView(
                scriptStorage: storage,
                scrollingController: controller,
                onClose: { [weak self] in
                    self?.hide()
                }
            )
        }
    }
}
