import CoreGraphics

enum KeyKind: Equatable {
    case letter, function, accent, spacer
}

enum KeyAction: Equatable {
    case text(String)
    case backspace, shift, returnKey, space, globe, dismiss, science
    case page(KeyPage)
}

struct KeySpec: Identifiable {
    var id: String
    var action: KeyAction
    var label: String = ""
    var icon: String? = nil
    var secondary: String? = nil
    var alternates: [String] = []
    var width: CGFloat = 1
    var kind: KeyKind = .letter
    var highlighted = false
}

enum KeyboardLayouts {
    struct Context {
        var pad: Bool
        var shift: ShiftState
        var flick: FlickMode
        var needsGlobe: Bool
        var returnLabel: String
        var returnPrimary: Bool
    }

    // iPad-style flick (swipe down) secondaries.
    static let numberFlick: [Character: String] = [
        "q": "1", "w": "2", "e": "3", "r": "4", "t": "5", "y": "6", "u": "7", "i": "8", "o": "9", "p": "0",
        "a": "@", "s": "#", "d": "$", "f": "&", "g": "*", "h": "(", "j": ")", "k": "'", "l": "\"",
        "z": "%", "x": "-", "c": "+", "v": "=", "b": "/", "n": ";", "m": ":",
    ]

    static let greekFlick: [Character: String] = [
        "q": "ϑ", "w": "ς", "e": "ε", "r": "ρ", "t": "τ", "y": "υ", "u": "θ", "i": "ι", "o": "ο", "p": "π",
        "a": "α", "s": "σ", "d": "δ", "f": "φ", "g": "γ", "h": "η", "j": "ξ", "k": "κ", "l": "λ",
        "z": "ζ", "x": "χ", "c": "ψ", "v": "ω", "b": "β", "n": "ν", "m": "μ",
    ]

    /// Long-press alternates: accents first, then science extras.
    static let alternates: [String: [String]] = [
        "a": ["à", "á", "â", "ä", "æ", "ã", "å", "ā", "α", "∀", "Å"],
        "b": ["β", "ℬ", "♭"],
        "c": ["ç", "ć", "č", "χ", "©", "℃", "ℂ"],
        "d": ["ď", "δ", "Δ", "∂", "ð", "∇"],
        "e": ["è", "é", "ê", "ë", "ē", "ė", "ę", "ε", "∈", "∃", "ℯ"],
        "f": ["φ", "ƒ", "ϕ", "Φ", "℉"],
        "g": ["ğ", "γ", "Γ", "ℊ"],
        "h": ["ℏ", "η", "ħ", "ℋ", "ℍ"],
        "i": ["ì", "í", "î", "ï", "ī", "į", "ι", "ı", "∞", "∫"],
        "j": ["ĵ", "ξ", "ȷ"],
        "k": ["κ", "ϰ", "K"],
        "l": ["ł", "λ", "Λ", "ℓ", "ℒ"],
        "m": ["μ", "µ", "ℳ"],
        "n": ["ñ", "ń", "ň", "ν", "∇", "ℕ"],
        "o": ["ò", "ó", "ô", "ö", "õ", "ø", "ō", "œ", "ω", "Ω", "°", "∘"],
        "p": ["π", "Π", "∏", "ψ", "Ψ", "℘", "ℙ", "¶"],
        "q": ["ℚ", "θ"],
        "r": ["ř", "ρ", "ϱ", "ℝ", "ℜ", "®"],
        "s": ["ß", "ś", "š", "ş", "σ", "Σ", "∑", "ς", "§"],
        "t": ["ť", "τ", "θ", "Θ", "ϑ", "†", "™"],
        "u": ["ù", "ú", "û", "ü", "ū", "ů", "υ", "µ", "∪"],
        "v": ["ν", "∨", "√"],
        "w": ["ω", "Ω", "ŵ"],
        "x": ["×", "χ", "ξ", "Ξ", "⊗"],
        "y": ["ÿ", "ý", "ψ", "Ψ", "υ"],
        "z": ["ž", "ź", "ż", "ζ", "ℤ"],
        "0": ["°", "∅", "⁰", "₀", "⊘"],
        "1": ["¹", "₁", "½", "⅓", "¼", "⅛"],
        "2": ["²", "₂", "⅔", "⅖"],
        "3": ["³", "₃", "¾", "⅜", "∛"],
        "4": ["⁴", "₄", "⅘", "∜"],
        "5": ["⁵", "₅", "⅝"],
        "6": ["⁶", "₆", "⅚"],
        "7": ["⁷", "₇", "⅞"],
        "8": ["⁸", "₈", "∞"],
        "9": ["⁹", "₉"],
        "-": ["–", "—", "−", "∓", "±", "•"],
        "=": ["≠", "≈", "≡", "≅", "≤", "≥", "∝"],
        "+": ["±", "∓", "⊕", "†"],
        "*": ["×", "·", "∗", "⋆", "⊗"],
        "/": ["÷", "⁄", "∕", "\\", "|"],
        "<": ["≤", "≪", "⟨", "←", "⇐"],
        ">": ["≥", "≫", "⟩", "→", "⇒"],
        ".": ["…", "·", "•", "°", "∘"],
        ",": [";", ":", "‚", "„"],
        "?": ["¿", "‽"],
        "!": ["¡", "‼", "≠"],
        "'": ["‘", "’", "′", "‚"],
        "\"": ["“", "”", "″", "«", "»", "„"],
        "$": ["€", "£", "¥", "¢", "₹", "₿", "₽"],
        "%": ["‰", "‱"],
        "&": ["§", "∧"],
        "(": ["[", "{", "⟨", "⌈", "⌊"],
        ")": ["]", "}", "⟩", "⌉", "⌋"],
        "^": ["ˆ", "∧", "↑"],
        "~": ["≈", "∼", "≃"],
        "|": ["‖", "∣", "⊥", "∥"],
        "#": ["№", "♯"],
        "@": ["⊙", "©"],
    ]

    private static func caseAlternates(_ list: [String], upper: Bool) -> [String] {
        guard upper else { return list }
        return list.map { s in
            let u = s.uppercased()
            return u.count == 1 ? u : s
        }
    }

    // MARK: Builders

    private static func letters(_ s: String, row: Int, _ ctx: Context) -> [KeySpec] {
        let upper = ctx.shift != .off
        return s.enumerated().map { idx, ch in
            let base = String(ch)
            var secondary: String?
            if ctx.pad {
                switch ctx.flick {
                case .numbers: secondary = numberFlick[ch]
                case .greek: secondary = greekFlick[ch].map { upper ? $0.uppercased() : $0 }
                case .off: secondary = nil
                }
            }
            return KeySpec(id: "r\(row)k\(idx)", action: .text(base), label: upper ? base.uppercased() : base,
                           secondary: secondary,
                           alternates: caseAlternates(alternates[base] ?? [], upper: upper))
        }
    }

    private static func plain(_ s: String, row: Int, offset: Int = 0, width: CGFloat = 1) -> [KeySpec] {
        s.enumerated().map { idx, ch in
            let base = String(ch)
            return KeySpec(id: "r\(row)k\(idx + offset)", action: .text(base), label: base,
                           alternates: alternates[base] ?? [], width: width)
        }
    }

    private static func punct(_ main: String, _ flick: String, id: String, _ ctx: Context) -> KeySpec {
        KeySpec(id: id, action: .text(main), label: main,
                secondary: ctx.pad && ctx.flick != .off ? flick : nil,
                alternates: alternates[main] ?? [])
    }

    private static func spacer(_ id: String, _ width: CGFloat) -> KeySpec {
        KeySpec(id: id, action: .text(""), width: width, kind: .spacer)
    }

    private static func backspace(_ width: CGFloat) -> KeySpec {
        KeySpec(id: "backspace", action: .backspace, icon: "delete.left", width: width, kind: .function)
    }

    private static func shiftKey(_ id: String, _ width: CGFloat, _ ctx: Context) -> KeySpec {
        let icon: String
        switch ctx.shift {
        case .off: icon = "shift"
        case .once: icon = "shift.fill"
        case .capsLock: icon = "capslock.fill"
        }
        return KeySpec(id: id, action: .shift, icon: icon, width: width, kind: .function,
                       highlighted: ctx.shift != .off)
    }

    private static func returnKey(_ width: CGFloat, _ ctx: Context) -> KeySpec {
        let icon: String? = ctx.pad || ctx.returnPrimary ? nil : "return"
        return KeySpec(id: "return", action: .returnKey, label: ctx.returnLabel, icon: icon, width: width,
                       kind: ctx.returnPrimary ? .accent : .function)
    }

    private static func pageKey(_ id: String, _ label: String, _ page: KeyPage, _ width: CGFloat) -> KeySpec {
        KeySpec(id: id, action: .page(page), label: label, width: width, kind: .function)
    }

    private static func pageSwitch(_ id: String, _ page: KeyPage, _ ctx: Context, width: CGFloat) -> KeySpec {
        switch page {
        case .letters: return pageKey(id, ctx.pad ? ".?123" : "123", .numbers, width)
        case .numbers, .symbols: return pageKey(id, "ABC", .letters, width)
        }
    }

    private static func bottomRow(_ page: KeyPage, _ ctx: Context) -> [KeySpec] {
        let science = KeySpec(id: "science", action: .science, icon: "function", width: ctx.pad ? 1 : 1.25, kind: .function)
        let globe = KeySpec(id: "globe", action: .globe, icon: "globe", width: ctx.pad ? 1 : 1.25, kind: .function)
        if ctx.pad {
            var row: [KeySpec] = [pageSwitch("pageL", page, ctx, width: 1.25)]
            if ctx.needsGlobe { row.append(globe) }
            row.append(science)
            let used: CGFloat = 1.25 + (ctx.needsGlobe ? 1 : 0) + 1 + 1.25 + 1.25
            row.append(KeySpec(id: "space", action: .space, label: "", width: 11.5 - used, kind: .letter))
            row.append(pageSwitch("pageR", page, ctx, width: 1.25))
            row.append(KeySpec(id: "dismiss", action: .dismiss, icon: "keyboard.chevron.compact.down", width: 1.25, kind: .function))
            return row
        }
        var row: [KeySpec] = [pageSwitch("pageL", page, ctx, width: 1.25)]
        if ctx.needsGlobe { row.append(globe) }
        row.append(science)
        let used: CGFloat = 1.25 + (ctx.needsGlobe ? 1.25 : 0) + 1.25 + 2.25
        row.append(KeySpec(id: "space", action: .space, label: "space", width: 10 - used, kind: .letter))
        row.append(returnKey(2.25, ctx))
        return row
    }

    // MARK: Pages

    static func rows(page: KeyPage, ctx: Context) -> [[KeySpec]] {
        if ctx.pad {
            switch page {
            case .letters:
                return [
                    letters("qwertyuiop", row: 0, ctx) + [backspace(1.5)],
                    [spacer("s1", 0.5)] + letters("asdfghjkl", row: 1, ctx) + [returnKey(2, ctx)],
                    [shiftKey("lshift", 1.25, ctx)] + letters("zxcvbnm", row: 2, ctx)
                        + [punct(",", "!", id: "comma", ctx), punct(".", "?", id: "period", ctx), shiftKey("rshift", 1.25, ctx)],
                    bottomRow(page, ctx),
                ]
            case .numbers:
                return [
                    plain("1234567890", row: 0) + [backspace(1.5)],
                    [spacer("s1", 0.5)] + plain("@#$&*()'\"", row: 1) + [returnKey(2, ctx)],
                    [pageKey("sym1", "#+=", .symbols, 1.25)] + plain("%-+=/;:,.", row: 2) + [pageKey("sym2", "#+=", .symbols, 1.25)],
                    bottomRow(page, ctx),
                ]
            case .symbols:
                return [
                    plain("[]{}#%^*+=", row: 0) + [backspace(1.5)],
                    [spacer("s1", 0.5)] + plain("_\\|~<>€£¥", row: 1) + [returnKey(2, ctx)],
                    [pageKey("num1", "123", .numbers, 1.25)] + plain("…±×÷≈≠≤≥°", row: 2) + [pageKey("num2", "123", .numbers, 1.25)],
                    bottomRow(page, ctx),
                ]
            }
        }

        switch page {
        case .letters:
            return [
                letters("qwertyuiop", row: 0, ctx),
                [spacer("s1", 0.5)] + letters("asdfghjkl", row: 1, ctx) + [spacer("s2", 0.5)],
                [shiftKey("lshift", 1.5, ctx)] + letters("zxcvbnm", row: 2, ctx) + [backspace(1.5)],
                bottomRow(page, ctx),
            ]
        case .numbers:
            return [
                plain("1234567890", row: 0),
                plain("-/:;()$&@\"", row: 1),
                [pageKey("sym1", "#+=", .symbols, 1.5)] + plain(".,?!'", row: 2, width: 1.4) + [backspace(1.5)],
                bottomRow(page, ctx),
            ]
        case .symbols:
            return [
                plain("[]{}#%^*+=", row: 0),
                plain("_\\|~<>€£¥•", row: 1),
                [pageKey("num1", "123", .numbers, 1.5)] + plain(".,?!'", row: 2, width: 1.4) + [backspace(1.5)],
                bottomRow(page, ctx),
            ]
        }
    }

    /// Bottom row shown under panels.
    static func utilityRow(_ ctx: Context) -> [KeySpec] {
        var row: [KeySpec] = [pageKey("u.abc", "ABC", .letters, 1.5)]
        if ctx.needsGlobe {
            row.append(KeySpec(id: "u.globe", action: .globe, icon: "globe", width: 1.2, kind: .function))
        }
        row.append(KeySpec(id: "u.space", action: .space, label: ctx.pad ? "" : "space", width: ctx.needsGlobe ? 5.3 : 6.5, kind: .letter))
        row.append(backspace(1.5))
        var ret = returnKey(1.5, ctx)
        ret.id = "u.return"
        row.append(ret)
        return row
    }
}
