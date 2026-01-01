import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var overlayController: OverlayPanelController?
    private var editorWindow: NSWindow?

    let scriptStorage = ScriptStorage()
    let scrollingController = ScrollingController()
    let speechManager = SpeechRecognitionManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupOverlay()
        setupVoiceScrolling()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "text.alignleft", accessibilityDescription: "NotchPrompt")
        }

        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Show Overlay", action: #selector(toggleOverlay), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "Edit Script", action: #selector(showEditor), keyEquivalent: "e"))
        menu.addItem(NSMenuItem.separator())

        let scrollMenu = NSMenu()
        let scrollItem = NSMenuItem(title: "Scroll Mode", action: nil, keyEquivalent: "")
        scrollItem.submenu = scrollMenu

        for mode in ScrollMode.allCases {
            let item = NSMenuItem(title: mode.rawValue, action: #selector(setScrollMode(_:)), keyEquivalent: "")
            item.representedObject = mode
            item.state = scrollingController.mode == mode ? .on : .off
            scrollMenu.addItem(item)
        }
        menu.addItem(scrollItem)

        menu.addItem(NSMenuItem(title: "Start/Stop Scroll", action: #selector(toggleScroll), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: "Reset Position", action: #selector(resetScroll), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "About NotchPrompt", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    private func setupOverlay() {
        overlayController = OverlayPanelController(
            scriptStorage: scriptStorage,
            scrollingController: scrollingController
        )
    }

    private func setupVoiceScrolling() {
        speechManager.onSpeechDetected = { [weak self] wpm in
            guard let self, self.scrollingController.mode == .voice else { return }
            self.scrollingController.wordsPerMinute = wpm
            if !self.scrollingController.isScrolling {
                self.scrollingController.startAutoScroll()
            }
        }
    }

    @objc private func toggleOverlay() {
        overlayController?.toggle()
    }

    @objc private func showEditor() {
        if editorWindow == nil {
            let editorView = ScriptEditorView(storage: scriptStorage)
            editorWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            editorWindow?.title = "Script Editor"
            editorWindow?.contentView = NSHostingView(rootView: editorView)
            editorWindow?.center()
        }
        editorWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func setScrollMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? ScrollMode else { return }
        scrollingController.mode = mode
        scrollingController.stopAutoScroll()

        if mode == .voice {
            speechManager.startListening()
        } else {
            speechManager.stopListening()
        }

        updateScrollModeMenu()
    }

    private func updateScrollModeMenu() {
        guard let menu = statusItem?.menu,
              let scrollItem = menu.items.first(where: { $0.title == "Scroll Mode" }),
              let scrollMenu = scrollItem.submenu else { return }

        for item in scrollMenu.items {
            if let mode = item.representedObject as? ScrollMode {
                item.state = scrollingController.mode == mode ? .on : .off
            }
        }
    }

    @objc private func toggleScroll() {
        switch scrollingController.mode {
        case .manual:
            break
        case .auto:
            scrollingController.toggleAutoScroll()
        case .voice:
            speechManager.toggleListening()
            if speechManager.isListening {
                scrollingController.startAutoScroll()
            } else {
                scrollingController.stopAutoScroll()
            }
        }
    }

    @objc private func resetScroll() {
        scrollingController.reset()
    }

    @objc private func showSettings() {
        let settingsView = SettingsView(scrollingController: scrollingController)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showAbout() {
        let aboutView = AboutView()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 460),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About NotchPrompt"
        window.contentView = NSHostingView(rootView: aboutView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
