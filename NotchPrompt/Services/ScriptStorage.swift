import Foundation
import Combine
import AppKit
import UniformTypeIdentifiers

final class ScriptStorage: ObservableObject {
    @Published private(set) var scripts: [Script] = []
    @Published var currentScript: Script?

    private let storageKey = "notchprompt.scripts"
    private let currentScriptKey = "notchprompt.currentScriptId"

    private var saveSubject = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()

    init() {
        load()

        saveSubject
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] in self?.persistToDisk() }
            .store(in: &cancellables)
    }

    // MARK: - Load / Save

    func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Script].self, from: data) {
            scripts = decoded
        }

        if let currentId = UserDefaults.standard.string(forKey: currentScriptKey),
           let uuid = UUID(uuidString: currentId) {
            currentScript = scripts.first { $0.id == uuid }
        }

        if currentScript == nil && scripts.isEmpty {
            let defaultScript = Script(
                title: "Welcome",
                pages: [
                    "Welcome to NotchPrompt!\n\nPaste or type your script here.\n\nThis text will scroll smoothly while you present.\n\n[Smile]",
                    "This is page two.\n\nYou can add multiple pages to your script.\n\nUse the page sidebar to navigate between them.\n\n[Pause]"
                ]
            )
            scripts.append(defaultScript)
            currentScript = defaultScript
            persistToDisk()
        } else if currentScript == nil {
            currentScript = scripts.first
        }
    }

    func save() {
        saveSubject.send()
    }

    private func persistToDisk() {
        if let encoded = try? JSONEncoder().encode(scripts) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
        if let current = currentScript {
            UserDefaults.standard.set(current.id.uuidString, forKey: currentScriptKey)
        }
    }

    // MARK: - CRUD

    func create(_ script: Script) {
        scripts.append(script)
        currentScript = script
        persistToDisk()
    }

    func update(_ script: Script) {
        if let index = scripts.firstIndex(where: { $0.id == script.id }) {
            scripts[index] = script
            if currentScript?.id == script.id {
                currentScript = script
            }
            save()
        }
    }

    func delete(_ script: Script) {
        scripts.removeAll { $0.id == script.id }
        if currentScript?.id == script.id {
            currentScript = scripts.first
        }
        persistToDisk()
    }

    func select(_ script: Script) {
        currentScript = script
        persistToDisk()
    }

    func selectNext() {
        guard scripts.count > 1, let current = currentScript,
              let idx = scripts.firstIndex(where: { $0.id == current.id }) else { return }
        currentScript = scripts[(idx + 1) % scripts.count]
        persistToDisk()
    }

    func selectPrevious() {
        guard scripts.count > 1, let current = currentScript,
              let idx = scripts.firstIndex(where: { $0.id == current.id }) else { return }
        let prev = idx == 0 ? scripts.count - 1 : idx - 1
        currentScript = scripts[prev]
        persistToDisk()
    }

    // MARK: - File Import / Export

    func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "notchprompt") ?? .data,
            UTType(filenameExtension: "pptx") ?? .data,
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            let ext = url.pathExtension.lowercased()
            if ext == "pptx" {
                self?.importPPTX(from: url)
            } else {
                self?.openNotchPromptFile(url)
            }
        }
    }

    func saveCurrentScript() {
        guard let script = currentScript else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "notchprompt") ?? .data]
        panel.nameFieldStringValue = "\(script.title).notchprompt"
        panel.canCreateDirectories = true

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.saveScript(script, to: url)
        }
    }

    private func saveScript(_ script: Script, to url: URL) {
        do {
            let data = try JSONEncoder().encode(script)
            try data.write(to: url, options: .atomic)
        } catch {
            showAlert("Failed to save file", detail: error.localizedDescription)
        }
    }

    private func openNotchPromptFile(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            var script = try JSONDecoder().decode(Script.self, from: data)
            script = Script(id: UUID(), title: script.title, pages: script.pages)
            DispatchQueue.main.async {
                self.create(script)
            }
        } catch {
            showAlert("Failed to open file", detail: error.localizedDescription)
        }
    }

    // MARK: - PPTX Import

    func importPPTX(from url: URL) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let notes = try PresentationNotesExtractor.extractNotes(from: url)
                let title = url.deletingPathExtension().lastPathComponent
                let script = Script(title: title, pages: notes)
                DispatchQueue.main.async {
                    self?.create(script)
                }
            } catch {
                DispatchQueue.main.async {
                    self?.showAlert("Import Error", detail: error.localizedDescription)
                }
            }
        }
    }

    private func showAlert(_ message: String, detail: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = message
            alert.informativeText = detail
            alert.runModal()
        }
    }
}

// MARK: - PPTX Notes Extractor (ported from Textream)

enum PresentationNotesExtractor {
    enum ExtractionError: LocalizedError {
        case unsupportedFormat
        case extractionFailed(String)
        case noNotesFound

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat:
                return "Unsupported file format. Please drop a .pptx file."
            case .extractionFailed(let detail):
                return "Failed to extract notes: \(detail)"
            case .noNotesFound:
                return "No presenter notes found in this presentation."
            }
        }
    }

    static func extractNotes(from url: URL) throws -> [String] {
        let ext = url.pathExtension.lowercased()
        guard ext == "pptx" else { throw ExtractionError.unsupportedFormat }
        return try extractPPTXNotes(from: url)
    }

    private static func extractPPTXNotes(from url: URL) throws -> [String] {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", "-q", url.path, "-d", tempDir.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ExtractionError.extractionFailed("Could not unzip PPTX file.")
        }

        let notesDir = tempDir.appendingPathComponent("ppt/notesSlides")
        guard fileManager.fileExists(atPath: notesDir.path) else {
            throw ExtractionError.noNotesFound
        }

        let noteFiles = try fileManager.contentsOfDirectory(at: notesDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "xml" && $0.lastPathComponent.hasPrefix("notesSlide") }
            .sorted { f1, f2 in
                let n1 = f1.lastPathComponent.filter { $0.isNumber }.compactMap { Int(String($0)) }.reduce(0) { $0 * 10 + $1 }
                let n2 = f2.lastPathComponent.filter { $0.isNumber }.compactMap { Int(String($0)) }.reduce(0) { $0 * 10 + $1 }
                return n1 < n2
            }

        var pages: [String] = []
        for noteFile in noteFiles {
            let data = try Data(contentsOf: noteFile)
            let text = parsePPTXNoteXML(data: data)
            pages.append(text)
        }

        pages = pages.compactMap { page in
            let trimmed = page.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty && Int(trimmed) == nil else { return nil }
            return trimmed
        }

        guard !pages.isEmpty else { throw ExtractionError.noNotesFound }
        return pages
    }

    private static func parsePPTXNoteXML(data: Data) -> String {
        let parser = PPTXNoteXMLParser(data: data)
        return parser.parse()
    }
}

private class PPTXNoteXMLParser: NSObject, XMLParserDelegate {
    private let data: Data
    private var paragraphs: [String] = []
    private var currentParagraph = ""
    private var currentText = ""
    private var insideBody = false
    private var insideTextRun = false
    private var insideParagraph = false
    private var skipPlaceholder = false

    init(data: Data) { self.data = data }

    func parse() -> String {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return paragraphs.joined(separator: "\n")
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String]) {
        if elementName.hasSuffix(":sp") || elementName == "sp" { skipPlaceholder = false }
        if elementName.hasSuffix(":ph") || elementName == "ph" {
            let type = attributes["type"] ?? ""
            if ["sldNum", "sldImg", "dt", "hdr", "ftr"].contains(type) { skipPlaceholder = true }
        }
        if elementName.hasSuffix(":txBody") || elementName == "txBody" { insideBody = true }
        if (elementName.hasSuffix(":p") || elementName == "p") && insideBody && !skipPlaceholder {
            insideParagraph = true; currentParagraph = ""
        }
        if (elementName.hasSuffix(":t") || elementName == "t") && insideParagraph {
            insideTextRun = true; currentText = ""
        }
        if (elementName.hasSuffix(":br") || elementName == "br") && insideParagraph {
            currentParagraph += "\n"
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if insideTextRun { currentText += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        if (elementName.hasSuffix(":t") || elementName == "t") && insideTextRun {
            insideTextRun = false; currentParagraph += currentText
        }
        if (elementName.hasSuffix(":p") || elementName == "p") && insideParagraph {
            insideParagraph = false; paragraphs.append(currentParagraph)
        }
        if elementName.hasSuffix(":txBody") || elementName == "txBody" { insideBody = false }
        if elementName.hasSuffix(":sp") || elementName == "sp" { skipPlaceholder = false }
    }
}
