import SwiftUI

@main
struct NotchPromptApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(scrollingController: appDelegate.scrollingController)
        }
    }
}
