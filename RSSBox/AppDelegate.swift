import AppKit
import SwiftUI
import SwiftData

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
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

        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 480)
        popover.behavior = .transient
        let popoverContent = PopoverView()
            .modelContainer(modelContainer)
            .environment(badgeController)
            .environment(feedPoller)
        popover.contentViewController = NSHostingController(rootView: popoverContent)

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
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
        let context = ModelContext(modelContainer)
        try? badgeController.update(context: context)
        button.image = badgeController.statusImage
    }
}
