import Foundation

protocol TitleSuggesting: Sendable {
    func suggestTitle(for recognizedText: String) -> String
}

/// Produces a short, editable title from Vision OCR without sending screenshot
/// content off device. It favors heading-like lines and ignores common status
/// bar, browser, price, and navigation text.
struct TitleSuggestionService: TitleSuggesting {
    private static let fallbackTitle = "Imported Screenshot"
    private static let ignoredLabels: Set<String> = [
        "back", "cancel", "close", "done", "edit", "home", "menu", "more",
        "next", "options", "previous", "save", "search", "share", "skip"
    ]

    func suggestTitle(for recognizedText: String) -> String {
        let lines = recognizedText
            .components(separatedBy: .newlines)
            .map(normalize)
            .filter { !$0.isEmpty }

        let candidates = lines.enumerated().compactMap { index, line -> Candidate? in
            guard isUseful(line) else { return nil }
            return Candidate(text: line, score: score(line, at: index))
        }

        guard let best = candidates.max(by: { lhs, rhs in
            lhs.score == rhs.score ? lhs.text.count > rhs.text.count : lhs.score < rhs.score
        }) else {
            return Self.fallbackTitle
        }

        return shortened(best.text)
    }

    private func normalize(_ line: String) -> String {
        line
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isUseful(_ line: String) -> Bool {
        guard line.count >= 3, line.count <= 120 else { return false }

        let lowercase = line.lowercased()
        guard !Self.ignoredLabels.contains(lowercase) else { return false }
        guard !lowercase.hasPrefix("http://"),
              !lowercase.hasPrefix("https://"),
              !lowercase.hasPrefix("www.") else { return false }

        let wordCount = words(in: line).count
        guard wordCount <= 16 else { return false }

        let letters = line.unicodeScalars.filter(CharacterSet.letters.contains)
        guard letters.count >= 3 else { return false }

        if line.range(
            of: #"^\d{1,2}:\d{2}\s*(AM|PM)?$"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil {
            return false
        }

        if line.range(
            of: #"^[\$€£]?\s*\d+[\d,.]*\s*$"#,
            options: .regularExpression
        ) != nil {
            return false
        }

        return true
    }

    private func score(_ line: String, at index: Int) -> Int {
        let wordList = words(in: line)
        var result = max(24 - (index * 3), 0)

        switch line.count {
        case 8...45: result += 32
        case 46...65: result += 20
        case 66...90: result += 6
        default: break
        }

        switch wordList.count {
        case 2...7: result += 28
        case 1: result += 8
        case 8...12: result += 10
        default: break
        }

        let headingWords = wordList.filter { word in
            word.first?.isUppercase == true || word == word.uppercased()
        }
        if !wordList.isEmpty && headingWords.count * 2 >= wordList.count {
            result += 12
        }

        let lowercase = line.lowercased()
        let usefulTerms = [
            "appointment", "booking", "confirmation", "event", "flight", "hotel",
            "order", "recipe", "reservation", "ticket", "trip"
        ]
        if usefulTerms.contains(where: lowercase.contains) {
            result += 12
        }

        if line.contains("$") { result -= 14 }
        if line.hasSuffix(".") || line.hasSuffix("!") || line.hasSuffix("?") { result -= 6 }
        if line.contains(":") { result -= 4 }

        return result
    }

    private func words(in line: String) -> [Substring] {
        line.split { !$0.isLetter && !$0.isNumber && $0 != "'" && $0 != "-" }
    }

    private func shortened(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "•·|–—:;"))
        )
        guard trimmed.count > 64 else { return trimmed }

        let prefix = String(trimmed.prefix(64))
        if let lastSpace = prefix.lastIndex(of: " ") {
            return String(prefix[..<lastSpace]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return prefix
    }
}

private struct Candidate {
    let text: String
    let score: Int
}
