import Foundation

// MARK: - Superscript / subscript

enum ScriptStyle: String, Codable, CaseIterable, Identifiable {
    case sup, sub
    var id: String { rawValue }
    var title: String { self == .sup ? "Superscript" : "Subscript" }
    var short: String { self == .sup ? "x²" : "x₂" }
}

enum Scripts {
    static let superscriptMap: [Character: Character] = [
        "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
        "+": "⁺", "-": "⁻", "−": "⁻", "=": "⁼", "(": "⁽", ")": "⁾", " ": " ",
        "a": "ᵃ", "b": "ᵇ", "c": "ᶜ", "d": "ᵈ", "e": "ᵉ", "f": "ᶠ", "g": "ᵍ", "h": "ʰ", "i": "ⁱ", "j": "ʲ",
        "k": "ᵏ", "l": "ˡ", "m": "ᵐ", "n": "ⁿ", "o": "ᵒ", "p": "ᵖ", "r": "ʳ", "s": "ˢ", "t": "ᵗ", "u": "ᵘ",
        "v": "ᵛ", "w": "ʷ", "x": "ˣ", "y": "ʸ", "z": "ᶻ",
        "A": "ᴬ", "B": "ᴮ", "D": "ᴰ", "E": "ᴱ", "G": "ᴳ", "H": "ᴴ", "I": "ᴵ", "J": "ᴶ", "K": "ᴷ", "L": "ᴸ",
        "M": "ᴹ", "N": "ᴺ", "O": "ᴼ", "P": "ᴾ", "R": "ᴿ", "T": "ᵀ", "U": "ᵁ", "V": "ⱽ", "W": "ᵂ",
        "α": "ᵅ", "β": "ᵝ", "γ": "ᵞ", "δ": "ᵟ", "ε": "ᵋ", "θ": "ᶿ", "ι": "ᶥ", "φ": "ᵠ", "χ": "ᵡ",
    ]

    static let subscriptMap: [Character: Character] = [
        "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄", "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
        "+": "₊", "-": "₋", "−": "₋", "=": "₌", "(": "₍", ")": "₎", " ": " ",
        "a": "ₐ", "e": "ₑ", "h": "ₕ", "i": "ᵢ", "j": "ⱼ", "k": "ₖ", "l": "ₗ", "m": "ₘ", "n": "ₙ", "o": "ₒ",
        "p": "ₚ", "r": "ᵣ", "s": "ₛ", "t": "ₜ", "u": "ᵤ", "v": "ᵥ", "x": "ₓ", "ə": "ₔ",
        "β": "ᵦ", "γ": "ᵧ", "ρ": "ᵨ", "φ": "ᵩ", "χ": "ᵪ",
    ]

    static func superscript(_ s: String) -> String {
        String(s.map { superscriptMap[$0] ?? $0 })
    }

    static func subscripted(_ s: String) -> String {
        String(s.map { subscriptMap[$0] ?? $0 })
    }

    static func canSuperscript(_ s: String) -> Bool {
        !s.isEmpty && s.allSatisfy { superscriptMap[$0] != nil }
    }

    static func canSubscript(_ s: String) -> Bool {
        !s.isEmpty && s.allSatisfy { subscriptMap[$0] != nil }
    }

    static func apply(_ style: ScriptStyle, to s: String) -> String {
        style == .sup ? superscript(s) : subscripted(s)
    }

    /// "2+", "+2", "-", "3-", "-1" → "²⁺", "²⁺", "⁻", "³⁻", "⁻"
    static func charge(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return "" }
        let digits = t.filter { $0.isASCII && $0.isNumber }
        let negative = t.contains("-") || t.contains("−")
        let magnitude = digits == "1" ? "" : digits
        if magnitude == "0" { return superscript("0") }
        return superscript(magnitude + (negative ? "-" : "+"))
    }
}

// MARK: - Mathematical alphanumeric styles

enum MathAlphabet: String, Codable, CaseIterable, Identifiable {
    case bold, italic, boldItalic, script, boldScript, fraktur, boldFraktur, doubleStruck
    case sans, sansBold, sansItalic, sansBoldItalic, monospace

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bold: return "Bold"
        case .italic: return "Italic"
        case .boldItalic: return "Bold italic"
        case .script: return "Script"
        case .boldScript: return "Bold script"
        case .fraktur: return "Fraktur"
        case .boldFraktur: return "Bold Fraktur"
        case .doubleStruck: return "Double-struck"
        case .sans: return "Sans-serif"
        case .sansBold: return "Sans bold"
        case .sansItalic: return "Sans italic"
        case .sansBoldItalic: return "Sans bold italic"
        case .monospace: return "Monospace"
        }
    }

    var sample: String { apply(to: "Abc") }

    private var bases: (upper: UInt32, lower: UInt32, digit: UInt32?) {
        switch self {
        case .bold: return (0x1D400, 0x1D41A, 0x1D7CE)
        case .italic: return (0x1D434, 0x1D44E, nil)
        case .boldItalic: return (0x1D468, 0x1D482, nil)
        case .script: return (0x1D49C, 0x1D4B6, nil)
        case .boldScript: return (0x1D4D0, 0x1D4EA, nil)
        case .fraktur: return (0x1D504, 0x1D51E, nil)
        case .boldFraktur: return (0x1D56C, 0x1D586, nil)
        case .doubleStruck: return (0x1D538, 0x1D552, 0x1D7D8)
        case .sans: return (0x1D5A0, 0x1D5BA, 0x1D7E2)
        case .sansBold: return (0x1D5D4, 0x1D5EE, 0x1D7EC)
        case .sansItalic: return (0x1D608, 0x1D622, nil)
        case .sansBoldItalic: return (0x1D63C, 0x1D656, nil)
        case .monospace: return (0x1D670, 0x1D68A, 0x1D7F6)
        }
    }

    private var greekBases: (upper: UInt32, lower: UInt32)? {
        switch self {
        case .bold: return (0x1D6A8, 0x1D6C2)
        case .italic: return (0x1D6E2, 0x1D6FC)
        case .boldItalic: return (0x1D71C, 0x1D736)
        case .sansBold: return (0x1D756, 0x1D770)
        case .sansBoldItalic: return (0x1D790, 0x1D7AA)
        default: return nil
        }
    }

    /// Letters that live in the Letterlike Symbols block instead.
    private var exceptions: [Character: Character] {
        switch self {
        case .italic: return ["h": "ℎ"]
        case .script:
            return ["B": "ℬ", "E": "ℰ", "F": "ℱ", "H": "ℋ", "I": "ℐ", "L": "ℒ", "M": "ℳ", "R": "ℛ",
                    "e": "ℯ", "g": "ℊ", "o": "ℴ"]
        case .fraktur: return ["C": "ℭ", "H": "ℌ", "I": "ℑ", "R": "ℜ", "Z": "ℨ"]
        case .doubleStruck:
            return ["C": "ℂ", "H": "ℍ", "N": "ℕ", "P": "ℙ", "Q": "ℚ", "R": "ℝ", "Z": "ℤ"]
        default: return [:]
        }
    }

    func apply(to s: String) -> String {
        let ex = exceptions
        let b = bases
        let g = greekBases
        var out = ""
        for ch in s {
            if let e = ex[ch] { out.append(e); continue }
            guard ch.unicodeScalars.count == 1, let scalar = ch.unicodeScalars.first else {
                out.append(ch); continue
            }
            let v = scalar.value
            var mapped: UInt32?
            switch v {
            case 65...90: mapped = b.upper + v - 65
            case 97...122: mapped = b.lower + v - 97
            case 48...57: if let d = b.digit { mapped = d + v - 48 }
            case 0x391...0x3A9 where v != 0x3A2: if let g = g { mapped = g.upper + v - 0x391 }
            case 0x3B1...0x3C9: if let g = g { mapped = g.lower + v - 0x3B1 }
            default: break
            }
            if let m = mapped, let u = Unicode.Scalar(m) {
                out.unicodeScalars.append(u)
            } else {
                out.append(ch)
            }
        }
        return out
    }
}

// MARK: - Combining marks

enum CombiningMark: String, CaseIterable, Identifiable {
    case vector = "\u{20D7}"
    case leftVector = "\u{20D6}"
    case bothVector = "\u{20E1}"
    case hat = "\u{0302}"
    case bar = "\u{0304}"
    case overline = "\u{0305}"
    case dot = "\u{0307}"
    case ddot = "\u{0308}"
    case tdot = "\u{20DB}"
    case tilde = "\u{0303}"
    case check = "\u{030C}"
    case ring = "\u{030A}"
    case acute = "\u{0301}"
    case grave = "\u{0300}"
    case breve = "\u{0306}"
    case underline = "\u{0332}"
    case slash = "\u{0338}"
    case circle = "\u{20DD}"
    case square = "\u{20DE}"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vector: return "Vector →"
        case .leftVector: return "Arrow ←"
        case .bothVector: return "Arrow ↔"
        case .hat: return "Hat"
        case .bar: return "Bar"
        case .overline: return "Overline"
        case .dot: return "Dot"
        case .ddot: return "Double dot"
        case .tdot: return "Triple dot"
        case .tilde: return "Tilde"
        case .check: return "Caron"
        case .ring: return "Ring"
        case .acute: return "Acute"
        case .grave: return "Grave"
        case .breve: return "Breve"
        case .underline: return "Underline"
        case .slash: return "Negate /"
        case .circle: return "Circled"
        case .square: return "Boxed"
        }
    }

    func apply(to s: String) -> String {
        var out = ""
        for ch in s {
            out.append(ch)
            if !ch.isWhitespace { out += rawValue }
        }
        return out
    }
}

// MARK: - Number formatting

enum NumberFormat {
    static func general(_ d: Double) -> String {
        if d.isNaN { return "NaN" }
        if d.isInfinite { return d > 0 ? "∞" : "-∞" }
        let a = abs(d)
        if a != 0 && (a >= 1e15 || a < 1e-4) { return scientific(d, significant: 6) }
        if d == d.rounded() { return String(Int64(d)) }
        return String(format: "%.10g", d)
    }

    /// 6.62607015e-34 → "6.626 × 10⁻³⁴"
    static func scientific(_ d: Double, significant: Int = 4) -> String {
        guard d != 0, d.isFinite else { return d == 0 ? "0" : general(d) }
        var exp = Int(floor(log10(abs(d))))
        var m = d / pow(10, Double(exp))
        let digits = max(significant, 1)
        let factor = pow(10, Double(digits - 1))
        m = (m * factor).rounded() / factor
        if abs(m) >= 10 { m /= 10; exp += 1 }
        var ms = String(format: "%.\(digits - 1)f", m)
        if ms.contains(".") {
            while ms.hasSuffix("0") { ms.removeLast() }
            if ms.hasSuffix(".") { ms.removeLast() }
        }
        if exp == 0 { return ms }
        return ms + " × 10" + Scripts.superscript(String(exp))
    }
}

// MARK: - Misc helpers

extension String {
    /// Unicode name of a single-scalar string, e.g. "∇" → "NABLA".
    var unicodeName: String? {
        guard unicodeScalars.count == 1, let s = unicodeScalars.first else { return nil }
        return s.properties.name ?? s.properties.nameAlias
    }

    var codepointLabel: String {
        unicodeScalars.map { String(format: "U+%04X", $0.value) }.joined(separator: " ")
    }

    /// Strings that consist only of combining marks get a dotted circle so they are visible.
    var displayForm: String {
        guard let first = unicodeScalars.first else { return self }
        switch first.properties.generalCategory {
        case .nonspacingMark, .enclosingMark, .spacingMark: return "◌" + self
        default: return self
        }
    }
}
