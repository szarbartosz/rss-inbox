import Foundation
import SwiftData

@Model
final class Article {
    var id: UUID
    var guid: String
    var title: String
    var summary: String
    var link: String
    var pubDate: Date
    var isRead: Bool
    var feed: Feed?

    init(guid: String, title: String, summary: String, link: String, pubDate: Date, feed: Feed) {
        self.id = UUID()
        self.guid = guid
        self.title = title
        self.summary = summary
        self.link = link
        self.pubDate = pubDate
        self.isRead = false
        self.feed = feed
    }
}
