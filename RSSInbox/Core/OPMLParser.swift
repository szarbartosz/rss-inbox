import Foundation

struct OPMLFeed {
    let title: String
    let url: String
}

enum OPMLParserError: Error {
    case invalidXML
}

struct OPMLParser {
    func parse(data: Data) throws -> [OPMLFeed] {
        let delegate = OPMLParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse(), !delegate.parseError else {
            throw OPMLParserError.invalidXML
        }
        guard delegate.sawOpml else {
            throw OPMLParserError.invalidXML
        }
        return delegate.feeds
    }

    func generate(feeds: [OPMLFeed]) -> Data {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
          <head><title>RSS Inbox Feeds</title></head>
          <body>
        """
        for feed in feeds {
            let title = feed.title.xmlEscaped
            let url = feed.url.xmlEscaped
            xml += "\n    <outline text=\"\(title)\" type=\"rss\" xmlUrl=\"\(url)\"/>"
        }
        xml += "\n  </body>\n</opml>"
        return Data(xml.utf8)
    }
}

private final class OPMLParserDelegate: NSObject, XMLParserDelegate {
    var feeds: [OPMLFeed] = []
    var sawOpml = false
    var parseError = false

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String]) {
        let el = elementName.lowercased()
        if el == "opml" { sawOpml = true }
        if el == "outline", let url = attributes["xmlUrl"], !url.isEmpty {
            let title = attributes["text"] ?? attributes["title"] ?? url
            feeds.append(OPMLFeed(title: title, url: url))
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred error: Error) {
        parseError = true
    }
}

private extension String {
    var xmlEscaped: String {
        self.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
