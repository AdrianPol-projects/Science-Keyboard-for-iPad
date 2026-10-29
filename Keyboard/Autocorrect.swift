import UIKit

/// Spell-checking, corrections and word completions for English or Czech,
/// using the system dictionaries through UITextChecker.
final class Autocorrector {
    struct Analysis {
        var word: String
        var correction: String?
        var alternatives: [String] = []
        var completions: [String] = []
    }

    private let checker = UITextChecker()
    /// The user's own text replacements from iOS Settings (input → output).
    private var replacements: [String: String] = [:]
    private var cachedLanguage: (TypingLanguage, String?)?

    func setLexicon(_ lexicon: UILexicon) {
        var map: [String: String] = [:]
        for entry in lexicon.entries where entry.userInput.lowercased() != entry.documentText.lowercased() {
            map[entry.userInput.lowercased()] = entry.documentText
        }
        replacements = map
    }

    /// Picks the best matching UITextChecker language, e.g. "en_US" or "cs_CZ".
    func checkerLanguage(for language: TypingLanguage) -> String? {
        if let cached = cachedLanguage, cached.0 == language { return cached.1 }
        var code: String?
        if let prefix = language.checkerPrefix {
            let available = UITextChecker.availableLanguages
            code = available.first { $0 == prefix }
                ?? available.first { $0.hasPrefix(prefix + "_") }
                ?? available.first { $0.hasPrefix(prefix) }
        }
        cachedLanguage = (language, code)
        return code
    }

    static func isAvailable(_ language: TypingLanguage) -> Bool {
        guard let prefix = language.checkerPrefix else { return false }
        return UITextChecker.availableLanguages.contains { $0.hasPrefix(prefix) }
    }

    /// Words we should not touch: short words (element symbols like Fe, Na),
    /// acronyms, anything with digits, and LaTeX commands.
    static func shouldCheck(_ word: String, precededBy previous: Character?) -> Bool {
        guard word.count >= 2, word.count <= 40 else { return false }
        if let p = previous, p == "\\" || p == "^" || p == "_" || p.isNumber { return false }
        guard word.allSatisfy({ $0.isLetter || $0 == "'" || $0 == "’" }) else { return false }
        let letters = word.filter(\.isLetter)
        if letters.count > 1 && letters.allSatisfy(\.isUppercase) { return false }
        if letters.count <= 2 && PeriodicTable.element(symbol: word) != nil { return false }
        return true
    }

    func analyze(_ word: String, language: TypingLanguage) -> Analysis {
        var result = Analysis(word: word)
        guard let code = checkerLanguage(for: language) else { return result }
        let range = NSRange(location: 0, length: (word as NSString).length)

        if let replacement = replacements[word.lowercased()] {
            result.correction = replacement
        }

        if word.count >= 3 {
            let miss = checker.rangeOfMisspelledWord(in: word, range: range, startingAt: 0, wrap: false, language: code)
            if miss.location != NSNotFound {
                let guesses = (checker.guesses(forWordRange: range, in: word, language: code) ?? [])
                    .filter { $0.lowercased() != word.lowercased() }
                if result.correction == nil { result.correction = guesses.first.map { matchCase($0, to: word) } }
                result.alternatives = guesses.dropFirst().prefix(2).map { matchCase($0, to: word) }
            }
        }

        let completions = checker.completions(forPartialWordRange: range, in: word, language: code) ?? []
        result.completions = completions
            .filter { $0.lowercased() != word.lowercased() }
            .prefix(3)
            .map { matchCase($0, to: word) }
        return result
    }

    func learn(_ word: String) {
        UITextChecker.learnWord(word)
    }

    private func matchCase(_ candidate: String, to word: String) -> String {
        guard let first = word.first, first.isUppercase,
              let c = candidate.first, c.isLowercase else { return candidate }
        return candidate.prefix(1).uppercased() + candidate.dropFirst()
    }
}
