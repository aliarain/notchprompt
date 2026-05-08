import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var overlayController: OverlayPanelController?
    private var editorWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?

    private var globalMonitors: [Any] = []
    private var iconPulseTimer: Timer?
    private var iconPulseToggle = false

    let scriptStorage = ScriptStorage()
    let scrollingController = ScrollingController()
    let speechManager = SpeechRecognitionManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupOverlay()
        setupVoiceScrolling()
        setupGlobalHotkeys()

        // Feature 13: Check for updates silently on launch
        UpdateChecker.shared.checkForUpdates(silent: true)

        // Feature 14: Register as services provider
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
    }

    func applicationWillTerminate(_ notification: Notification) {
        globalMonitors.forEach { NSEvent.removeMonitor($0) }
        globalMonitors.removeAll()
        iconPulseTimer?.invalidate()
        speechManager.forceStop()
    }

    // Feature 16: Unsaved changes — scripts auto-save, so just terminate
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return .terminateNow
    }

    // Feature 15: URL scheme handler (notchprompt://read?text=...)
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard url.scheme == "notchprompt", url.host == "read",
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let text = components.queryItems?.first(where: { $0.name == "text" })?.value
            else { continue }
            let script = Script(title: "Quick Read", content: text)
            scriptStorage.create(script)
            overlayController?.show()
        }
    }

    // Feature 14: macOS Services handler
    @objc func readInNotchPrompt(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let text = pboard.string(forType: .string) else { return }
        let script = Script(title: "Quick Read", content: text)
        scriptStorage.create(script)
        overlayController?.show()
    }

    // MARK: - Setup

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "text.alignleft", accessibilityDescription: "NotchPrompt")
        }

        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Show Overlay", action: #selector(toggleOverlay), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "Edit Script", action: #selector(showEditor), keyEquivalent: "e"))
        menu.addItem(NSMenuItem.separator())

        // Listening mode submenu
        let listeningMenu = NSMenu()
        let listeningItem = NSMenuItem(title: "Listening Mode", action: nil, keyEquivalent: "")
        listeningItem.submenu = listeningMenu
        for mode in ListeningMode.allCases {
            let item = NSMenuItem(title: mode.rawValue, action: #selector(setListeningMode(_:)), keyEquivalent: "")
            item.representedObject = mode
            item.state = scrollingController.listeningMode == mode ? .on : .off
            listeningMenu.addItem(item)
        }
        menu.addItem(listeningItem)

        // Scroll mode submenu
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
        menu.addItem(NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "About NotchPrompt", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    private func setupOverlay() {
        overlayController = OverlayPanelController(
            scriptStorage: scriptStorage,
            scrollingController: scrollingController,
            speechManager: speechManager
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

    private func setupGlobalHotkeys() {
        let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains([.command, .shift]) else { return }
            switch event.charactersIgnoringModifiers {
            case "o": DispatchQueue.main.async { self?.toggleOverlay() }
            case "s": DispatchQueue.main.async { self?.toggleScroll() }
            case "r": DispatchQueue.main.async { self?.resetScroll() }
            case "]": DispatchQueue.main.async { self?.nextScript() }
            case "[": DispatchQueue.main.async { self?.previousScript() }
            default: break
            }
        }
        if let monitor = globalMonitor { globalMonitors.append(monitor) }

        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.command, .shift]) {
                switch event.charactersIgnoringModifiers {
                case "o": DispatchQueue.main.async { self?.toggleOverlay() }; return nil
                case "s": DispatchQueue.main.async { self?.toggleScroll() }; return nil
                case "r": DispatchQueue.main.async { self?.resetScroll() }; return nil
                case "]": DispatchQueue.main.async { self?.nextScript() }; return nil
                case "[": DispatchQueue.main.async { self?.previousScript() }; return nil
                default: break
                }
            }
            if event.modifierFlags.contains(.control), event.charactersIgnoringModifiers == "`" {
                DispatchQueue.main.async { self?.toggleOverlay() }
                return nil
            }
            if event.modifierFlags.contains(.control), event.keyCode == 49 {
                DispatchQueue.main.async { self?.toggleScroll() }
                return nil
            }
            return event
        }
        if let monitor = localMonitor { globalMonitors.append(monitor) }
    }

    // MARK: - Icon Pulse

    func startIconPulse() {
        iconPulseTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, let button = self.statusItem?.button else { return }
                self.iconPulseToggle.toggle()
                button.image = NSImage(
                    systemSymbolName: self.iconPulseToggle ? "waveform" : "text.alignleft",
                    accessibilityDescription: "NotchPrompt"
                )
            }
        }
    }

    func stopIconPulse() {
        iconPulseTimer?.invalidate()
        iconPulseTimer = nil
        statusItem?.button?.image = NSImage(systemSymbolName: "text.alignleft", accessibilityDescription: "NotchPrompt")
    }

    // MARK: - Actions

    @objc private func toggleOverlay() {
        overlayController?.toggle()
    }

    @objc private func showEditor() {
        if let window = editorWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let editorView = ScriptEditorView(storage: scriptStorage)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Script Editor"
        window.contentView = NSHostingView(rootView: editorView)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        editorWindow = window
    }

    @objc private func setListeningMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? ListeningMode else { return }
        scrollingController.listeningMode = mode
        updateListeningModeMenu()

        // Handle voice icon pulse for voice-activated modes
        if mode == .silencePaused || mode == .wordTracking {
            startIconPulse()
        } else {
            stopIconPulse()
        }
    }

    private func updateListeningModeMenu() {
        guard let menu = statusItem?.menu,
              let listeningItem = menu.items.first(where: { $0.title == "Listening Mode" }),
              let listeningMenu = listeningItem.submenu else { return }
        for item in listeningMenu.items {
            if let mode = item.representedObject as? ListeningMode {
                item.state = scrollingController.listeningMode == mode ? .on : .off
            }
        }
    }

    @objc private func setScrollMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? ScrollMode else { return }
        scrollingController.mode = mode
        scrollingController.stopAutoScroll()

        if mode == .voice {
            speechManager.startListening()
            startIconPulse()
        } else {
            speechManager.stopListening()
            stopIconPulse()
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
            scrollingController.mode = .auto
            scrollingController.startAutoScroll()
        case .auto:
            scrollingController.toggleAutoScroll()
        case .voice:
            speechManager.toggleListening()
            if speechManager.isListening {
                scrollingController.startAutoScroll()
                startIconPulse()
            } else {
                scrollingController.stopAutoScroll()
                stopIconPulse()
            }
        }
    }

    @objc private func resetScroll() {
        scrollingController.reset()
    }

    @objc private func nextScript() {
        scriptStorage.selectNext()
    }

    @objc private func previousScript() {
        scriptStorage.selectPrevious()
    }

    @objc private func showSettings() {
        // Always recreate so settings reflect current state
        settingsWindow?.close()
        settingsWindow = nil

        let settingsView = SettingsView(scrollingController: scrollingController)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    @objc private func showAbout() {
        if let window = aboutWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let aboutView = AboutView()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About NotchPrompt"
        window.contentView = NSHostingView(rootView: aboutView)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        aboutWindow = window
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // Feature 13: Check for updates action
    @objc private func checkForUpdates() {
        UpdateChecker.shared.checkForUpdates(silent: false)
    }
}
