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
    }

    func applicationWillTerminate(_ notification: Notification) {
        globalMonitors.forEach { NSEvent.removeMonitor($0) }
        globalMonitors.removeAll()
        iconPulseTimer?.invalidate()
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

    private func setupGlobalHotkeys() {
        // Global monitor: works when OTHER apps are focused
        // NOTE: Requires Accessibility permission in System Preferences
        let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains([.command, .shift]) else { return }
            switch event.charactersIgnoringModifiers {
            case "o":
                DispatchQueue.main.async { self?.toggleOverlay() }
            case "s":
                DispatchQueue.main.async { self?.toggleScroll() }
            case "r":
                DispatchQueue.main.async { self?.resetScroll() }
            case "]":
                DispatchQueue.main.async { self?.nextScript() }
            case "[":
                DispatchQueue.main.async { self?.previousScript() }
            default:
                break
            }
        }
        if let monitor = globalMonitor {
            globalMonitors.append(monitor)
        }

        // Local monitor: works when THIS app is focused (no permissions needed)
        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Cmd+Shift shortcuts
            if event.modifierFlags.contains([.command, .shift]) {
                switch event.charactersIgnoringModifiers {
                case "o":
                    DispatchQueue.main.async { self?.toggleOverlay() }
                    return nil
                case "s":
                    DispatchQueue.main.async { self?.toggleScroll() }
                    return nil
                case "r":
                    DispatchQueue.main.async { self?.resetScroll() }
                    return nil
                case "]":
                    DispatchQueue.main.async { self?.nextScript() }
                    return nil
                case "[":
                    DispatchQueue.main.async { self?.previousScript() }
                    return nil
                default:
                    break
                }
            }

            // Ctrl+` (backtick) — creative toggle for overlay
            if event.modifierFlags.contains(.control),
               event.charactersIgnoringModifiers == "`" {
                DispatchQueue.main.async { self?.toggleOverlay() }
                return nil
            }

            // Ctrl+Space — toggle auto-scroll
            if event.modifierFlags.contains(.control),
               event.keyCode == 49 {
                DispatchQueue.main.async { self?.toggleScroll() }
                return nil
            }

            return event
        }
        if let monitor = localMonitor {
            globalMonitors.append(monitor)
        }
    }

    func startIconPulse() {
        iconPulseTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            guard let self, let button = self.statusItem?.button else { return }
            self.iconPulseToggle.toggle()
            button.image = NSImage(
                systemSymbolName: self.iconPulseToggle ? "waveform" : "text.alignleft",
                accessibilityDescription: "NotchPrompt"
            )
        }
    }

    func stopIconPulse() {
        iconPulseTimer?.invalidate()
        iconPulseTimer = nil
        statusItem?.button?.image = NSImage(systemSymbolName: "text.alignleft", accessibilityDescription: "NotchPrompt")
    }

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
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 550),
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
            // Auto-switch to auto scroll mode when user triggers scroll
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
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(scrollingController: scrollingController)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
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
}
