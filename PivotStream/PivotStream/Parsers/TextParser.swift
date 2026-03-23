import Foundation

struct TextParser {

    nonisolated static func parse(_ text: String) -> [Token] {
        let normalized = normalize(text)
        return normalized
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .compactMap { splitToken($0) }
    }

    // MARK: - Normalization

    nonisolated static func normalize(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "\r\n", with: "\n")
        result = result.replacingOccurrences(of: "\r", with: "\n")
        // Collapse multiple newlines (3+) to two
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        // Collapse tabs/multiple spaces to single space
        let lines = result.components(separatedBy: "\n")
        let collapsed = lines.map { line -> String in
            let words = line.components(separatedBy: .init(charactersIn: " \t")).filter { !$0.isEmpty }
            return words.joined(separator: " ")
        }
        return collapsed.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Tokenization

    nonisolated static func splitToken(_ word: String) -> Token? {
        guard let firstIdx = word.firstIndex(where: { $0.isLetter || $0.isNumber }),
              let lastIdx = word.lastIndex(where: { $0.isLetter || $0.isNumber }) else {
            return nil
        }

        let prefix = String(word[word.startIndex..<firstIdx])
        let rawCore = String(word[firstIdx...lastIdx])
        let suffix = word.index(after: lastIdx) < word.endIndex
            ? String(word[word.index(after: lastIdx)...])
            : ""

        // Keep internal apostrophes and hyphens, strip others
        let core = filterCore(rawCore)
        guard !core.isEmpty, core.contains(where: { $0.isLetter || $0.isNumber }) else { return nil }

        let orpIndex = computeORP(core.count)
        let pauseMult = computePauseMult(suffix: suffix + (word.last.map(String.init) ?? ""), coreLength: core.count)

        return Token(core: core, prefix: prefix, suffix: suffix, orpIndex: orpIndex, pauseMult: pauseMult)
    }

    nonisolated private static func filterCore(_ raw: String) -> String {
        // Allow alphanumeric, internal apostrophes, internal hyphens
        var result = ""
        let chars = Array(raw)
        for (i, ch) in chars.enumerated() {
            if ch.isLetter || ch.isNumber {
                result.append(ch)
            } else if (ch == "'" || ch == "'" || ch == "-") && i > 0 && i < chars.count - 1 {
                result.append(ch)
            }
        }
        return result
    }

    nonisolated static func computeORP(_ len: Int) -> Int {
        switch len {
        case ..<2: return 0
        case ..<6: return 1
        case ..<10: return 2
        case ..<14: return 3
        default: return min(4, len - 1)
        }
    }

    nonisolated static func computePauseMult(suffix: String, coreLength: Int) -> Double {
        var mult = 1.0
        let lastChar = suffix.first ?? suffix.last
        if let c = lastChar {
            if ".!?".contains(c) { mult += 2.0 }
            else if ":;".contains(c) { mult += 1.8 }
            else if ",".contains(c) { mult += 1.4 }
        }
        if coreLength > 8 {
            let extra = min((coreLength - 8) / 4, 5)
            mult += Double(extra) * 0.1
        }
        return mult
    }
}
