import Testing
import Foundation
@testable import RSSBox

private func fixture(_ name: String) -> Data {
    let bundle = Bundle(for: FeedParserTestsHelper.self)
    // Try with Fixtures subdirectory first (folder reference), then fall back to flat bundle root
    let url = bundle.url(forResource: name, withExtension: nil, subdirectory: "Fixtures")
        ?? bundle.url(forResource: name, withExtension: nil)!
    return try! Data(contentsOf: url)
}

// Helper class to get the test bundle (needed for Bundle lookup)
private final class FeedParserTestsHelper {}

@Suite("FeedParser")
struct FeedParserTests {
    @Test func parsesRSS2Title() throws {
        let result = try FeedParser().parse(data: fixture("rss2.xml"))
        #expect(result.title == "Test RSS Feed")
    }

    @Test func parsesRSS2Items() throws {
        let result = try FeedParser().parse(data: fixture("rss2.xml"))
        #expect(result.items.count == 2)
        #expect(result.items[0].title == "First Article")
        #expect(result.items[0].guid == "https://example.com/1")
        #expect(result.items[0].summary == "First article summary")
        #expect(result.items[0].link == "https://example.com/1")
        #expect(result.items[1].guid == "unique-guid-2")
    }

    @Test func parsesAtomTitle() throws {
        let result = try FeedParser().parse(data: fixture("atom.xml"))
        #expect(result.title == "Test Atom Feed")
    }

    @Test func parsesAtomEntries() throws {
        let result = try FeedParser().parse(data: fixture("atom.xml"))
        #expect(result.items.count == 2)
        #expect(result.items[0].title == "Atom Article One")
        #expect(result.items[0].guid == "https://example.com/atom/1")
        #expect(result.items[0].summary == "Summary of atom article one")
        #expect(result.items[0].link == "https://example.com/atom/1")
    }

    @Test func atomUsesContentWhenNoSummary() throws {
        let result = try FeedParser().parse(data: fixture("atom.xml"))
        #expect(result.items[1].summary == "Content of atom article two")
    }

    @Test func fallsBackToLinkWhenNoGuid() throws {
        let result = try FeedParser().parse(data: fixture("rss2-no-guid.xml"))
        #expect(result.items[0].guid == "https://example.com/noguid")
    }

    @Test func throwsOnMalformedXML() {
        #expect(throws: FeedParserError.self) {
            try FeedParser().parse(data: fixture("malformed.xml"))
        }
    }
}
