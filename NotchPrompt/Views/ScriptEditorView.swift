import SwiftUI

struct ScriptEditorView: View {
    @ObservedObject var storage: ScriptStorage
    @State private var editingContent: String = ""
    @State private var editingTitle: String = ""
    @State private var showTemplatePicker = false
    @State private var hoveredScriptId: UUID?

    var body: some View {
        HSplitView {
            sidebar
            editor
        }
        .frame(minWidth: 600, minHeight: 450)
        .onAppear {
            if let script = storage.currentScript {
                editingContent = script.content
                editingTitle = script.title
            }
        }
        .sheet(isPresented: $showTemplatePicker) {
            TemplatePickerView { template in
                let script = template.script
                storage.create(script)
                editingContent = script.content
                editingTitle = script.title
                showTemplatePicker = false
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(storage.scripts, selection: Binding(
                get: { storage.currentScript?.id },
                set: { id in
                    if let id, let script = storage.scripts.first(where: { $0.id == id }) {
                        storage.select(script)
                        withAnimation(Theme.smoothEase) {
                            editingContent = script.content
                            editingTitle = script.title
                        }
                    }
                }
            )) { script in
                let isActive = storage.currentScript?.id == script.id

                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isActive ? Theme.accentGradient : LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom))
                        .frame(width: 3)
                        .padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(script.title)
                            .font(.system(size: 13, weight: isActive ? .semibold : .medium))
                            .foregroundColor(isActive ? .primary : .secondary)

                        HStack(spacing: 8) {
                            Text("\(script.wordCount) words")
                            Text(script.updatedAt, style: .relative)
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    }
                    .padding(.leading, 8)
                    .padding(.vertical, 4)
                }
                .tag(script.id)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(hoveredScriptId == script.id ? Color.white.opacity(0.05) : .clear)
                )
                .onHover { hovering in
                    hoveredScriptId = hovering ? script.id : nil
                }
                .contextMenu {
                    Button("Delete", role: .destructive) {
                        withAnimation(Theme.springAnimation) {
                            storage.delete(script)
                            if let current = storage.currentScript {
                                editingContent = current.content
                                editingTitle = current.title
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .animation(Theme.springAnimation, value: storage.scripts.count)

            Divider()

            HStack(spacing: 8) {
                Button(action: { createBlankScript() }) {
                    Label("New", systemImage: "plus")
                }
                .buttonStyle(ScaleButtonStyle())

                Button(action: { showTemplatePicker = true }) {
                    Label("Template", systemImage: "doc.text")
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .font(.system(size: 12))
            .padding(10)
        }
        .frame(minWidth: 180, maxWidth: 220)
    }

    private var editor: some View {
        VStack(spacing: 0) {
            TextField("Script Title", text: $editingTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .onChange(of: editingTitle) { _, _ in updateScript() }

            Divider()

            if editingContent.isEmpty {
                emptyState
            } else {
                TextEditor(text: $editingContent)
                    .font(.system(size: 15, design: .rounded))
                    .scrollContentBackground(.hidden)
                    .padding(16)
                    .onChange(of: editingContent) { _, _ in updateScript() }
            }

            Divider()

            statsBar
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "text.cursor")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(Theme.accentGradient)

            Text("Start typing or paste your script")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)

            Text("Use [Pause], [Smile], [CTA] for inline cues")
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.secondary.opacity(0.7))

            Button("Or choose a template") {
                showTemplatePicker = true
            }
            .buttonStyle(PillButtonStyle())
            .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            editingContent = " "
            editingContent = ""
        }
    }

    private var statsBar: some View {
        HStack(spacing: 16) {
            Label("\(wordCount) words", systemImage: "text.word.spacing")
            Label("\(characterCount) chars", systemImage: "character.cursor.ibeam")
            Spacer()
            Label("~\(estimatedTime) min", systemImage: "clock")
            Label("\(lineCount) lines", systemImage: "list.bullet")
        }
        .font(.system(size: 11, design: .rounded))
        .foregroundColor(.secondary)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    private var wordCount: Int {
        editingContent.split(separator: " ").count
    }

    private var characterCount: Int {
        editingContent.count
    }

    private var lineCount: Int {
        max(1, editingContent.components(separatedBy: .newlines).filter { !$0.isEmpty }.count)
    }

    private var estimatedTime: Int {
        max(1, wordCount / 150)
    }

    private func updateScript() {
        guard var script = storage.currentScript else { return }
        script.title = editingTitle
        script.updateContent(editingContent)
        storage.update(script)
    }

    private func createBlankScript() {
        let script = Script(title: "New Script", content: "")
        storage.create(script)
        withAnimation(Theme.smoothEase) {
            editingContent = ""
            editingTitle = "New Script"
        }
    }
}

struct TemplatePickerView: View {
    var onSelect: (ScriptTemplate) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var hoveredTemplate: ScriptTemplate?

    var body: some View {
        VStack(spacing: 20) {
            Text("Choose a Template")
                .font(.system(size: 18, weight: .bold, design: .rounded))

            Text("Start with a structure, then make it yours")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(ScriptTemplate.allCases) { template in
                    Button(action: { onSelect(template) }) {
                        VStack(spacing: 10) {
                            Image(systemName: template.icon)
                                .font(.system(size: 24, weight: .light))
                                .foregroundStyle(Theme.accentGradient)

                            Text(template.rawValue)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(hoveredTemplate == template ? Theme.surfaceElevated : Theme.surfaceOverlay)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(hoveredTemplate == template ? Theme.accentPrimary.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
                                )
                        )
                        .scaleEffect(hoveredTemplate == template ? 1.03 : 1.0)
                        .animation(Theme.quickSpring, value: hoveredTemplate)
                    }
                    .buttonStyle(.plain)
                    .onHover { h in hoveredTemplate = h ? template : nil }
                }
            }

            Button("Cancel") { dismiss() }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding(24)
        .frame(width: 360)
    }
}
