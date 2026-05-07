import Foundation
import SwiftData

@Model
final class Feed {
    var id: UUID
    var url: String
    var title: String
    var faviconData: Data?
    var lastFetched: Date?
    var fetchError: String?
    @Relationship(deleteRule: .cascade) var articles: [Article] = []

    init(url: String, title: String) {
        self.id = UUID()
        self.url = url
        self.title = title
    }
}
