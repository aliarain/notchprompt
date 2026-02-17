import SwiftUI

struct SettingsView: View {
    @ObservedObject var scrollingController: ScrollingController

    @AppStorage("overlay.fontSize") private var fontSize: Double = 16
    @AppStorage("overlay.opacity") private var backgroundOpacity: Double = 0.85
    @AppStorage("overlay.textColor") private var textColorHex: String = "#FFFFFF"

    var body: some View {
        TabView {
            appearanceTab
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            scrollingTab
                .tabItem {
                    Label("Scrolling", systemImage: "arrow.up.arrow.down")
                }

            shortcutsTab
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 460, height: 420)
    }

    private var appearanceTab: some View {
        Form {
            Section {
                LabeledContent {
                    HStack {
                        Slider(value: $fontSize, in: 12...28, step: 1)
                        Text("\(Int(fontSize))pt")
                            .monospacedDigit()
                            .frame(width: 40)
                    }
                } label: {
                    Label("Font Size", systemImage: "textformat.size")
                }

                LabeledContent {
                    HStack {
                        Slider(value: $backgroundOpacity, in: 0.3...1.0, step: 0.05)
                        Text("\(Int(backgroundOpacity * 100))%")
                            .monospacedDigit()
                            .frame(width: 40)
                    }
                } label: {
                    Label("Background", systemImage: "circle.lefthalf.filled")
                }

                LabeledContent {
                    Picker("", selection: $textColorHex) {
                        HStack { Circle().fill(.white).frame(width: 10, height: 10); Text("White") }.tag("#FFFFFF")
                        HStack { Circle().fill(Color(hex: "#FFEB3B")).frame(width: 10, height: 10); Text("Yellow") }.tag("#FFEB3B")
                        HStack { Circle().fill(Color(hex: "#00BCD4")).frame(width: 10, height: 10); Text("Cyan") }.tag("#00BCD4")
                        HStack { Circle().fill(Color(hex: "#4CAF50")).frame(width: 10, height: 10); Text("Green") }.tag("#4CAF50")
                        HStack { Circle().fill(Color(hex: "#C4B5FD")).frame(width: 10, height: 10); Text("Lavender") }.tag("#C4B5FD")
                    }
                    .labelsHidden()
                    .frame(width: 120)
                } label: {
                    Label("Text Color", systemImage: "paintpalette")
                }
            } header: {
                Text("Display")
            }

            Section {
                previewWidget
            } header: {
                Text("Preview")
            }

            Section {
                Button("Reset to Defaults") {
                    withAnimation(Theme.springAnimation) {
                        fontSize = 16
                        backgroundOpacity = 0.85
                        textColorHex = "#FFFFFF"
                    }
                }
                .foregroundColor(.red)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var previewWidget: some View {
        VStack(spacing: 4) {
            Text("This is how your script will look")
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                .foregroundColor(Color(hex: textColorHex))
            Text("with the current settings applied.")
                .font(.system(size: fontSize, weight: .regular, design: .rounded))
                .foregroundColor(Color(hex: textColorHex).opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(backgroundOpacity))
        )
        .animation(Theme.smoothEase, value: fontSize)
        .animation(Theme.smoothEase, value: textColorHex)
        .animation(Theme.smoothEase, value: backgroundOpacity)
    }

    private var scrollingTab: some View {
        Form {
            Section {
                LabeledContent {
                    HStack {
                        Slider(value: $scrollingController.wordsPerMinute, in: 50...400, step: 10)
                        Text("\(Int(scrollingController.wordsPerMinute)) wpm")
                            .monospacedDigit()
                            .frame(width: 60)
                    }
                } label: {
                    Label("Speed", systemImage: "speedometer")
                }

                LabeledContent {
                    Picker("", selection: $scrollingController.mode) {
                        ForEach(ScrollMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 120)
                } label: {
                    Label("Mode", systemImage: "gear.badge")
                }
            } header: {
                Text("Scroll Settings")
            }

            Section {
                Toggle(isOn: $scrollingController.useCountdown) {
                    Label("Countdown Timer", systemImage: "timer")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label("Hover to Pause", systemImage: "hand.raised")
                    Text("Auto-scroll pauses when you hover over the overlay.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Behavior")
            }

            Section {
                Button("Reset Scroll Settings") {
                    withAnimation(Theme.springAnimation) {
                        scrollingController.wordsPerMinute = 150
                        scrollingController.mode = .manual
                        scrollingController.useCountdown = true
                    }
                }
                .foregroundColor(.red)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var shortcutsTab: some View {
        Form {
            Section {
                KeyboardShortcutRow(keys: "↑ / ↓", description: "Scroll up / down")
                KeyboardShortcutRow(keys: "Space", description: "Play / Pause scroll")
                KeyboardShortcutRow(keys: "Esc", description: "Close overlay")
            } header: {
                Text("Overlay Controls")
            }

            Section {
                KeyboardShortcutRow(keys: "⌃ `", description: "Toggle overlay")
                KeyboardShortcutRow(keys: "⌃ Space", description: "Start / Stop scroll")
                KeyboardShortcutRow(keys: "⌘O", description: "Toggle overlay (menu)")
                KeyboardShortcutRow(keys: "⌘E", description: "Open script editor")
            } header: {
                Text("Quick Actions")
            }

            Section {
                KeyboardShortcutRow(keys: "⇧⌘O", description: "Toggle overlay (global)")
                KeyboardShortcutRow(keys: "⇧⌘S", description: "Start / Stop scroll (global)")
                KeyboardShortcutRow(keys: "⇧⌘R", description: "Reset position (global)")
                KeyboardShortcutRow(keys: "⇧⌘]", description: "Next script")
                KeyboardShortcutRow(keys: "⇧⌘[", description: "Previous script")
            } header: {
                Text("Global Hotkeys (needs Accessibility)")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var aboutTab: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "text.alignleft")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(Theme.accentGradient)

            VStack(spacing: 4) {
                Text("NotchPrompt")
                    .font(.system(size: 20, weight: .bold, design: .rounded))

                Text("Version 1.0.0")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("A teleprompter hidden in your Mac's notch.\nInvisible during screen shares.")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Divider()
                .frame(width: 120)

            VStack(spacing: 4) {
                Text("Built by")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(1.5)

                Text("RaptrX")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))

                Link(destination: URL(string: "https://raptrx.com")!) {
                    Text("raptrx.com")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.accentPrimary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Text("Made with ❤️ in Pakistan")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct KeyboardShortcutRow: View {
    let keys: String
    let description: String

    var body: some View {
        HStack {
            Text(keys)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.primary.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                        )
                )
            Text(description)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}
