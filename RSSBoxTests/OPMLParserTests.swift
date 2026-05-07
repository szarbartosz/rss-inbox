import Testing
import Foundation
import SwiftData
@testable import RSSBox

private func fixture(_ name: String) -> Data {
    let bundle = Bundle(for: OPMLParserTestsHelper.self)
    if let url = bundle.url(forResource: name, withExtension: nil, subdirectory: "Fixtures") {
        return try! Data(contentsOf: url)
    }
    let url = bundle.url(forResource: name, withExtension: nil)!
    return try! Data(contentsOf: url)
}

private final class OPMLParserTestsHelper {}

@Suite("OPMLParser")
struct OPMLParserTests {
    @Test func parsesTopLevelFeeds() throws {
        let feeds = try OPMLParser().parse(data: fixture("sample.opml"))
        #expect(feeds.count == 3)
    }

    @Test func parsesFeedTitlesAndURLs() throws {
        let feeds = try OPMLParser().parse(data: fixture("sample.opml"))
        #expect(feeds[0].title == "TechCrunch")
        #expect(feeds[0].url == "https://techcrunch.com/feed/")
        #expect(feeds[1].title == "The Verge")
    }

    @Test func parsesNestedOutlines() throws {
        let feeds = try OPMLParser().parse(data: fixture("sample.opml"))
        let hn = feeds.first { $0.title == "Hacker News" }
        #expect(hn != nil)
        #expect(hn?.url == "https://news.ycombinator.com/rss")
    }

    @Test func throwsOnInvalidOPML() {
        #expect(throws: OPMLParserError.self) {
            try OPMLParser().parse(data: fixture("invalid.opml"))
        }
    }

    @Test func generatesValidOPML() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Feed.self, Article.self, configurations: config)
        let context = ModelContext(container)
        let feed1 = Feed(url: "https://example.com/rss", title: "Example")
        let feed2 = Feed(url: "https://other.com/feed", title: "Other")
        context.insert(feed1)
        context.insert(feed2)
        let data = OPMLParser().generate(feeds: [feed1, feed2])
        let reparsed = try OPMLParser().parse(data: data)
        #expect(reparsed.count == 2)
        #expect(reparsed[0].url == "https://example.com/rss")
    }
}
