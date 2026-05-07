import Testing
import SwiftData
@testable import RSSBox

@Suite("Models")
struct ModelTests {
    @Test func containerInitialises() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Feed.self, Article.self, configurations: config)
        let context = ModelContext(container)
        let feed = Feed(url: "https://example.com/rss", title: "Test")
        context.insert(feed)
        try context.save()
        let feeds = try context.fetch(FetchDescriptor<Feed>())
        #expect(feeds.count == 1)
        #expect(feeds[0].title == "Test")
    }

    @Test func cascadeDeleteRemovesArticles() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Feed.self, Article.self, configurations: config)
        let context = ModelContext(container)
        let feed = Feed(url: "https://example.com/rss", title: "Test")
        context.insert(feed)
        let article = Article(guid: "g1", title: "T", summary: "S", link: "https://example.com/1", pubDate: .now, feed: feed)
        context.insert(article)
        try context.save()
        context.delete(feed)
        try context.save()
        let articles = try context.fetch(FetchDescriptor<Article>())
        #expect(articles.isEmpty)
    }
}
