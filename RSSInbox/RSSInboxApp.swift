import SwiftUI

@main
struct RSSInboxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            PreferencesView()
                .modelContainer(appDelegate.modelContainer)
                .environment(appDelegate.feedPoller)
        }
    }
}
