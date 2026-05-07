import AppKit

final class ReaderWindowController: NSWindowController {
    static let shared = ReaderWindowController()

    private init() {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: true
        )
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError() }

    func show(article: Article) {
        showWindow(nil)
    }
}
