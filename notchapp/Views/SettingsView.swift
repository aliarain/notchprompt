import SwiftUI

struct SettingsView: View {
    @ObservedObject var scrollingController: ScrollingController

    @AppStorage("overlay.fontSize") private var fontSize: Double = 16
    @AppStorage("overlay.opacity") private var backgroundOpacity: Double = 0.85
    @AppStorage("overlay.textColor") private var textColorHex: String = "#FFFFFF"

    var body: some View {
        Form {
            Section {
                LabeledContent("Font Size") {
                    HStack {
                        Slider(value: $fontSize, in: 12...28, step: 1)
                        Text("\(Int(fontSize))pt")
                            .monospacedDigit()
                            .frame(width: 40)
                    }
                }

                LabeledContent("Background") {
                    HStack {
                        Slider(value: $backgroundOpacity, in: 0.3...1.0, step: 0.05)
                        Text("\(Int(backgroundOpacity * 100))%")
                            .monospacedDigit()
                            .frame(width: 40)
                    }
                }

                LabeledContent("Text Color") {
                    Picker("", selection: $textColorHex) {
                        Text("White").tag("#FFFFFF")
                        Text("Yellow").tag("#FFEB3B")
                        Text("Cyan").tag("#00BCD4")
                        Text("Green").tag("#4CAF50")
                    }
                    .labelsHidden()
                    .frame(width: 100)
                }
            } header: {
                Text("Appearance")
            }

            Section {
                LabeledContent("Scroll Speed") {
                    HStack {
                        Slider(value: $scrollingController.wordsPerMinute, in: 50...400, step: 10)
                        Text("\(Int(scrollingController.wordsPerMinute))")
                            .monospacedDigit()
                            .frame(width: 40)
                    }
                }

                LabeledContent("Mode") {
                    Picker("", selection: $scrollingController.mode) {
                        ForEach(ScrollMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 100)
                }
            } header: {
                Text("Scrolling")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    KeyboardShortcutRow(keys: "↑ / ↓", description: "Scroll up/down")
                    KeyboardShortcutRow(keys: "Space", description: "Play/Pause")
                    KeyboardShortcutRow(keys: "⌘O", description: "Toggle overlay")
                    KeyboardShortcutRow(keys: "⌘E", description: "Open editor")
                }
            } header: {
                Text("Keyboard Shortcuts")
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .padding()
    }
}

struct KeyboardShortcutRow: View {
    let keys: String
    let description: String

    var body: some View {
        HStack {
            Text(keys)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.secondary.opacity(0.2))
                )
            Text(description)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
}
