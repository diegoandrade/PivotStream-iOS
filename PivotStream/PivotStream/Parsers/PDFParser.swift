import Foundation
import PDFKit

enum PDFError: Error {
    case cannotOpen
    case noText
}

struct PDFResult {
    let text: String
    let pageCount: Int
    let chapters: [Chapter]
}

struct PDFParser {

    nonisolated static func parse(url: URL) throws -> PDFResult {
        guard let document = PDFDocument(url: url) else {
            throw PDFError.cannotOpen
        }

        let pageCount = document.pageCount
        var pages: [String] = []

        for i in 0..<pageCount {
            if let page = document.page(at: i), let pageText = page.string {
                pages.append(pageText)
            }
        }

        let rawText = pages.joined(separator: "\n")
        let text = TextParser.normalize(rawText)

        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw PDFError.noText
        }

        let chapters = detectSections(in: text)
        return PDFResult(text: text, pageCount: pageCount, chapters: chapters)
    }

    // MARK: - Section detection (matches Python _extract_pdf_sections exactly)

    nonisolated private static func detectSections(in text: String) -> [Chapter] {

        // Matches: "1", "1.2", "1.2.3" with optional separator [.)-:] and title
        guard let numericRx = try? NSRegularExpression(
            pattern: #"^(\d{1,3}(?:\.\d{1,3}){0,2})([.):\-])?\s*([A-Za-z].+)$"#
        ) else { return [] }

        // Roman numeral label (case-insensitive) followed by ". Title"
        guard let romanRx = try? NSRegularExpression(
            pattern: #"^([IVXLCDM]{1,10})\.\s+([A-Za-z].+)$"#,
            options: .caseInsensitive
        ) else { return [] }

        // Single letter label followed by separator and title
        guard let alphaRx = try? NSRegularExpression(
            pattern: #"^([A-Za-z])([.):\-])\s*([A-Za-z].+)$"#
        ) else { return [] }

        // Unit noise filter — applied to title portion of decimal numeric lines
        guard let unitNoise = try? NSRegularExpression(
            pattern: #"\b(?:kb|mb|gb|tb|pb|%|hz|khz|mhz|ghz|w|kw|mw|v|kv|a|ma|ms|s|sec|secs|min|mins|hr|hrs|kg|g|mg|cm|mm|m2|m\^2|m3|m\^3)\b"#,
            options: .caseInsensitive
        ) else { return [] }

        let maxMajor = 99
        let maxSub = 99

        var chapters: [Chapter] = []
        var seen: Set<String> = []
        var tokenIndex = 0

        for line in text.components(separatedBy: "\n") {
            let cleaned = normalizeSpace(line)
            guard !cleaned.isEmpty else { continue }

            let lineTokens = countTokens(cleaned)

            // --- Numeric ---
            let cleanedNSRange = NSRange(cleaned.startIndex..., in: cleaned)
            if let m = numericRx.firstMatch(in: cleaned, range: cleanedNSRange),
               let labelRange = Range(m.range(at: 1), in: cleaned),
               let titleRange = Range(m.range(at: 3), in: cleaned) {

                let label = String(cleaned[labelRange])
                let title = String(cleaned[titleRange]).trimmingCharacters(in: .whitespaces)
                let parts = label.split(separator: ".").map(String.init)
                var valid = true
                var numericParts: [Int] = []
                let hasDecimal = parts.count > 1

                for (idx, part) in parts.enumerated() {
                    // No leading zeros on multi-digit parts
                    if part.count > 1 && part.hasPrefix("0") { valid = false; break }
                    guard let value = Int(part), value > 0 else { valid = false; break }
                    if idx == 0 && value > maxMajor { valid = false; break }
                    if idx > 0 && value > maxSub { valid = false; break }
                    numericParts.append(value)
                }

                if valid && isProbableTitle(title) {
                    if hasDecimal {
                        let titleNS = NSRange(title.startIndex..., in: title)
                        if unitNoise.firstMatch(in: title, range: titleNS) != nil {
                            tokenIndex += lineTokens
                            continue
                        }
                    }
                    let normalizedLabel = numericParts.map(String.init).joined(separator: ".")
                    let fullTitle = "\(normalizedLabel) \(title)"
                    if !seen.contains(fullTitle) {
                        chapters.append(Chapter(title: fullTitle, startIndex: tokenIndex, level: 0))
                        seen.insert(fullTitle)
                    }
                }
                tokenIndex += lineTokens
                continue
            }

            // --- Roman numeral ---
            if let m = romanRx.firstMatch(in: cleaned, range: cleanedNSRange),
               let labelRange = Range(m.range(at: 1), in: cleaned),
               let titleRange = Range(m.range(at: 2), in: cleaned) {

                let roman = String(cleaned[labelRange]).uppercased()
                let title = String(cleaned[titleRange]).trimmingCharacters(in: .whitespaces)

                if isProbableTitle(title) {
                    let value = romanToInt(roman)
                    if value > 0 && value <= maxMajor {
                        let fullTitle = "\(roman) \(title)"
                        if !seen.contains(fullTitle) {
                            chapters.append(Chapter(title: fullTitle, startIndex: tokenIndex, level: 0))
                            seen.insert(fullTitle)
                        }
                    }
                }
                tokenIndex += lineTokens
                continue
            }

            // --- Alphabetic ---
            if let m = alphaRx.firstMatch(in: cleaned, range: cleanedNSRange),
               let labelRange = Range(m.range(at: 1), in: cleaned),
               let titleRange = Range(m.range(at: 3), in: cleaned) {

                let label = String(cleaned[labelRange]).uppercased()
                let title = String(cleaned[titleRange]).trimmingCharacters(in: .whitespaces)

                if isProbableTitle(title) {
                    let fullTitle = "\(label) \(title)"
                    if !seen.contains(fullTitle) {
                        chapters.append(Chapter(title: fullTitle, startIndex: tokenIndex, level: 0))
                        seen.insert(fullTitle)
                    }
                }
            }

            tokenIndex += lineTokens
        }

        return chapters
    }

    // MARK: - Helpers

    nonisolated private static func normalizeSpace(_ text: String) -> String {
        let components = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        return components.joined(separator: " ")
    }

    nonisolated private static func countTokens(_ text: String) -> Int {
        text.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .compactMap { TextParser.splitToken($0) }
            .count
    }

    nonisolated private static func isProbableTitle(_ title: String) -> Bool {
        guard !title.isEmpty else { return false }
        return title.contains(where: { $0.isLetter })
    }

    nonisolated private static func romanToInt(_ roman: String) -> Int {
        let map: [Character: Int] = [
            "I": 1, "V": 5, "X": 10, "L": 50,
            "C": 100, "D": 500, "M": 1000
        ]
        var total = 0
        var prev = 0
        for ch in roman.reversed() {
            let current = map[ch] ?? 0
            if current < prev {
                total -= current
            } else {
                total += current
                prev = current
            }
        }
        return total
    }
}
