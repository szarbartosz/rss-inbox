import Testing
import SwiftData
import AppKit
@testable import RSSBox

@Suite("BadgeController")
@MainActor
struct BadgeControllerTests {
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Feed.self, Article.self, configurations: config)
    }

    @Test func hasUnreadFalseWhenNoArticles() throws {
        let container = try makeContainer()
        let controller = BadgeController()
        let context = ModelContext(container)
        try controller.update(context: context)
        #expect(!controller.hasUnread)
    }

    @Test func hasUnreadTrueWhenUnreadArticleExists() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let feed = Feed(url: "https://example.com/rss", title: "Test")
        context.insert(feed)
        let article = Article(guid: "g1", title: "T", summary: "S", link: "https://example.com/1", pubDate: .now, feed: feed)
        context.insert(article)
        try context.save()

        let controller = BadgeController()
        try controller.update(context: context)
        #expect(controller.hasUnread)
    }

    @Test func hasUnreadFalseAfterMarkingRead() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let feed = Feed(url: "https://example.com/rss", title: "Test")
        context.insert(feed)
        let article = Article(guid: "g1", title: "T", summary: "S", link: "https://example.com/1", pubDate: .now, feed: feed)
        context.insert(article)
        try context.save()

        article.isRead = true
        try context.save()

        let controller = BadgeController()
        try controller.update(context: context)
        #expect(!controller.hasUnread)
    }

    @Test func statusImageChangesWithUnreadState() throws {
        let controller = BadgeController()
        let emptyImage = controller.statusImage
        controller.hasUnread = true
        let fullImage = controller.statusImage
        #expect(emptyImage !== fullImage)
    }
}
