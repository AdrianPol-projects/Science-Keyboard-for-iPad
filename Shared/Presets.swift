import Foundation

enum PresetFieldKind: Codable, Hashable {
    case element
    case integer
    case number
    case charge
    case text
    case choice([String])

    var title: String {
        switch self {
        case .element: return "Element"
        case .integer: return "Integer"
        case .number: return "Number"
        case .charge: return "Charge"
        case .text: return "Text"
        case .choice: return "Choice"
        }
    }
}

struct PresetField: Codable, Hashable, Identifiable {
    var key: String
    var label: String
    var kind: PresetFieldKind
    /// Expression evaluated against earlier fields, e.g. "el.Z".
    var defaultExpression: String?
    var optional: Bool = false

    var id: String { key }
}

/// A step-by-step builder. The template uses `{expression:modifier}` tokens, e.g.
/// `{A:sup}{Z:sub}{el}` → ²³⁸₉₂U. See `PresetEngine` for the full syntax.
struct Preset: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var category: String
    var fields: [PresetField]
    var template: String
    var example: String = ""
    var isCustom: Bool = false
}

enum PresetEngine {
    static let modifiers: [(name: String, help: String)] = [
        ("sup", "superscript"), ("sub", "subscript"), ("charge", "ion charge: 2- → ²⁻"),
        ("chem", "chemical formula: H2O → H₂O"), ("units", "unit exponents: m/s2 → m/s²"),
        ("sci", "scientific notation"), ("latex", "LaTeX → Unicode"),
        ("bold", "𝐛𝐨𝐥𝐝"), ("italic", "𝑖𝑡𝑎𝑙𝑖𝑐"), ("script", "𝓈𝒸𝓇𝒾𝓅𝓉"), ("frak", "𝔣𝔯𝔞𝔨"),
        ("bb", "𝕕𝕠𝕦𝕓𝕝𝕖"), ("sans", "𝗌𝖺𝗇𝗌"), ("mono", "𝚖𝚘𝚗𝚘"),
        ("vec", "v⃗"), ("hat", "x̂"), ("bar", "x̄"), ("dot", "ẋ"), ("ddot", "ẍ"), ("tilde", "x̃"),
        ("upper", "UPPER"), ("lower", "lower"),
    ]

    static func variables(for preset: Preset, values: [String: String]) -> [String: ExprValue] {
        var vars: [String: ExprValue] = [:]
        for field in preset.fields {
            let raw = values[field.key] ?? ""
            switch field.kind {
            case .element:
                if let e = PeriodicTable.element(symbol: raw) {
                    vars[field.key] = .string(e.symbol)
                    vars[field.key + ".symbol"] = .string(e.symbol)
                    vars[field.key + ".Z"] = .number(Double(e.number))
                    vars[field.key + ".A"] = .number(Double(e.massNumber))
                    vars[field.key + ".name"] = .string(e.name)
                    vars[field.key + ".mass"] = .number(e.mass)
                    vars[field.key + ".config"] = .string(e.configuration)
                } else {
                    vars[field.key] = .string(raw)
                }
            case .integer, .number:
                if let d = Double(raw.replacingOccurrences(of: "−", with: "-")) {
                    vars[field.key] = .number(d)
                } else {
                    vars[field.key] = .string(raw)
                }
            case .charge, .text, .choice:
                vars[field.key] = .string(raw)
            }
        }
        return vars
    }

    static func defaultValue(for field: PresetField, in preset: Preset, values: [String: String]) -> String {
        if case .choice(let options) = field.kind, field.defaultExpression == nil {
            return options.first ?? ""
        }
        guard let expr = field.defaultExpression, !expr.isEmpty else { return "" }
        let evaluator = ExpressionEvaluator(variables: variables(for: preset, values: values))
        return (try? evaluator.evaluate(expr).text) ?? ""
    }

    static func render(_ preset: Preset, values: [String: String]) -> String {
        renderTemplate(preset.template, variables: variables(for: preset, values: values))
    }

    static func renderTemplate(_ template: String, variables: [String: ExprValue]) -> String {
        let chars = Array(template)
        var out = ""
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "{" {
                if i + 1 < chars.count && chars[i + 1] == "{" {
                    out.append("{"); i += 2; continue
                }
                guard let close = chars[(i + 1)...].firstIndex(of: "}") else {
                    out += String(chars[i...]); break
                }
                out += evaluateToken(String(chars[(i + 1)..<close]), variables: variables)
                i = close + 1
                continue
            }
            if c == "}" && i + 1 < chars.count && chars[i + 1] == "}" {
                out.append("}"); i += 2; continue
            }
            out.append(c)
            i += 1
        }
        return out
    }

    static func evaluateToken(_ token: String, variables: [String: ExprValue]) -> String {
        var expr = token
        var modifier: String?
        if let colon = token.lastIndex(of: ":"), !token[colon...].contains("\"") {
            let mod = String(token[token.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            if modifiers.contains(where: { $0.name == mod }) {
                modifier = mod
                expr = String(token[..<colon])
            }
        }
        let evaluator = ExpressionEvaluator(variables: variables)
        guard let value = try? evaluator.evaluate(expr) else { return "" }
        return apply(modifier, to: value)
    }

    static func apply(_ modifier: String?, to value: ExprValue) -> String {
        let text = value.text
        switch modifier {
        case "sup"?: return Scripts.superscript(text)
        case "sub"?: return Scripts.subscripted(text)
        case "charge"?: return Scripts.charge(text)
        case "chem"?: return ChemFormatter.formatText(text)
        case "units"?: return ChemFormatter.formatUnits(text)
        case "sci"?: return value.asNumber.map { NumberFormat.scientific($0) } ?? text
        case "latex"?: return LatexConverter.convert(text)
        case "bold"?: return MathAlphabet.bold.apply(to: text)
        case "italic"?: return MathAlphabet.italic.apply(to: text)
        case "script"?: return MathAlphabet.script.apply(to: text)
        case "frak"?: return MathAlphabet.fraktur.apply(to: text)
        case "bb"?: return MathAlphabet.doubleStruck.apply(to: text)
        case "sans"?: return MathAlphabet.sans.apply(to: text)
        case "mono"?: return MathAlphabet.monospace.apply(to: text)
        case "vec"?: return CombiningMark.vector.apply(to: text)
        case "hat"?: return CombiningMark.hat.apply(to: text)
        case "bar"?: return CombiningMark.bar.apply(to: text)
        case "dot"?: return CombiningMark.dot.apply(to: text)
        case "ddot"?: return CombiningMark.ddot.apply(to: text)
        case "tilde"?: return CombiningMark.tilde.apply(to: text)
        case "upper"?: return text.uppercased()
        case "lower"?: return text.lowercased()
        default: return text
        }
    }

    /// Renders the preset with all defaults filled in, for previews.
    static func sample(_ preset: Preset, element: String = "U") -> String {
        var values: [String: String] = [:]
        for field in preset.fields {
            if case .element = field.kind {
                values[field.key] = element
            } else {
                values[field.key] = defaultValue(for: field, in: preset, values: values)
            }
        }
        return render(preset, values: values)
    }
}

// MARK: - Built-in library

enum PresetLibrary {
    static let categories = ["Chemistry", "Physics", "Math", "Custom"]

    private static func el(_ label: String = "Element") -> PresetField {
        PresetField(key: "el", label: label, kind: .element)
    }
    private static let protons = PresetField(key: "Z", label: "Proton number (Z)", kind: .integer, defaultExpression: "el.Z")
    private static let massNumber = PresetField(key: "A", label: "Mass / nucleon number (A)", kind: .integer, defaultExpression: "el.A")
    private static func text(_ key: String, _ label: String, _ def: String? = nil, optional: Bool = false) -> PresetField {
        PresetField(key: key, label: label, kind: .text, defaultExpression: def.map { "\"\($0)\"" }, optional: optional)
    }
    private static func num(_ key: String, _ label: String, _ def: String? = nil) -> PresetField {
        PresetField(key: key, label: label, kind: .number, defaultExpression: def)
    }
    private static func int(_ key: String, _ label: String, _ def: String? = nil) -> PresetField {
        PresetField(key: key, label: label, kind: .integer, defaultExpression: def)
    }

    static let builtIn: [Preset] = chemistry + physics + math

    static let chemistry: [Preset] = [
        Preset(id: "nuclide", name: "Nuclide notation", category: "Chemistry",
               fields: [el(), protons, massNumber,
                        PresetField(key: "q", label: "Charge (optional)", kind: .charge, optional: true)],
               template: "{A:sup}{Z:sub}{el}{q:charge}", example: "²³⁸₉₂U"),
        Preset(id: "isotope", name: "Isotope (mass only)", category: "Chemistry",
               fields: [el(), massNumber], template: "{A:sup}{el}", example: "¹⁴C"),
        Preset(id: "isotopeName", name: "Isotope name", category: "Chemistry",
               fields: [el(), massNumber], template: "{el.name}-{A}", example: "Uranium-235"),
        Preset(id: "ion", name: "Ion", category: "Chemistry",
               fields: [el(), PresetField(key: "q", label: "Charge", kind: .charge, defaultExpression: "\"2+\"")],
               template: "{el}{q:charge}", example: "Fe³⁺"),
        Preset(id: "formula", name: "Chemical formula", category: "Chemistry",
               fields: [text("f", "Formula (e.g. Ca(OH)2, SO4^2-, CuSO4.5H2O)", "H2SO4")],
               template: "{f:chem}", example: "H₂SO₄"),
        Preset(id: "reaction", name: "Reaction", category: "Chemistry",
               fields: [text("r", "Reactants", "2H2 + O2"), text("p", "Products", "2H2O")],
               template: "{r:chem} → {p:chem}", example: "2H₂ + O₂ → 2H₂O"),
        Preset(id: "equilibrium", name: "Equilibrium", category: "Chemistry",
               fields: [text("r", "Reactants", "N2 + 3H2"), text("p", "Products", "2NH3")],
               template: "{r:chem} ⇌ {p:chem}", example: "N₂ + 3H₂ ⇌ 2NH₃"),
        Preset(id: "alpha", name: "α decay", category: "Chemistry",
               fields: [el("Parent nuclide"), protons, massNumber],
               template: "{A:sup}{Z:sub}{el} → {A-4:sup}{Z-2:sub}{sym(Z-2)} + ⁴₂He", example: "²³⁸₉₂U → ²³⁴₉₀Th + ⁴₂He"),
        Preset(id: "betaMinus", name: "β⁻ decay", category: "Chemistry",
               fields: [el("Parent nuclide"), protons, massNumber],
               template: "{A:sup}{Z:sub}{el} → {A:sup}{Z+1:sub}{sym(Z+1)} + ⁰₋₁e + ν̄ₑ", example: "¹⁴₆C → ¹⁴₇N + ⁰₋₁e + ν̄ₑ"),
        Preset(id: "betaPlus", name: "β⁺ decay", category: "Chemistry",
               fields: [el("Parent nuclide"), protons, massNumber],
               template: "{A:sup}{Z:sub}{el} → {A:sup}{Z-1:sub}{sym(Z-1)} + ⁰₊₁e + νₑ", example: "²²₁₁Na → ²²₁₀Ne + ⁰₊₁e + νₑ"),
        Preset(id: "ec", name: "Electron capture", category: "Chemistry",
               fields: [el("Parent nuclide"), protons, massNumber],
               template: "{A:sup}{Z:sub}{el} + ⁰₋₁e → {A:sup}{Z-1:sub}{sym(Z-1)} + νₑ", example: "⁴⁰₁₉K + ⁰₋₁e → ⁴⁰₁₈Ar + νₑ"),
        Preset(id: "gamma", name: "γ emission", category: "Chemistry",
               fields: [el("Nuclide"), protons, massNumber],
               template: "{A:sup}{Z:sub}{el}* → {A:sup}{Z:sub}{el} + γ", example: "⁶⁰₂₈Ni* → ⁶⁰₂₈Ni + γ"),
        Preset(id: "config", name: "Electron configuration", category: "Chemistry",
               fields: [el()], template: "{el}: {el.config}", example: "Fe: [Ar] 3d⁶ 4s²"),
        Preset(id: "fullconfig", name: "Full electron configuration", category: "Chemistry",
               fields: [el()], template: "{fullconfig(el.Z)}", example: "1s² 2s² 2p⁶ …"),
        Preset(id: "molarMass", name: "Molar mass", category: "Chemistry",
               fields: [el()], template: "M({el}) = {el.mass} g·mol⁻¹", example: "M(Fe) = 55.845 g·mol⁻¹"),
        Preset(id: "concentration", name: "Concentration", category: "Chemistry",
               fields: [text("s", "Species", "Na+"), num("c", "Concentration (mol/L)", "0.1")],
               template: "[{s:chem}] = {c} mol·L⁻¹", example: "[Na⁺] = 0.1 mol·L⁻¹"),
        Preset(id: "pH", name: "pH from [H₃O⁺]", category: "Chemistry",
               fields: [num("c", "[H₃O⁺] in mol/L", "0.001")],
               template: "pH = −log₁₀({c}) = {round(-log(c), 2)}", example: "pH = −log₁₀(0.001) = 3"),
        Preset(id: "enthalpy", name: "Enthalpy change", category: "Chemistry",
               fields: [PresetField(key: "k", label: "Type", kind: .choice(["r", "f", "c", "vap", "fus", "sol"])),
                        num("v", "Value (kJ/mol)", "-285.8")],
               template: "Δ{k}H° = {v} kJ·mol⁻¹", example: "ΔfH° = −285.8 kJ·mol⁻¹"),
        Preset(id: "state", name: "Species with state", category: "Chemistry",
               fields: [text("f", "Formula", "NaCl"),
                        PresetField(key: "s", label: "State", kind: .choice(["aq", "s", "l", "g"]))],
               template: "{f:chem}({s})", example: "NaCl(aq)"),
    ]

    static let physics: [Preset] = [
        Preset(id: "sci", name: "Scientific notation", category: "Physics",
               fields: [num("m", "Mantissa", "6.022"), int("e", "Power of ten", "23")],
               template: "{m} × 10{e:sup}", example: "6.022 × 10²³"),
        Preset(id: "quantity", name: "Quantity with unit", category: "Physics",
               fields: [num("v", "Value", "9.81"),
                        PresetField(key: "p", label: "Prefix", kind: .choice(["", "k", "M", "G", "T", "m", "µ", "n", "p", "f", "c", "d"])),
                        PresetField(key: "u", label: "Unit", kind: .choice(["m", "s", "kg", "g", "N", "J", "W", "Pa", "Hz", "V", "A", "Ω", "C", "F", "T", "H", "K", "mol", "eV", "L", "Wb", "S", "Bq", "Gy", "Sv", "cd", "lm", "lx"]))],
               template: "{v} {p}{u}", example: "9.81 m"),
        Preset(id: "unitPower", name: "Unit with exponent", category: "Physics",
               fields: [text("u", "Units (e.g. kg*m*s-2, J mol-1 K-1)", "m/s2")],
               template: "{u:units}", example: "m/s²"),
        Preset(id: "vector", name: "Vector", category: "Physics",
               fields: [text("v", "Symbol", "F")], template: "{v:vec}", example: "F⃗"),
        Preset(id: "unitVector", name: "Unit vector", category: "Physics",
               fields: [text("v", "Symbol", "r")], template: "{v:hat}", example: "r̂"),
        Preset(id: "components", name: "Vector components", category: "Physics",
               fields: [num("x", "x", "1"), num("y", "y", "0"), num("z", "z", "0")],
               template: "⟨{x}, {y}, {z}⟩", example: "⟨1, 0, 0⟩"),
        Preset(id: "timeDeriv", name: "Time derivative ẋ", category: "Physics",
               fields: [text("x", "Variable", "x")], template: "{x:dot}", example: "ẋ"),
        Preset(id: "timeDeriv2", name: "Second time derivative ẍ", category: "Physics",
               fields: [text("x", "Variable", "x")], template: "{x:ddot}", example: "ẍ"),
        Preset(id: "uncertainty", name: "Value ± uncertainty", category: "Physics",
               fields: [num("v", "Value", "9.81"), num("u", "Uncertainty", "0.02"), text("unit", "Unit", "m/s2", optional: true)],
               template: "({v} ± {u}) {unit:units}", example: "(9.81 ± 0.02) m/s²"),
        Preset(id: "ke", name: "Kinetic energy (computed)", category: "Physics",
               fields: [num("m", "Mass (kg)", "2"), num("v", "Speed (m/s)", "3")],
               template: "Eₖ = ½·{m} kg·({v} m/s)² = {0.5*m*v^2} J", example: "Eₖ = ½·2 kg·(3 m/s)² = 9 J"),
        Preset(id: "photon", name: "Photon energy from λ", category: "Physics",
               fields: [num("l", "Wavelength (nm)", "500")],
               template: "E = hc/λ = {h*c/(l*1e-9):sci} J = {h*c/(l*1e-9)/qe:sci} eV", example: "E = 3.973 × 10⁻¹⁹ J"),
        Preset(id: "ket", name: "Ket |ψ⟩", category: "Physics",
               fields: [text("a", "State", "ψ")], template: "|{a}⟩", example: "|ψ⟩"),
        Preset(id: "braket", name: "Bra-ket ⟨φ|ψ⟩", category: "Physics",
               fields: [text("a", "Bra", "φ"), text("b", "Ket", "ψ")], template: "⟨{a}|{b}⟩", example: "⟨φ|ψ⟩"),
        Preset(id: "expect", name: "Expectation value", category: "Physics",
               fields: [text("a", "Operator", "Ĥ"), text("s", "State", "ψ")],
               template: "⟨{s}|{a}|{s}⟩", example: "⟨ψ|Ĥ|ψ⟩"),
        Preset(id: "subscripted", name: "Symbol with subscript", category: "Physics",
               fields: [text("s", "Symbol", "E"), text("i", "Subscript", "k")], template: "{s}{i:sub}", example: "Eₖ"),
    ]

    static let math: [Preset] = [
        Preset(id: "fraction", name: "Fraction", category: "Math",
               fields: [text("n", "Numerator", "1"), text("d", "Denominator", "2")],
               template: "{n:sup}⁄{d:sub}", example: "¹⁄₂"),
        Preset(id: "power", name: "Power", category: "Math",
               fields: [text("b", "Base", "x"), text("e", "Exponent", "2")], template: "{b}{e:sup}", example: "x²"),
        Preset(id: "index", name: "Subscript / index", category: "Math",
               fields: [text("b", "Base", "a"), text("i", "Index", "n")], template: "{b}{i:sub}", example: "aₙ"),
        Preset(id: "root", name: "n-th root", category: "Math",
               fields: [int("n", "Degree", "3"), text("x", "Radicand", "x")], template: "{root(n)}({x})", example: "∛(x)"),
        Preset(id: "log", name: "Logarithm with base", category: "Math",
               fields: [text("b", "Base", "2"), text("x", "Argument", "x")], template: "log{b:sub}({x})", example: "log₂(x)"),
        Preset(id: "integral", name: "Definite integral", category: "Math",
               fields: [text("a", "Lower limit", "0"), text("b", "Upper limit", "∞"),
                        text("f", "Integrand", "f(x)"), text("x", "Variable", "x")],
               template: "∫{a:sub}{b:sup} {f} d{x}", example: "∫₀∞ f(x) dx"),
        Preset(id: "sum", name: "Summation", category: "Math",
               fields: [text("i", "Index", "n"), text("lo", "From", "1"), text("hi", "To", "∞"), text("f", "Term", "aₙ")],
               template: "∑{i + \"=\" + lo:sub}{hi:sup} {f}", example: "∑ₙ₌₁∞ aₙ"),
        Preset(id: "product", name: "Product", category: "Math",
               fields: [text("i", "Index", "k"), text("lo", "From", "1"), text("hi", "To", "n"), text("f", "Factor", "k")],
               template: "∏{i + \"=\" + lo:sub}{hi:sup} {f}", example: "∏ₖ₌₁ⁿ k"),
        Preset(id: "limit", name: "Limit", category: "Math",
               fields: [text("x", "Variable", "x"), text("a", "Approaches", "0"), text("f", "Function", "sin(x)/x")],
               template: "lim({x}→{a}) {f}", example: "lim(x→0) sin(x)/x"),
        Preset(id: "derivative", name: "Derivative", category: "Math",
               fields: [text("f", "Function", "f"), text("x", "Variable", "x"), int("n", "Order", "1")],
               template: "{if(eq(n, 1), \"d\" + f + \"/d\" + x, \"d\" + sup(n) + f + \"/d\" + x + sup(n))}", example: "df/dx"),
        Preset(id: "partial", name: "Partial derivative", category: "Math",
               fields: [text("f", "Function", "f"), text("x", "Variable", "x")], template: "∂{f}/∂{x}", example: "∂f/∂x"),
        Preset(id: "matrix", name: "2×2 matrix", category: "Math",
               fields: [text("a", "a₁₁", "a"), text("b", "a₁₂", "b"), text("c", "a₂₁", "c"), text("d", "a₂₂", "d")],
               template: "⎡{a} {b}⎤\n⎣{c} {d}⎦", example: "⎡a b⎤ ⎣c d⎦"),
        Preset(id: "det", name: "2×2 determinant (computed)", category: "Math",
               fields: [num("a", "a", "1"), num("b", "b", "2"), num("c", "c", "3"), num("d", "d", "4")],
               template: "det = {a}·{d} − {b}·{c} = {a*d-b*c}", example: "det = −2"),
        Preset(id: "binomial", name: "Binomial coefficient", category: "Math",
               fields: [int("n", "n", "5"), int("k", "k", "2")], template: "C({n}, {k}) = {nCr(n, k)}", example: "C(5, 2) = 10"),
        Preset(id: "quadratic", name: "Quadratic roots", category: "Math",
               fields: [num("a", "a", "1"), num("b", "b", "-3"), num("c", "c", "2")],
               template: "x = {(-b+sqrt(b^2-4*a*c))/(2*a)}, x = {(-b-sqrt(b^2-4*a*c))/(2*a)}", example: "x = 2, x = 1"),
        Preset(id: "set", name: "Set-builder", category: "Math",
               fields: [text("x", "Element", "x"),
                        PresetField(key: "S", label: "Set", kind: .choice(["R", "N", "Z", "Q", "C"])),
                        text("p", "Condition", "x > 0")],
               template: "{{ {x} ∈ {S:bb} | {p} }}", example: "{ x ∈ ℝ | x > 0 }"),
        Preset(id: "complex", name: "Complex number", category: "Math",
               fields: [num("a", "Real part", "3"), num("b", "Imaginary part", "4")],
               template: "{a} + {b}i  (|z| = {hypot(a, b)})", example: "3 + 4i  (|z| = 5)"),
        Preset(id: "norm", name: "Norm", category: "Math",
               fields: [text("v", "Vector", "v")], template: "‖{v:vec}‖", example: "‖v⃗‖"),
        Preset(id: "latex", name: "LaTeX → Unicode", category: "Math",
               fields: [text("t", "LaTeX", "\\sum_{n=1}^{N} \\alpha_n")], template: "{t:latex}", example: "∑ₙ₌₁ᴺ αₙ"),
    ]
}
