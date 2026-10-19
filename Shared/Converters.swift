import Foundation

// MARK: - Chemistry

enum ChemFormatter {
    private static func isDigit(_ c: Character) -> Bool { c.isASCII && c.isNumber }
    private static func isSign(_ c: Character) -> Bool { c == "+" || c == "-" || c == "−" }

    /// "H2SO4" → H₂SO₄, "Ca(OH)2" → Ca(OH)₂, "SO4^2-" → SO₄²⁻, "Fe3+" → Fe³⁺,
    /// "NH4+" → NH₄⁺, "CuSO4.5H2O" → CuSO₄·5H₂O, "2H2O(l)" → 2H₂O(l), "^14C" → ¹⁴C
    static func formatFormula(_ token: String) -> String {
        let chars = Array(token)
        var out = ""
        var i = 0
        var termStart = true
        var termLetters = ""
        while i < chars.count {
            let c = chars[i]

            if c == "^" {
                i += 1
                var run = ""
                while i < chars.count, isDigit(chars[i]) || isSign(chars[i]) {
                    run.append(chars[i]); i += 1
                }
                out += run.contains(where: isSign) ? Scripts.charge(run) : Scripts.superscript(run)
                termStart = false
                continue
            }

            if c == "_" {
                i += 1
                var run = ""
                while i < chars.count, isDigit(chars[i]) || isSign(chars[i]) {
                    run.append(chars[i]); i += 1
                }
                out += Scripts.subscripted(run)
                continue
            }

            if isDigit(c) {
                var j = i
                while j < chars.count && isDigit(chars[j]) { j += 1 }
                let run = String(chars[i..<j])
                let signFollows = j < chars.count && isSign(chars[j]) && j + 1 == chars.count
                if termStart {
                    out += run
                } else if signFollows && isMonatomic(termLetters) {
                    out += Scripts.charge(run + (chars[j] == "+" ? "+" : "-"))
                    j += 1
                } else {
                    out += Scripts.subscripted(run)
                }
                i = j
                continue
            }

            if isSign(c) && i == chars.count - 1 && !termStart {
                out += c == "+" ? "⁺" : "⁻"
                i += 1
                continue
            }

            if c == "*" || c == "·" || c == "•" ||
                (c == "." && i + 1 < chars.count && (isDigit(chars[i + 1]) || chars[i + 1].isUppercase)) {
                out += "·"
                termStart = true
                termLetters = ""
                i += 1
                continue
            }

            if c == "(", let close = chars[i...].firstIndex(of: ")") {
                let inner = String(chars[(i + 1)..<close])
                if ["aq", "s", "l", "g"].contains(inner) {
                    out += "(\(inner))"
                    i = close + 1
                    continue
                }
            }

            if c.isLetter { termLetters.append(c) }
            out.append(c)
            termStart = false
            i += 1
        }
        return out
    }

    private static func isMonatomic(_ letters: String) -> Bool {
        let chars = Array(letters)
        guard chars.count == 1 || chars.count == 2, chars[0].isUppercase else { return false }
        return chars.count == 1 || chars[1].isLowercase
    }

    /// True when every capitalised run is a real element symbol, e.g. "CO2", "Fe3+", "Ca(OH)2".
    static func looksLikeFormula(_ token: String) -> Bool {
        let chars = Array(token)
        guard chars.count >= 2 else { return false }
        let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789()[]^_+-−·*.")
        guard chars.allSatisfy({ allowed.contains($0) }) else { return false }
        guard chars.contains(where: { isDigit($0) || isSign($0) || $0 == "^" }) else { return false }

        var i = 0
        var sawElement = false
        while i < chars.count {
            let c = chars[i]
            if c == "(", let close = chars[i...].firstIndex(of: ")"),
               ["aq", "s", "l", "g"].contains(String(chars[(i + 1)..<close])) {
                i = close + 1
                continue
            }
            if c.isUppercase {
                var sym = String(c)
                if i + 1 < chars.count, chars[i + 1].isLowercase {
                    let two = sym + String(chars[i + 1])
                    if PeriodicTable.isSymbol(two) {
                        sym = two
                        i += 1
                    }
                }
                guard PeriodicTable.isSymbol(sym) else { return false }
                sawElement = true
            } else if c.isLowercase {
                return false
            }
            i += 1
        }
        return sawElement
    }

    /// Formats a whole reaction: "2H2 + O2 -> 2H2O" → "2H₂ + O₂ → 2H₂O".
    static func formatText(_ text: String) -> String {
        var s = text
        for (a, b) in [("<=>", "⇌"), ("<->", "⇌"), ("-->", "⟶"), ("->", "→"), ("<-", "←"), ("=>", "⇒")] {
            s = s.replacingOccurrences(of: a, with: b)
        }
        return s.components(separatedBy: " ").map { token -> String in
            if token == "e-" { return "e⁻" }
            if looksLikeFormula(token) || token.contains("^") { return formatFormula(token) }
            return token
        }.joined(separator: " ")
    }

    /// "m/s2" → m/s², "kg*m*s-2" → kg·m·s⁻², "cm3" → cm³, "J mol-1 K-1" → J mol⁻¹ K⁻¹
    static func formatUnits(_ text: String) -> String {
        let chars = Array(text.replacingOccurrences(of: "*", with: "·"))
        var out = ""
        var i = 0
        while i < chars.count {
            let c = chars[i]
            let prevIsLetter = i > 0 && (chars[i - 1].isLetter || chars[i - 1] == ")")
            if prevIsLetter && (isDigit(c) || ((c == "-" || c == "−") && i + 1 < chars.count && isDigit(chars[i + 1]))) {
                var run = String(c)
                var j = i + 1
                while j < chars.count && isDigit(chars[j]) { run.append(chars[j]); j += 1 }
                out += Scripts.superscript(run)
                i = j
                continue
            }
            if c == "^" {
                var run = ""
                var j = i + 1
                while j < chars.count && (isDigit(chars[j]) || isSign(chars[j])) { run.append(chars[j]); j += 1 }
                out += Scripts.superscript(run)
                i = j
                continue
            }
            out.append(c)
            i += 1
        }
        return out
    }
}

// MARK: - LaTeX → Unicode

enum LatexConverter {
    static let greek: [String: String] = [
        "alpha": "α", "beta": "β", "gamma": "γ", "delta": "δ", "epsilon": "ε", "varepsilon": "ε",
        "zeta": "ζ", "eta": "η", "theta": "θ", "vartheta": "ϑ", "iota": "ι", "kappa": "κ",
        "varkappa": "ϰ", "lambda": "λ", "mu": "μ", "nu": "ν", "xi": "ξ", "omicron": "ο", "pi": "π",
        "varpi": "ϖ", "rho": "ρ", "varrho": "ϱ", "sigma": "σ", "varsigma": "ς", "tau": "τ",
        "upsilon": "υ", "phi": "φ", "varphi": "ϕ", "chi": "χ", "psi": "ψ", "omega": "ω",
        "digamma": "ϝ",
        "Alpha": "Α", "Beta": "Β", "Gamma": "Γ", "Delta": "Δ", "Epsilon": "Ε", "Zeta": "Ζ",
        "Eta": "Η", "Theta": "Θ", "Iota": "Ι", "Kappa": "Κ", "Lambda": "Λ", "Mu": "Μ", "Nu": "Ν",
        "Xi": "Ξ", "Omicron": "Ο", "Pi": "Π", "Rho": "Ρ", "Sigma": "Σ", "Tau": "Τ",
        "Upsilon": "Υ", "Phi": "Φ", "Chi": "Χ", "Psi": "Ψ", "Omega": "Ω",
    ]

    private static let other: [String: String] = [
        // Operators
        "pm": "±", "mp": "∓", "times": "×", "div": "÷", "cdot": "·", "ast": "∗", "star": "⋆",
        "circ": "∘", "bullet": "•", "oplus": "⊕", "ominus": "⊖", "otimes": "⊗", "oslash": "⊘",
        "odot": "⊙", "cap": "∩", "cup": "∪", "sqcap": "⊓", "sqcup": "⊔", "uplus": "⊎",
        "wedge": "∧", "land": "∧", "vee": "∨", "lor": "∨", "neg": "¬", "lnot": "¬",
        "setminus": "∖", "dagger": "†", "ddagger": "‡", "wr": "≀", "amalg": "⨿",
        // Relations
        "leq": "≤", "le": "≤", "geq": "≥", "ge": "≥", "neq": "≠", "ne": "≠", "approx": "≈",
        "equiv": "≡", "sim": "∼", "simeq": "≃", "cong": "≅", "propto": "∝", "ll": "≪", "gg": "≫",
        "lll": "⋘", "ggg": "⋙", "leqslant": "⩽", "geqslant": "⩾", "lesssim": "≲", "gtrsim": "≳",
        "subset": "⊂", "supset": "⊃", "subseteq": "⊆", "supseteq": "⊇", "subsetneq": "⊊",
        "supsetneq": "⊋", "sqsubseteq": "⊑", "sqsupseteq": "⊒", "in": "∈", "notin": "∉", "ni": "∋",
        "perp": "⊥", "parallel": "∥", "nparallel": "∦", "mid": "∣", "nmid": "∤", "models": "⊨",
        "vdash": "⊢", "dashv": "⊣", "doteq": "≐", "prec": "≺", "succ": "≻", "preceq": "⪯",
        "succeq": "⪰", "asymp": "≍", "bowtie": "⋈", "triangleq": "≜", "coloneqq": "≔",
        "approxeq": "≊", "nsim": "≁", "ncong": "≇", "nleq": "≰", "ngeq": "≱", "lhd": "⊲", "rhd": "⊳",
        // Arrows
        "to": "→", "rightarrow": "→", "leftarrow": "←", "gets": "←", "leftrightarrow": "↔",
        "Rightarrow": "⇒", "Leftarrow": "⇐", "Leftrightarrow": "⇔", "implies": "⟹", "impliedby": "⟸",
        "iff": "⟺", "mapsto": "↦", "longmapsto": "⟼", "uparrow": "↑", "downarrow": "↓",
        "updownarrow": "↕", "Uparrow": "⇑", "Downarrow": "⇓", "rightleftharpoons": "⇌",
        "leftrightharpoons": "⇋", "rightharpoonup": "⇀", "leftharpoonup": "↼",
        "longrightarrow": "⟶", "longleftarrow": "⟵", "longleftrightarrow": "⟷",
        "Longrightarrow": "⟹", "Longleftarrow": "⟸", "hookrightarrow": "↪", "hookleftarrow": "↩",
        "nearrow": "↗", "searrow": "↘", "swarrow": "↙", "nwarrow": "↖", "leadsto": "⤳",
        "rightrightarrows": "⇉", "leftleftarrows": "⇇", "circlearrowleft": "↺", "circlearrowright": "↻",
        "rightsquigarrow": "⇝", "twoheadrightarrow": "↠",
        // Big operators
        "sum": "∑", "prod": "∏", "coprod": "∐", "int": "∫", "iint": "∬", "iiint": "∭",
        "iiiint": "⨌", "oint": "∮", "oiint": "∯", "oiiint": "∰", "bigcup": "⋃", "bigcap": "⋂",
        "bigvee": "⋁", "bigwedge": "⋀", "bigoplus": "⨁", "bigotimes": "⨂", "bigodot": "⨀",
        // Misc
        "infty": "∞", "partial": "∂", "nabla": "∇", "forall": "∀", "exists": "∃", "nexists": "∄",
        "emptyset": "∅", "varnothing": "∅", "hbar": "ℏ", "hslash": "ℏ", "ell": "ℓ", "Re": "ℜ", "Im": "ℑ",
        "aleph": "ℵ", "beth": "ℶ", "gimel": "ℷ", "angle": "∠", "measuredangle": "∡",
        "sphericalangle": "∢", "triangle": "△", "degree": "°", "prime": "′", "dprime": "″",
        "therefore": "∴", "because": "∵", "ldots": "…", "dots": "…", "cdots": "⋯", "vdots": "⋮",
        "ddots": "⋱", "langle": "⟨", "rangle": "⟩", "lceil": "⌈", "rceil": "⌉", "lfloor": "⌊",
        "rfloor": "⌋", "lVert": "‖", "rVert": "‖", "Vert": "‖", "vert": "|", "surd": "√",
        "top": "⊤", "bot": "⊥", "wp": "℘", "Box": "□", "square": "□", "blacksquare": "■",
        "Diamond": "◇", "diamond": "⋄", "lozenge": "◊", "checkmark": "✓", "AA": "Å",
        "angstrom": "Å", "celsius": "℃", "ohm": "Ω", "mho": "℧", "micro": "µ", "permil": "‰",
        "complement": "∁", "S": "§", "P": "¶", "copyright": "©", "pounds": "£", "euro": "€",
        "flat": "♭", "natural": "♮", "sharp": "♯", "clubsuit": "♣", "diamondsuit": "♢",
        "heartsuit": "♡", "spadesuit": "♠", "bigstar": "★", "star2": "☆", "sun": "☉", "earth": "⊕",
        "male": "♂", "female": "♀", "smile": "⌣", "frown": "⌢", "backslash": "∖",
        "lbrace": "{", "rbrace": "}", "lbrack": "[", "rbrack": "]", "llbracket": "⟦", "rrbracket": "⟧",
        "half": "½", "third": "⅓", "quarter": "¼", "deg": "°",
        // Spacing / escapes
        "quad": "\u{2003}", "qquad": "\u{2003}\u{2003}", ",": "\u{2009}", ";": "\u{2005}",
        ":": "\u{2005}", "!": "", " ": " ", "\\": "\n", "{": "{", "}": "}", "%": "%", "&": "&",
        "_": "_", "#": "#", "$": "$", "|": "‖",
    ]

    static let symbols: [String: String] = greek.merging(other) { a, _ in a }

    static let functionNames: Set<String> = [
        "sin", "cos", "tan", "cot", "sec", "csc", "arcsin", "arccos", "arctan", "sinh", "cosh",
        "tanh", "coth", "log", "ln", "lg", "exp", "lim", "liminf", "limsup", "max", "min", "sup",
        "inf", "det", "dim", "ker", "deg", "arg", "gcd", "hom", "Pr", "mod", "bmod", "tr", "rank",
    ]

    private static let vulgar: [String: String] = [
        "1/2": "½", "1/3": "⅓", "2/3": "⅔", "1/4": "¼", "3/4": "¾", "1/5": "⅕", "2/5": "⅖",
        "3/5": "⅗", "4/5": "⅘", "1/6": "⅙", "5/6": "⅚", "1/7": "⅐", "1/8": "⅛", "3/8": "⅜",
        "5/8": "⅝", "7/8": "⅞", "1/9": "⅑", "1/10": "⅒", "0/3": "↉",
    ]

    /// Reverse lookup used by search: "∇" → ["nabla"]
    static let aliases: [String: [String]] = {
        var map: [String: [String]] = [:]
        for (k, v) in symbols where v.count == 1 && k.count > 1 { map[v, default: []].append(k) }
        return map
    }()

    static func convert(_ input: String) -> String {
        let chars = Array(input)
        var i = 0
        return parseSequence(chars, &i, untilBrace: false)
    }

    static func fraction(_ a: String, _ b: String) -> String {
        if let v = vulgar["\(a)/\(b)"] { return v }
        if Scripts.canSuperscript(a) && Scripts.canSubscript(b) {
            return Scripts.superscript(a) + "⁄" + Scripts.subscripted(b)
        }
        let l = a.count > 1 ? "(\(a))" : a
        let r = b.count > 1 ? "(\(b))" : b
        return l + "/" + r
    }

    private static func parseSequence(_ c: [Character], _ i: inout Int, untilBrace: Bool) -> String {
        var out = ""
        while i < c.count {
            let ch = c[i]
            switch ch {
            case "}" where untilBrace:
                i += 1
                return out
            case "\\":
                out += parseCommand(c, &i)
            case "^":
                i += 1
                let g = parseGroup(c, &i)
                if Scripts.canSuperscript(g) { out += Scripts.superscript(g) }
                else { out += g.count == 1 ? "^" + g : "^(" + g + ")" }
            case "_":
                i += 1
                let g = parseGroup(c, &i)
                if Scripts.canSubscript(g) { out += Scripts.subscripted(g) }
                else { out += g.count == 1 ? "_" + g : "_(" + g + ")" }
            case "{":
                i += 1
                out += parseSequence(c, &i, untilBrace: true)
            case "~":
                out += "\u{00A0}"
                i += 1
            default:
                out.append(ch)
                i += 1
            }
        }
        return out
    }

    private static func parseGroup(_ c: [Character], _ i: inout Int) -> String {
        while i < c.count && c[i] == " " { i += 1 }
        guard i < c.count else { return "" }
        if c[i] == "{" {
            i += 1
            return parseSequence(c, &i, untilBrace: true)
        }
        if c[i] == "\\" { return parseCommand(c, &i) }
        let ch = c[i]
        i += 1
        return String(ch)
    }

    private static func parseCommand(_ c: [Character], _ i: inout Int) -> String {
        i += 1 // skip backslash
        guard i < c.count else { return "\\" }
        var name = ""
        if c[i].isASCII && c[i].isLetter {
            while i < c.count && c[i].isASCII && c[i].isLetter { name.append(c[i]); i += 1 }
        } else {
            name = String(c[i])
            i += 1
        }

        switch name {
        case "frac", "dfrac", "tfrac", "cfrac":
            let a = parseGroup(c, &i)
            let b = parseGroup(c, &i)
            return fraction(a, b)
        case "binom":
            let a = parseGroup(c, &i)
            let b = parseGroup(c, &i)
            return "(\(a) choose \(b))"
        case "sqrt":
            var index: String?
            if i < c.count, c[i] == "[", let close = c[i...].firstIndex(of: "]") {
                index = String(c[(i + 1)..<close])
                i = close + 1
            }
            let x = parseGroup(c, &i)
            let root: String
            switch index {
            case nil, "2"?: root = "√"
            case "3"?: root = "∛"
            case "4"?: root = "∜"
            case let n?: root = Scripts.superscript(n) + "√"
            }
            return root + (x.count == 1 ? x : "(\(x))")
        case "mathbb", "Bbb": return MathAlphabet.doubleStruck.apply(to: parseGroup(c, &i))
        case "mathcal", "mathscr": return MathAlphabet.script.apply(to: parseGroup(c, &i))
        case "mathfrak": return MathAlphabet.fraktur.apply(to: parseGroup(c, &i))
        case "mathbf", "boldsymbol", "bm", "textbf": return MathAlphabet.bold.apply(to: parseGroup(c, &i))
        case "mathit", "textit": return MathAlphabet.italic.apply(to: parseGroup(c, &i))
        case "mathsf", "textsf": return MathAlphabet.sans.apply(to: parseGroup(c, &i))
        case "mathtt", "texttt": return MathAlphabet.monospace.apply(to: parseGroup(c, &i))
        case "text", "mathrm", "textrm", "operatorname", "mbox", "mathnormal":
            return parseGroup(c, &i)
        case "vec", "overrightarrow": return CombiningMark.vector.apply(to: parseGroup(c, &i))
        case "overleftarrow": return CombiningMark.leftVector.apply(to: parseGroup(c, &i))
        case "hat", "widehat": return CombiningMark.hat.apply(to: parseGroup(c, &i))
        case "bar": return CombiningMark.bar.apply(to: parseGroup(c, &i))
        case "overline": return CombiningMark.overline.apply(to: parseGroup(c, &i))
        case "underline": return CombiningMark.underline.apply(to: parseGroup(c, &i))
        case "dot": return CombiningMark.dot.apply(to: parseGroup(c, &i))
        case "ddot": return CombiningMark.ddot.apply(to: parseGroup(c, &i))
        case "dddot": return CombiningMark.tdot.apply(to: parseGroup(c, &i))
        case "tilde", "widetilde": return CombiningMark.tilde.apply(to: parseGroup(c, &i))
        case "check": return CombiningMark.check.apply(to: parseGroup(c, &i))
        case "breve": return CombiningMark.breve.apply(to: parseGroup(c, &i))
        case "acute": return CombiningMark.acute.apply(to: parseGroup(c, &i))
        case "grave": return CombiningMark.grave.apply(to: parseGroup(c, &i))
        case "mathring": return CombiningMark.ring.apply(to: parseGroup(c, &i))
        case "cancel", "not": return CombiningMark.slash.apply(to: parseGroup(c, &i))
        case "boxed": return "[" + parseGroup(c, &i) + "]"
        case "ce": return ChemFormatter.formatText(parseGroup(c, &i))
        case "si", "unit": return ChemFormatter.formatUnits(parseGroup(c, &i))
        case "left", "right", "big", "Big", "bigg", "Bigg", "bigl", "bigr", "Bigl", "Bigr",
             "displaystyle", "textstyle", "limits", "nolimits", "middle":
            if i < c.count, c[i] == "." { i += 1 }
            return ""
        default:
            if let s = symbols[name] { return s }
            if functionNames.contains(name) { return name }
            return "\\" + name
        }
    }
}
