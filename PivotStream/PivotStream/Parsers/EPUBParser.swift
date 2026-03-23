import Foundation

enum EPUBError: Error {
    case missingContainer
    case missingOPF
    case invalidOPF
    case noContent
}

struct EPUBResult {
    let text: String
    let chapters: [Chapter]
}

struct EPUBParser {

    nonisolated static func parse(url: URL) throws -> EPUBResult {
        let zip = try ZipReader(url: url)
        let entries = try zip.readAll()

        // 1. Find OPF path from META-INF/container.xml
        guard let containerData = entries["META-INF/container.xml"] else {
            throw EPUBError.missingContainer
        }
        let opfPath = try parseContainerXML(containerData)

        // 2. Parse OPF
        guard let opfData = entries[opfPath] else {
            throw EPUBError.missingOPF
        }
        let opfDir = opfPath.contains("/") ? String(opfPath.prefix(upTo: opfPath.lastIndex(of: "/")!)) + "/" : ""
        let opf = try parseOPF(opfData, baseDir: opfDir)

        // 3. Get TOC
        var tocItems: [TOCItem] = []
        if let tocHref = opf.navHref, let navData = entries[opfDir + tocHref] ?? entries[tocHref] {
            tocItems = parseEPUB3Nav(navData)
        } else if let ncxHref = opf.ncxHref, let ncxData = entries[opfDir + ncxHref] ?? entries[ncxHref] {
            tocItems = parseNCX(ncxData)
        }

        // 4. Extract text in spine order, track chapter positions
        var fullText = ""
        var chapters: [Chapter] = []
        var tokenCount = 0

        for spineItem in opf.spine {
            guard let href = opf.manifest[spineItem] else { continue }
            let fullHref = opfDir + href
            guard let htmlData = entries[fullHref] ?? entries[href] else { continue }
            let htmlString = String(data: htmlData, encoding: .utf8) ?? ""
            let chapterText = htmlToText(htmlString)
            guard !chapterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

            // Find matching TOC item for this href
            let hrefBase = href.components(separatedBy: "#").first ?? href
            let matchingToc = tocItems.first { item in
                let itemBase = item.href.components(separatedBy: "#").first ?? item.href
                return itemBase == hrefBase || itemBase == fullHref
            }
            if let toc = matchingToc {
                chapters.append(Chapter(title: toc.title, startIndex: tokenCount, level: toc.level))
            }

            // Count tokens in this chunk
            let words = chapterText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            let tokens = words.compactMap { TextParser.splitToken($0) }
            tokenCount += tokens.count

            if !fullText.isEmpty { fullText += "\n\n" }
            fullText += chapterText
        }

        if fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw EPUBError.noContent
        }

        return EPUBResult(text: TextParser.normalize(fullText), chapters: chapters)
    }

    // MARK: - Container XML

    private struct TOCItem {
        let title: String
        let href: String
        let level: Int
    }

    private struct OPFData {
        let manifest: [String: String]  // id -> href
        let spine: [String]             // idref order
        let ncxHref: String?
        let navHref: String?
    }

    nonisolated private static func parseContainerXML(_ data: Data) throws -> String {
        let parser = SimpleXMLParser(data: data)
        parser.parse()
        // Look for rootfile element's full-path attribute
        for el in parser.elements {
            if el.name == "rootfile", let path = el.attributes["full-path"] {
                return path
            }
        }
        throw EPUBError.missingContainer
    }

    nonisolated private static func parseOPF(_ data: Data, baseDir: String) throws -> OPFData {
        let parser = SimpleXMLParser(data: data)
        parser.parse()

        var manifest: [String: String] = [:]
        var spine: [String] = []
        var tocId: String? = nil
        var ncxHref: String? = nil
        var navHref: String? = nil

        for el in parser.elements {
            switch el.name {
            case "item":
                if let id = el.attributes["id"], let href = el.attributes["href"] {
                    manifest[id] = href
                    let mediaType = el.attributes["media-type"] ?? ""
                    let properties = el.attributes["properties"] ?? ""
                    if mediaType == "application/x-dtbncx+xml" {
                        ncxHref = href
                    }
                    if properties.contains("nav") {
                        navHref = href
                    }
                }
            case "spine":
                tocId = el.attributes["toc"]
            case "itemref":
                if let idref = el.attributes["idref"] {
                    spine.append(idref)
                }
            default:
                break
            }
        }

        if ncxHref == nil, let tid = tocId, let href = manifest[tid] {
            ncxHref = href
        }

        return OPFData(manifest: manifest, spine: spine, ncxHref: ncxHref, navHref: navHref)
    }

    nonisolated private static func parseEPUB3Nav(_ data: Data) -> [TOCItem] {
        let html = String(data: data, encoding: .utf8) ?? ""
        var items: [TOCItem] = []
        parseNavOL(html: html, level: 0, items: &items)
        return items
    }

    nonisolated private static func parseNavOL(html: String, level: Int, items: inout [TOCItem]) {
        // Extract <a href="...">Title</a> pairs from nav list items
        let pattern = "<a[^>]+href=\"([^\"]*(?:#[^\"]*)??)\"[^>]*>(.*?)</a>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return }
        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)

        for match in matches {
            if let hrefRange = Range(match.range(at: 1), in: html),
               let titleRange = Range(match.range(at: 2), in: html) {
                let href = String(html[hrefRange])
                let rawTitle = String(html[titleRange])
                let title = stripTags(rawTitle).trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty {
                    items.append(TOCItem(title: title, href: href, level: level))
                }
            }
        }
    }

    nonisolated private static func parseNCX(_ data: Data) -> [TOCItem] {
        let parser = SimpleXMLParser(data: data)
        parser.parse()

        var items: [TOCItem] = []
        var depth = 0
        var inNavPoint = false
        var currentTitle = ""
        var currentHref = ""
        var depthStack: [Int] = []

        for el in parser.elements {
            switch el.name {
            case "navPoint":
                depth = (depthStack.last ?? -1) + 1
                depthStack.append(depth)
                inNavPoint = true
                currentTitle = ""
                currentHref = ""
            case "navPoint_end":
                if inNavPoint && !currentTitle.isEmpty {
                    items.append(TOCItem(title: currentTitle, href: currentHref, level: depth))
                }
                depthStack.removeLast()
                depth = depthStack.last ?? 0
                inNavPoint = false
            case "text":
                if inNavPoint && currentTitle.isEmpty {
                    currentTitle = el.text ?? ""
                }
            case "content":
                if let src = el.attributes["src"] {
                    currentHref = src
                }
            default:
                break
            }
        }
        return items
    }

    // MARK: - HTML to text

    nonisolated static func htmlToText(_ html: String) -> String {
        var text = html

        // Remove script and style blocks
        text = removeBlocks(text, tag: "script")
        text = removeBlocks(text, tag: "style")

        // Block elements → newlines
        for tag in ["</p>", "</div>", "</br>", "<br>", "<br/>", "<br />", "</h1>", "</h2>",
                    "</h3>", "</h4>", "</h5>", "</h6>", "</li>", "</tr>"] {
            text = text.replacingOccurrences(of: tag, with: "\n", options: .caseInsensitive)
        }

        // Strip all remaining tags
        text = stripTags(text)

        // Unescape HTML entities
        text = unescapeHTML(text)

        // Normalize whitespace
        return TextParser.normalize(text)
    }

    nonisolated private static func removeBlocks(_ html: String, tag: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: "<\(tag)[^>]*>[\\s\\S]*?</\(tag)>",
            options: [.caseInsensitive]
        ) else { return html }
        let range = NSRange(html.startIndex..., in: html)
        return regex.stringByReplacingMatches(in: html, range: range, withTemplate: "")
    }

    nonisolated private static func stripTags(_ html: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "<[^>]+>") else { return html }
        let range = NSRange(html.startIndex..., in: html)
        return regex.stringByReplacingMatches(in: html, range: range, withTemplate: "")
    }

    nonisolated private static func unescapeHTML(_ text: String) -> String {
        let entities: [(String, String)] = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"),
            ("&nbsp;", " "), ("&mdash;", "—"), ("&ndash;", "–"),
            ("&lsquo;", "\u{2018}"), ("&rsquo;", "\u{2019}"),
            ("&ldquo;", "\u{201C}"), ("&rdquo;", "\u{201D}"),
        ]
        var result = text
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        // Numeric entities like &#160; or &#x00A0;
        if let regex = try? NSRegularExpression(pattern: "&#(x?)([0-9a-fA-F]+);") {
            let nsString = result as NSString
            let range = NSRange(location: 0, length: nsString.length)
            let matches = regex.matches(in: result, range: range)
            var output = result
            for match in matches.reversed() {
                guard let fullRange = Range(match.range, in: output) else { continue }
                let isHexRange = Range(match.range(at: 1), in: output)
                let numRange = Range(match.range(at: 2), in: output)
                guard let numRange else { continue }
                let isHex = isHexRange.map { !output[$0].isEmpty } ?? false
                let numStr = String(output[numRange])
                let codePoint = UInt32(numStr, radix: isHex ? 16 : 10) ?? 0
                if let scalar = Unicode.Scalar(codePoint) {
                    output.replaceSubrange(fullRange, with: String(scalar))
                }
            }
            result = output
        }
        return result
    }
}

// MARK: - Simple SAX XML Parser

final class SimpleXMLParser: NSObject, XMLParserDelegate {
    struct Element {
        let name: String
        let attributes: [String: String]
        var text: String?
    }

    private(set) var elements: [Element] = []
    private var currentText = ""
    private var elementStack: [Element] = []
    private let data: Data

    init(data: Data) {
        self.data = data
    }

    func parse() {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        currentText = ""
        let el = Element(name: elementName.lowercased(), attributes: attributeDict)
        elementStack.append(el)
        elements.append(el)
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let name = elementName.lowercased()
        if !elementStack.isEmpty {
            var el = elementStack.removeLast()
            el = Element(name: el.name, attributes: el.attributes, text: currentText.trimmingCharacters(in: .whitespacesAndNewlines))
            elements.append(Element(name: "\(name)_end", attributes: [:], text: el.text))
        }
        // Also update last matching element's text
        if let idx = elements.lastIndex(where: { $0.name == name && $0.text == nil }) {
            let existing = elements[idx]
            elements[idx] = Element(name: existing.name, attributes: existing.attributes,
                                    text: currentText.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        currentText = ""
    }
}
