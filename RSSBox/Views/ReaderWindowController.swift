import AppKit
import SwiftUI
import SwiftData

final class ReaderWindowController: NSWindowController {
    static let shared = ReaderWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "RSS Inbox — Reader"
        window.setFrameAutosaveName("ReaderWindow")
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError() }

    func show(article: Article) {
        let delegate = NSApp.delegate as! AppDelegate
        let view = ReaderView(selectedArticle: article)
            .modelContainer(delegate.modelContainer)
            .environment(delegate.badgeController)
        window?.contentView = NSHostingView(rootView: view)
        showWindow(nil)
        window?.orderFrontRegardless()
    }
}
