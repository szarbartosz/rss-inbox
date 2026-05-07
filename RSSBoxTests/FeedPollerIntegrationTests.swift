import Testing
import SwiftData
import Foundation
@testable import RSSBox

// URLProtocol stub for intercepting network requests in tests
final class MockURLProtocol: URLProtocol {
    static var handlers: [String: Data] = [:]

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url?.absoluteString,
              let data = MockURLProtocol.handlers[url] else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let response = HTTPURLResponse(
            url: request.url!, statusCode: 200,
            httpVersion: nil, headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func fixture(_ name: String) -> Data {
    let bundle = Bundle(for: MockURLProtocol.self)
    guard let url = bundle.url(forResource: name, withExtension: nil, subdirectory: "Fixtures")
                   ?? bundle.url(forResource: name, withExtension: nil),
          let data = try? Data(contentsOf: url) else {
        fatalError("Missing test fixture: \(name)")
    }
    return data
}

@Suite("FeedPoller Integration")
@MainActor
struct FeedPollerIntegrationTests {
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Feed.self, Article.self, configurations: config)
    }

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    @Test func pollInsertsNewArticles() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let feed = Feed(url: "https://example.com/rss", title: "")
        context.insert(feed)
        try context.save()

        MockURLProtocol.handlers["https://example.com/rss"] = fixture("rss2.xml")

        let badgeController = BadgeController()
        let poller = FeedPoller(
            modelContainer: container,
            badgeController: badgeController,
            urlSession: makeSession()
        )
        await poller.pollAllFeeds()

        let articles = try context.fetch(FetchDescriptor<Article>())
        #expect(articles.count == 2)
        #expect(feed.lastFetched != nil)
        #expect(feed.fetchError == nil)
        #expect(badgeController.hasUnread)
    }

    @Test func pollDeduplicatesOnRepeat() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let feed = Feed(url: "https://example.com/rss", title: "")
        context.insert(feed)
        try context.save()

        MockURLProtocol.handlers["https://example.com/rss"] = fixture("rss2.xml")
        let badgeController = BadgeController()
        let poller = FeedPoller(
            modelContainer: container,
            badgeController: badgeController,
            urlSession: makeSession()
        )

        await poller.pollAllFeeds()
        await poller.pollAllFeeds()

        let articles = try context.fetch(FetchDescriptor<Article>())
        #expect(articles.count == 2)
    }

    @Test func pollSetsErrorOnNetworkFailure() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let feed = Feed(url: "https://example.com/bad", title: "Bad Feed")
        context.insert(feed)
        try context.save()

        // No handler registered → MockURLProtocol returns badServerResponse
        let badgeController = BadgeController()
        let poller = FeedPoller(
            modelContainer: container,
            badgeController: badgeController,
            urlSession: makeSession()
        )
        await poller.pollAllFeeds()

        #expect(feed.fetchError != nil)
        #expect(feed.lastFetched == nil)
    }

    @Test func pollUpdatesFeedTitle() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let feed = Feed(url: "https://example.com/rss", title: "")
        context.insert(feed)
        try context.save()

        MockURLProtocol.handlers["https://example.com/rss"] = fixture("rss2.xml")
        let badgeController = BadgeController()
        let poller = FeedPoller(
            modelContainer: container,
            badgeController: badgeController,
            urlSession: makeSession()
        )
        await poller.pollAllFeeds()

        #expect(feed.title == "Test RSS Feed")
    }
}
