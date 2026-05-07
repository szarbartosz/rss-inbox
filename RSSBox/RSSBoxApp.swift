import SwiftUI

@main
struct RSSBoxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            PreferencesView()
                .modelContainer(appDelegate.modelContainer)
                .environment(appDelegate.feedPoller)
        }
    }
}
