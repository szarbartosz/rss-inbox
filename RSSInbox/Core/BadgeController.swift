import AppKit
import SwiftData

@Observable
final class BadgeController {
    var hasUnread: Bool = false

    @MainActor
    private static func emojiImage(_ emoji: String) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else {
                return false
            }
            let font = NSFont.systemFont(ofSize: 14)
            let attrs: [NSAttributedString.Key: Any] = [.font: font]
            let str = NSAttributedString(string: emoji, attributes: attrs)
            let line = CTLineCreateWithAttributedString(str)
            let ink = CTLineGetImageBounds(line, ctx)
            ctx.textPosition = CGPoint(
                x: (rect.width - ink.width) / 2 - ink.minX,
                y: (rect.height - ink.height) / 2 - ink.minY
            )
            CTLineDraw(line, ctx)
            return true
        }
        image.isTemplate = false
        return image
    }

    @MainActor private static let emptyMailbox = emojiImage("📭")
    @MainActor private static let fullMailbox  = emojiImage("📬")

    @MainActor var statusImage: NSImage {
        hasUnread ? BadgeController.fullMailbox : BadgeController.emptyMailbox
    }

    @MainActor func update(context: ModelContext) throws {
        let descriptor = FetchDescriptor<Article>(
            predicate: #Predicate { !$0.isRead }
        )
        let count = try context.fetchCount(descriptor)
        hasUnread = count > 0
    }
}
