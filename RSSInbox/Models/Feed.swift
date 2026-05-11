import Foundation
import SwiftData

@Model
final class Feed {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var url: String
    var title: String
    var faviconData: Data?
    var lastFetched: Date?
    var fetchError: String?
    @Relationship(deleteRule: .cascade) var articles: [Article] = []

    init(url: String, title: String) {
        self.id = UUID()
        self.url = url
        self.title = title
        // Register in the live-wrapper set so FeedPoller can propagate
        // property updates to this instance from any context.
        Feed._liveWrappers.add(self)
    }

    // Global weak registry of all Feed instances created via init(url:title:).
    // Fetched instances do not go through this init, so they are absent from
    // this set. Access only from @MainActor.
    nonisolated(unsafe) static let _liveWrappers: NSHashTable<Feed> = .weakObjects()
}
