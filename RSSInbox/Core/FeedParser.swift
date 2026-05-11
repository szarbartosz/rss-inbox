import Foundation

struct ParsedItem {
    let guid: String
    let title: String
    let summary: String
    let link: String
    let pubDate: Date
}

struct ParsedFeed {
    let title: String
    let items: [ParsedItem]
}

enum FeedParserError: Error {
    case invalidXML
}

final class FeedParser {
    func parse(data: Data) throws -> ParsedFeed {
        let delegate = ParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse(), !delegate.parseError else {
            throw FeedParserError.invalidXML
        }
        return ParsedFeed(title: delegate.feedTitle, items: delegate.items)
    }
}

private final class ParserDelegate: NSObject, XMLParserDelegate {
    var feedTitle = ""
    var items: [ParsedItem] = []
    var parseError = false

    private var isAtom = false
    private var inEntry = false
    private var inItem = false
    private var currentText = ""
    private var currentGuid = ""
    private var currentTitle = ""
    private var currentSummary = ""
    private var currentContent = ""
    private var currentLink = ""
    private var currentPubDate: Date?

    private static let rfc2822: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return f
    }()

    private static let iso8601: ISO8601DateFormatter = ISO8601DateFormatter()

    private func parseDate(_ s: String) -> Date? {
        ParserDelegate.rfc2822.date(from: s.trimmingCharacters(in: .whitespaces))
            ?? ParserDelegate.iso8601.date(from: s.trimmingCharacters(in: .whitespaces))
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String]) {
        currentText = ""
        let el = elementName.lowercased()
        if el == "feed" { isAtom = true }
        if el == "entry" { inEntry = true; resetCurrentItem() }
        if el == "item" { inItem = true; resetCurrentItem() }
        if isAtom && el == "link", let href = attributes["href"], !href.isEmpty {
            if inEntry { currentLink = href }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        let el = elementName.lowercased()
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if inEntry || inItem {
            switch el {
            case "title": currentTitle = text
            case "guid", "id": currentGuid = text
            case "description", "summary": currentSummary = text
            case "content", "content:encoded": currentContent = text
            case "link" where !isAtom: currentLink = text
            case "pubdate", "published", "updated":
                if currentPubDate == nil { currentPubDate = parseDate(text) }
            case "entry", "item":
                let guid = currentGuid.isEmpty ? currentLink : currentGuid
                let summary = currentSummary.isEmpty ? currentContent : currentSummary
                items.append(ParsedItem(
                    guid: guid,
                    title: currentTitle,
                    summary: summary,
                    link: currentLink,
                    pubDate: currentPubDate ?? Date.distantPast
                ))
                inEntry = false; inItem = false
            default: break
            }
        } else if el == "title" && feedTitle.isEmpty {
            feedTitle = text
        }
        currentText = ""
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = true
    }

    private func resetCurrentItem() {
        currentGuid = ""; currentTitle = ""; currentSummary = ""
        currentContent = ""; currentLink = ""; currentPubDate = nil
    }
}
