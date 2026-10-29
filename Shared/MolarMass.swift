import Foundation

enum MassPrecision: String, CaseIterable, Identifiable {
    case precise, oneDecimal, whole
    var id: String { rawValue }
    var title: String {
        switch self {
        case .precise: return "Precise"
        case .oneDecimal: return "1 decimal"
        case .whole: return "Whole numbers"
        }
    }
}

enum MassKind: String, CaseIterable, Identifiable {
    case molar, molecular, relative
    var id: String { rawValue }
    var title: String {
        switch self {
        case .molar: return "Molar mass M"
        case .molecular: return "Molecule mass m"
        case .relative: return "Relative Mᵣ"
        }
    }
    var symbol: String {
        switch self {
        case .molar: return "M"
        case .molecular: return "m"
        case .relative: return "Mᵣ"
        }
    }
}

enum MultiplyStyle: String, CaseIterable, Identifiable {
    case dot, times, parens
    var id: String { rawValue }
    var title: String {
        switch self {
        case .dot: return "2·1"
        case .times: return "2×1"
        case .parens: return "2(1)"
        }
    }
}

enum MassUnitStyle: String, CaseIterable, Identifiable {
    case superscript, slash
    var id: String { rawValue }
    var title: String { self == .superscript ? "g·mol⁻¹" : "g/mol" }
}

struct ElementCounter: Equatable {
    private(set) var order: [String] = []
    private(set) var counts: [String: Int] = [:]

    var isEmpty: Bool { order.isEmpty }

    mutating func add(_ symbol: String, _ n: Int) {
        if counts[symbol] == nil { order.append(symbol) }
        counts[symbol, default: 0] += n
    }

    mutating func merge(_ other: ElementCounter, times: Int) {
        for s in other.order { add(s, (other.counts[s] ?? 0) * times) }
    }
}

enum MolarMassError: LocalizedError {
    case unknownElement(String)
    case unexpected(Character)
    case unbalanced
    case empty

    var errorDescription: String? {
        switch self {
        case .unknownElement(let s): return "“\(s)” is not an element"
        case .unexpected(let c): return "Unexpected “\(c)”"
        case .unbalanced: return "Brackets don’t match"
        case .empty: return "Enter a formula, e.g. H2O"
        }
    }
}

struct MolarMassReport {
    let input: String
    let counter: ElementCounter

    var pretty: String { ChemFormatter.formatText(MolarMass.stripCharge(input)) }

    var elements: [(element: Element, count: Int)] {
        counter.order.compactMap { s in
            PeriodicTable.element(symbol: s).map { ($0, counter.counts[s] ?? 0) }
        }
    }

    static func mass(of e: Element, _ p: MassPrecision) -> Double {
        switch p {
        case .precise: return e.mass
        case .oneDecimal: return (e.mass * 10).rounded() / 10
        case .whole: return e.mass.rounded()
        }
    }

    static func massText(of e: Element, _ p: MassPrecision) -> String {
        switch p {
        case .precise: return e.massText.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        case .oneDecimal: return String(format: "%.1f", mass(of: e, p))
        case .whole: return String(Int(mass(of: e, p)))
        }
    }

    func total(_ p: MassPrecision) -> Double {
        elements.reduce(0) { $0 + Double($1.count) * Self.mass(of: $1.element, p) }
    }

    func totalText(_ p: MassPrecision) -> String {
        let t = total(p)
        switch p {
        case .whole: return String(Int(t.rounded()))
        case .oneDecimal: return String(format: "%.1f", t)
        case .precise:
            var s = String(format: "%.3f", t)
            while s.hasSuffix("0") { s.removeLast() }
            if s.hasSuffix(".") { s.removeLast() }
            return s
        }
    }

    private static func term(_ count: Int, _ value: String, _ style: MultiplyStyle) -> String {
        guard count != 1 else { return value }
        switch style {
        case .dot: return "\(count)·\(value)"
        case .times: return "\(count) × \(value)"
        case .parens: return "\(count)(\(value))"
        }
    }

    /// "2·1.008 + 15.999"
    func numericSteps(_ p: MassPrecision, _ style: MultiplyStyle) -> String {
        elements.map { Self.term($0.count, Self.massText(of: $0.element, p), style) }.joined(separator: " + ")
    }

    /// "2·M(H) + M(O)"
    func symbolicSteps(_ kind: MassKind, _ style: MultiplyStyle) -> String {
        let sym = kind == .relative ? "Aᵣ" : kind.symbol
        return elements.map { Self.term($0.count, "\(sym)(\($0.element.symbol))", style) }.joined(separator: " + ")
    }

    func unit(_ kind: MassKind, _ unitStyle: MassUnitStyle) -> String {
        switch kind {
        case .molar: return unitStyle == .superscript ? " g·mol⁻¹" : " g/mol"
        case .molecular: return " u"
        case .relative: return ""
        }
    }

    /// "M(H₂O) = 2·1.008 + 15.999 = 18.015 g·mol⁻¹"
    func equation(_ kind: MassKind, _ p: MassPrecision, _ style: MultiplyStyle, _ unitStyle: MassUnitStyle,
                  symbolic: Bool = false, steps: Bool = true) -> String {
        var parts = ["\(kind.symbol)(\(pretty))"]
        if symbolic && (elements.count > 1 || elements.first?.count != 1) { parts.append(symbolicSteps(kind, style)) }
        if steps && (elements.count > 1 || elements.first?.count != 1) { parts.append(numericSteps(p, style)) }
        parts.append(totalText(p) + unit(kind, unitStyle))
        return parts.joined(separator: " = ")
    }

    /// Mass fractions, e.g. [("H", 11.19), ("O", 88.81)]
    func composition(_ p: MassPrecision) -> [(String, Double)] {
        let t = total(p)
        guard t > 0 else { return [] }
        return elements.map { ($0.element.symbol, Double($0.count) * Self.mass(of: $0.element, p) / t * 100) }
    }
}

enum MolarMass {
    private static let subscriptDigits: [Character: Character] = [
        "₀": "0", "₁": "1", "₂": "2", "₃": "3", "₄": "4", "₅": "5", "₆": "6", "₇": "7", "₈": "8", "₉": "9",
    ]
    private static let superscriptChars = Set("⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻")

    private static func isDigit(_ c: Character) -> Bool { c.isASCII && c.isNumber }
    private static func isSeparator(_ c: Character) -> Bool { c == "·" || c == "." || c == "*" || c == "•" || c == "⋅" }

    /// Removes ion charges, which don't change the mass meaningfully: "SO4^2-" → "SO4", "Fe3+" → "Fe", "NH4+" → "NH4".
    static func stripCharge(_ text: String) -> String {
        var s = String(text.filter { !superscriptChars.contains($0) })
        if let caret = s.firstIndex(of: "^") { s = String(s[..<caret]) }
        s = s.trimmingCharacters(in: .whitespaces)
        if let last = s.last, last == "+" || last == "-" || last == "−" {
            s.removeLast()
            var digits = ""
            while let d = s.last, isDigit(d) { digits.insert(d, at: digits.startIndex); s.removeLast() }
            let letters = Array(s)
            let monatomic = (letters.count == 1 && letters[0].isUppercase)
                || (letters.count == 2 && letters[0].isUppercase && letters[1].isLowercase)
            if !monatomic { s += digits }
            s = s.trimmingCharacters(in: .whitespaces)
        }
        return s
    }

    static func parse(_ text: String) throws -> ElementCounter {
        let normalized = stripCharge(String(text.map { subscriptDigits[$0] ?? $0 }))
        let chars = Array(normalized)
        guard chars.contains(where: { $0.isLetter }) else { throw MolarMassError.empty }
        var i = 0
        var total = ElementCounter()
        while i < chars.count {
            while i < chars.count && chars[i] == " " { i += 1 }
            let coefficient = readNumber(chars, &i) ?? 1
            let part = try parseSequence(chars, &i, closing: nil)
            total.merge(part, times: coefficient)
            if i < chars.count {
                if isSeparator(chars[i]) { i += 1 } else { throw MolarMassError.unexpected(chars[i]) }
            }
        }
        guard !total.isEmpty else { throw MolarMassError.empty }
        return total
    }

    static func report(_ text: String) -> Result<MolarMassReport, Error> {
        do {
            return .success(MolarMassReport(input: text, counter: try parse(text)))
        } catch {
            return .failure(error)
        }
    }

    private static func readNumber(_ c: [Character], _ i: inout Int) -> Int? {
        var s = ""
        while i < c.count && isDigit(c[i]) { s.append(c[i]); i += 1 }
        return s.isEmpty ? nil : Int(s)
    }

    private static func closingFor(_ c: Character) -> Character {
        switch c {
        case "[": return "]"
        case "{": return "}"
        default: return ")"
        }
    }

    private static func parseSequence(_ c: [Character], _ i: inout Int, closing: Character?) throws -> ElementCounter {
        var counter = ElementCounter()
        while i < c.count {
            let ch = c[i]
            if ch == " " { i += 1; continue }
            if closing == nil && isSeparator(ch) { return counter }
            if ch == "(" || ch == "[" || ch == "{" {
                // State symbols such as (aq) or (s) are ignored.
                if let close = c[i...].firstIndex(of: closingFor(ch)),
                   ["aq", "s", "l", "g"].contains(String(c[(i + 1)..<close])) {
                    i = close + 1
                    continue
                }
                i += 1
                let inner = try parseSequence(c, &i, closing: closingFor(ch))
                counter.merge(inner, times: readNumber(c, &i) ?? 1)
                continue
            }
            if ch == ")" || ch == "]" || ch == "}" {
                guard ch == closing else { throw MolarMassError.unbalanced }
                i += 1
                return counter
            }
            if ch.isUppercase {
                var symbol = String(ch)
                i += 1
                if i < c.count, c[i].isLowercase, PeriodicTable.isSymbol(symbol + String(c[i])) {
                    symbol += String(c[i])
                    i += 1
                }
                guard PeriodicTable.isSymbol(symbol) else {
                    var bad = symbol
                    if i < c.count, c[i].isLowercase { bad.append(c[i]) }
                    throw MolarMassError.unknownElement(bad)
                }
                counter.add(symbol, readNumber(c, &i) ?? 1)
                continue
            }
            throw MolarMassError.unexpected(ch)
        }
        if closing != nil { throw MolarMassError.unbalanced }
        return counter
    }
}
