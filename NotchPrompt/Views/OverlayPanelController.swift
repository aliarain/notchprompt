import AppKit
import SwiftUI
import DynamicNotchKit

@MainActor
final class OverlayPanelController {
    private var notch: DynamicNotch<TeleprompterContentView, EmptyView, EmptyView>?
    private let scriptStorage: ScriptStorage
    private let scrollingController: ScrollingController
    private let speechManager: SpeechRecognitionManager

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

    func hide() {
        speechManager.forceStop()
        scrollingController.stopAutoScroll()
        isExpanded = false

        Task {
            await notch?.hide()
            notch = nil
        }
    }

    func toggle() {
        if isExpanded { hide() } else { show() }
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
}
