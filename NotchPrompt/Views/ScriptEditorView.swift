import SwiftUI
import UniformTypeIdentifiers

struct ScriptEditorView: View {
    @ObservedObject var storage: ScriptStorage
    @State private var editingTitle: String = ""
    @State private var showTemplatePicker = false
    @State private var hoveredScriptId: UUID?
    @State private var currentPageIndex: Int = 0
    @State private var isDroppingPPTX = false
    @State private var dropError: String?

    // Feature 19: Dictation
    @State private var isDictating: Bool = false
    @StateObject private var dictation = DictationManager()

    private var currentPageContent: Binding<String> {
        Binding(
            get: {
                guard let script = storage.currentScript,
                      currentPageIndex < script.pages.count else { return "" }
                return script.pages[currentPageIndex]
            },
            set: { newValue in
                guard var script = storage.currentScript,
                      currentPageIndex < script.pages.count else { return }
                script.pages[currentPageIndex] = newValue
                storage.update(script)
            }
        )
    }

    var body: some View {
        HSplitView {
            scriptSidebar
            HSplitView {
                pageSidebar
                editor
            }
        }
        .frame(minWidth: 700, minHeight: 480)
        .onAppear {
            if let script = storage.currentScript {
                editingTitle = script.title
                currentPageIndex = 0
            }
        }
        .onChange(of: storage.currentScript?.id) { _, _ in
            if let script = storage.currentScript {
                editingTitle = script.title
                currentPageIndex = 0
            }
        }
        .sheet(isPresented: $showTemplatePicker) {
            TemplatePickerView { template in
                let script = template.script
                storage.create(script)
                editingTitle = script.title
                currentPageIndex = 0
                showTemplatePicker = false
            }
        }
        .alert("Import Error", isPresented: Binding(get: { dropError != nil }, set: { if !$0 { dropError = nil } })) {
            Button("OK") { dropError = nil }
        } message: {
            Text(dropError ?? "")
        }
    }

    // MARK: - Script Sidebar (left)

    private var scriptSidebar: some View {
        VStack(spacing: 0) {
            List(storage.scripts, selection: Binding(
                get: { storage.currentScript?.id },
                set: { id in
                    if let id, let script = storage.scripts.first(where: { $0.id == id }) {
                        storage.select(script)
                        withAnimation(Theme.smoothEase) {
                            editingTitle = script.title
                            currentPageIndex = 0
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
                            if script.pages.count > 1 {
                                Text("\(script.pages.count) pages")
                            }
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
                .onHover { hovering in hoveredScriptId = hovering ? script.id : nil }
                .contextMenu {
                    Button("Export…") { storage.saveCurrentScript() }
                    Divider()
                    Button("Delete", role: .destructive) {
                        withAnimation(Theme.springAnimation) {
                            storage.delete(script)
                            if let current = storage.currentScript {
                                editingTitle = current.title
                                currentPageIndex = 0
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

                Button(action: { storage.openFile() }) {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .font(.system(size: 12))
            .padding(10)
        }
        .frame(minWidth: 160, maxWidth: 200)
    }

    // MARK: - Page Sidebar (middle)

    private var pageSidebar: some View {
        VStack(spacing: 0) {
            if let script = storage.currentScript, script.pages.count > 1 {
                List(selection: Binding(
                    get: { currentPageIndex },
                    set: { if let idx = $0 { currentPageIndex = idx } }
                )) {
                    ForEach(Array(script.pages.enumerated()), id: \.offset) { index, page in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 4) {
                                Text("Page \(index + 1)")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(currentPageIndex == index ? Theme.accentPrimary : .secondary)

                                // Feature 12: Read page indicator
                                if storage.readPageIndices.contains(index) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 6, height: 6)
                                }
                            }

                            Text(pagePreview(page))
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 2)
                        .tag(index)
                        .contextMenu {
                            if script.pages.count > 1 {
                                Button("Delete Page", role: .destructive) {
                                    removePage(at: index)
                                }
                            }
                        }
                    }
                }
                .listStyle(.sidebar)

                Divider()

                Button(action: { addPage() }) {
                    Label("Add Page", systemImage: "plus")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(minWidth: script_hasMultiplePages ? 120 : 0, maxWidth: script_hasMultiplePages ? 150 : 0)
    }

    private var script_hasMultiplePages: Bool {
        (storage.currentScript?.pages.count ?? 1) > 1
    }

    // MARK: - Editor (right)

    private var editor: some View {
        VStack(spacing: 0) {
            // Title
            HStack {
                TextField("Script Title", text: $editingTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .onChange(of: editingTitle) { _, _ in updateTitle() }

                Spacer()

                // Page indicator / add page button
                if let script = storage.currentScript {
                    if script.pages.count == 1 {
                        Button(action: { addPage() }) {
                            Label("Add Page", systemImage: "plus.rectangle.on.rectangle")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("Page \(currentPageIndex + 1) of \(script.pages.count)")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            // Text editor with drop support
            ZStack {
                TextEditor(text: currentPageContent)
                    .font(.system(size: 15, design: .rounded))
                    .scrollContentBackground(.hidden)
                    .padding(16)

                if isDroppingPPTX {
                    dropZoneOverlay
                }

                // Feature 19: Dictation button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            toggleDictation()
                        } label: {
                            Image(systemName: isDictating ? "mic.fill" : "mic")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(isDictating ? Theme.accentPrimary : .secondary)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(isDictating ? Theme.accentPrimary.opacity(0.15) : Color.primary.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                        .help(isDictating ? "Stop Dictation" : "Start Dictation")
                        .padding(12)
                    }
                }
            }
            .onAppear {
                dictation.onTextUpdate = { [self] text in
                    appendDictatedText(text)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDroppingPPTX) { providers in
                guard let provider = providers.first else { return false }
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    let ext = url.pathExtension.lowercased()
                    if ext == "key" {
                        DispatchQueue.main.async {
                            self.dropError = "Keynote files can't be imported directly. Export as PowerPoint (.pptx) first:\nIn Keynote: File → Export To → PowerPoint…"
                        }
                        return
                    }
                    guard ext == "pptx" else {
                        DispatchQueue.main.async {
                            self.dropError = "Only .pptx files are supported. For Keynote, export as PowerPoint first."
                        }
                        return
                    }
                    DispatchQueue.main.async {
                        self.storage.importPPTX(from: url)
                    }
                }
                return true
            }

            Divider()
            statsBar
        }
    }

    private var dropZoneOverlay: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Theme.accentPrimary)
            Text("Drop PowerPoint (.pptx) to import slides as pages")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Theme.accentPrimary, style: StrokeStyle(lineWidth: 2, dash: [8]))
                .background(Theme.accentPrimary.opacity(0.06).clipShape(RoundedRectangle(cornerRadius: 12)))
        )
        .padding(8)
    }

    private var statsBar: some View {
        HStack(spacing: 16) {
            if let script = storage.currentScript {
                let page = currentPageIndex < script.pages.count ? script.pages[currentPageIndex] : ""
                let wc = page.split(separator: " ").count
                let cc = page.count
                let lc = max(1, page.components(separatedBy: .newlines).filter { !$0.isEmpty }.count)
                let est = max(1, wc / 150)

                Label("\(wc) words", systemImage: "text.word.spacing")
                Label("\(cc) chars", systemImage: "character.cursor.ibeam")
                Spacer()
                Label("~\(est) min", systemImage: "clock")
                Label("\(lc) lines", systemImage: "list.bullet")
            }
        }
        .font(.system(size: 11, design: .rounded))
        .foregroundColor(.secondary)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private func pagePreview(_ page: String) -> String {
        let trimmed = page.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Empty" }
        let words = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let preview = words.prefix(6).joined(separator: " ")
        return preview.count > 35 ? String(preview.prefix(35)) + "…" : preview
    }

    private func updateTitle() {
        guard var script = storage.currentScript else { return }
        script.title = editingTitle
        storage.update(script)
    }

    private func addPage() {
        guard var script = storage.currentScript else { return }
        script.pages.append("")
        storage.update(script)
        withAnimation(Theme.smoothEase) {
            currentPageIndex = script.pages.count - 1
        }
    }

    private func removePage(at index: Int) {
        guard var script = storage.currentScript, script.pages.count > 1 else { return }
        script.pages.remove(at: index)
        storage.update(script)
        withAnimation(Theme.smoothEase) {
            if currentPageIndex >= script.pages.count {
                currentPageIndex = script.pages.count - 1
            } else if currentPageIndex > index {
                currentPageIndex -= 1
            }
        }
    }

    private func createBlankScript() {
        let script = Script(title: "New Script", content: "")
        storage.create(script)
        withAnimation(Theme.smoothEase) {
            editingTitle = "New Script"
            currentPageIndex = 0
        }
    }

    // MARK: - Dictation (Feature 19)

    private func toggleDictation() {
        if isDictating {
            dictation.stop()
            isDictating = false
        } else {
            dictation.onTextUpdate = { [self] text in
                appendDictatedText(text)
            }
            dictation.start()
            isDictating = true
        }
    }

    private func appendDictatedText(_ text: String) {
        guard var script = storage.currentScript,
              currentPageIndex < script.pages.count else { return }
        let current = script.pages[currentPageIndex]
        // Replace the last dictated segment or append
        let separator = current.isEmpty ? "" : " "
        script.pages[currentPageIndex] = current + separator + text
        storage.update(script)
    }
}

// MARK: - Template Picker

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
