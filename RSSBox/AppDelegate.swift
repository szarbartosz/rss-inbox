import AppKit
import SwiftUI
import SwiftData

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: NSPanel!
    private var eventMonitor: Any?
    let badgeController = BadgeController()
    let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: Feed.self, Article.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
    private(set) lazy var feedPoller: FeedPoller = FeedPoller(
        modelContainer: modelContainer,
        badgeController: badgeController
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = badgeController.statusImage
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        let content = PopoverView()
            .modelContainer(modelContainer)
            .environment(badgeController)
            .environment(feedPoller)
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 480)

        let effectView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 320, height: 480))
        effectView.material = .popover
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 10
        effectView.layer?.masksToBounds = true
        effectView.addSubview(hostingView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: effectView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
        ])

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 480),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = effectView
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovable = false

        ReaderWindowController.shared.modelContainer = modelContainer
        ReaderWindowController.shared.badgeController = badgeController

        let intervalMinutes = UserDefaults.standard.integer(forKey: "pollIntervalMinutes")
        feedPoller.start(intervalMinutes: intervalMinutes > 0 ? intervalMinutes : 15)

        Task { @MainActor [weak self] in
            guard let self else { return }
            while true {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    withObservationTracking {
                        _ = self.badgeController.hasUnread
                    } onChange: {
                        continuation.resume()
                    }
                }
                self.statusItem.button?.image = self.badgeController.statusImage
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        feedPoller.stop()
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        if panel.isVisible {
            closePanel()
        } else {
            openPanel()
        }
    }

    private func openPanel() {
        guard let button = statusItem.button,
              let buttonWindow = button.window,
              let screen = buttonWindow.screen else { return }

        let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let panelWidth: CGFloat = 320
        let panelHeight: CGFloat = 480
        var x = buttonFrame.minX
        let y = buttonFrame.minY - panelHeight - 6
        x = max(screen.visibleFrame.minX + 4, min(x, screen.visibleFrame.maxX - panelWidth - 4))

        panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        panel.makeKeyAndOrderFront(nil)

        let context = ModelContext(modelContainer)
        try? badgeController.update(context: context)
        button.image = badgeController.statusImage

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePanel()
        }
    }

    private func closePanel() {
        panel.orderOut(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
