import SwiftUI

struct ScriptEditorView: View {
    @ObservedObject var storage: ScriptStorage
    @State private var editingContent: String = ""
    @State private var editingTitle: String = ""
    @State private var showingNewScript: Bool = false

    var body: some View {
        HSplitView {
            // Scripts list
            VStack(spacing: 0) {
                List(storage.scripts, selection: Binding(
                    get: { storage.currentScript?.id },
                    set: { id in
                        if let id, let script = storage.scripts.first(where: { $0.id == id }) {
                            storage.select(script)
                            editingContent = script.content
                            editingTitle = script.title
                        }
                    }
                )) { script in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(script.title)
                            .font(.system(size: 13, weight: .medium))
                        Text(script.updatedAt, style: .relative)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    .tag(script.id)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            storage.delete(script)
                        }
                    }
                }
                .listStyle(.sidebar)

                Divider()

                Button(action: { createNewScript() }) {
                    Label("New Script", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderless)
                .padding(12)
            }
            .frame(minWidth: 180, maxWidth: 220)

            // Editor
            VStack(spacing: 0) {
                // Title field
                TextField("Script Title", text: $editingTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .onChange(of: editingTitle) { _, newValue in
                        updateScript()
                    }

                Divider()

                // Content editor
                TextEditor(text: $editingContent)
                    .font(.system(size: 15))
                    .scrollContentBackground(.hidden)
                    .padding(16)
                    .onChange(of: editingContent) { _, newValue in
                        updateScript()
                    }

                Divider()

                // Stats bar
                HStack {
                    Text("\(wordCount) words")
                    Spacer()
                    Text("~\(estimatedTime) min read")
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            if let script = storage.currentScript {
                editingContent = script.content
                editingTitle = script.title
            }
        }
    }

    private var wordCount: Int {
        editingContent.split(separator: " ").count
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

    private func createNewScript() {
        let script = Script(title: "New Script", content: "")
        storage.create(script)
        editingContent = ""
        editingTitle = "New Script"
    }
}
