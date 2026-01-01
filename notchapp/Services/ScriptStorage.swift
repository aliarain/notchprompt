import Foundation
import Combine

final class ScriptStorage: ObservableObject {
    @Published private(set) var scripts: [Script] = []
    @Published var currentScript: Script?

    private let storageKey = "notchprompt.scripts"
    private let currentScriptKey = "notchprompt.currentScriptId"

    init() {
        load()
    }

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
            let defaultScript = Script(title: "Welcome", content: "Welcome to NotchPrompt!\n\nPaste or type your script here.\n\nThis text will scroll smoothly while you present.")
            scripts.append(defaultScript)
            currentScript = defaultScript
            save()
        } else if currentScript == nil {
            currentScript = scripts.first
        }
    }

    func save() {
        if let encoded = try? JSONEncoder().encode(scripts) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
        if let current = currentScript {
            UserDefaults.standard.set(current.id.uuidString, forKey: currentScriptKey)
        }
    }

    func create(_ script: Script) {
        scripts.append(script)
        currentScript = script
        save()
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
        save()
    }

    func select(_ script: Script) {
        currentScript = script
        save()
    }
}
