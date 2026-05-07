import Testing
import Foundation
@testable import RSSBox

private func fixture(_ name: String) -> Data {
    let bundle = Bundle(for: OPMLParserTestsHelper.self)
    guard let url = bundle.url(forResource: name, withExtension: nil, subdirectory: "Fixtures")
                   ?? bundle.url(forResource: name, withExtension: nil),
          let data = try? Data(contentsOf: url) else {
        fatalError("Missing test fixture: \(name) — check it is listed in Copy Bundle Resources")
    }
    return data
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
        let feeds = [
            OPMLFeed(title: "Example", url: "https://example.com/rss"),
            OPMLFeed(title: "Other", url: "https://other.com/feed"),
        ]
        let data = OPMLParser().generate(feeds: feeds)
        let reparsed = try OPMLParser().parse(data: data)
        #expect(reparsed.count == 2)
        #expect(reparsed[0].url == "https://example.com/rss")
        #expect(reparsed[0].title == "Example")
        #expect(reparsed[1].url == "https://other.com/feed")
    }
}
