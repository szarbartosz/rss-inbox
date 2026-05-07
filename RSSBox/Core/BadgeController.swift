import AppKit
import SwiftData
import Observation

@Observable
final class BadgeController {
    var hasUnread: Bool = false

    private static func emojiImage(_ emoji: String) -> NSImage {
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size, flipped: false) { rect in
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 16)
            ]
            let str = NSAttributedString(string: emoji, attributes: attrs)
            let strSize = str.size()
            let origin = NSPoint(x: (rect.width - strSize.width) / 2,
                                 y: (rect.height - strSize.height) / 2)
            str.draw(at: origin)
            return true
        }
        image.isTemplate = false
        return image
    }

    static let emptyMailbox = emojiImage("📪")
    static let fullMailbox  = emojiImage("📫")

    var statusImage: NSImage {
        hasUnread ? BadgeController.fullMailbox : BadgeController.emptyMailbox
    }

    func update(context: ModelContext) throws {
        let descriptor = FetchDescriptor<Article>(
            predicate: #Predicate { !$0.isRead }
        )
        let count = try context.fetchCount(descriptor)
        hasUnread = count > 0
    }
}
