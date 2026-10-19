import Foundation

struct SymbolSection: Identifiable {
    let id: String
    let title: String
    let items: [String]
}

struct SymbolCategory: Identifiable {
    let id: String
    let title: String
    let glyph: String
    let sections: [SymbolSection]
}

struct UnicodeBlock: Identifiable {
    let name: String
    let range: ClosedRange<UInt32>
    var id: String { name }
    var items: [String] { SymbolCatalog.scalars(range) }
}

enum SymbolCatalog {
    /// Splits a string into single characters, ignoring spaces.
    static func chars(_ s: String) -> [String] {
        s.filter { $0 != " " }.map { String($0) }
    }

    /// Splits on spaces, for multi-character items.
    static func words(_ s: String) -> [String] {
        s.split(separator: " ").map(String.init)
    }

    /// All assigned, visible scalars in a range.
    static func scalars(_ range: ClosedRange<UInt32>) -> [String] {
        range.compactMap { v -> String? in
            guard let s = Unicode.Scalar(v) else { return nil }
            switch s.properties.generalCategory {
            case .unassigned, .control, .format, .surrogate, .privateUse,
                 .lineSeparator, .paragraphSeparator, .spaceSeparator:
                return nil
            default:
                return String(Character(s))
            }
        }
    }

    private static func section(_ id: String, _ title: String, _ items: [String]) -> SymbolSection {
        SymbolSection(id: id, title: title, items: items)
    }

    private static func block(_ id: String, _ title: String, _ range: ClosedRange<UInt32>) -> SymbolSection {
        SymbolSection(id: id, title: title, items: scalars(range))
    }

    static let combiningMarks: [String] = CombiningMark.allCases.map(\.rawValue)

    // MARK: Categories

    static let greek = SymbolCategory(id: "greek", title: "Greek", glyph: "αβ", sections: [
        section("greek.lower", "Lowercase", chars("α β γ δ ε ζ η θ ι κ λ μ ν ξ ο π ρ σ ς τ υ φ χ ψ ω")),
        section("greek.upper", "Uppercase", chars("Α Β Γ Δ Ε Ζ Η Θ Ι Κ Λ Μ Ν Ξ Ο Π Ρ Σ Τ Υ Φ Χ Ψ Ω")),
        section("greek.variants", "Variants", chars("ϵ ϑ ϰ ϕ ϱ ϖ ϐ ϒ ϴ ϝ Ϝ ϟ Ϟ ϡ Ϡ ϻ ͱ ϶ ∂ ∇ ℧ µ")),
        section("greek.bold", "Bold", chars(MathAlphabet.bold.apply(to: "αβγδεζηθικλμνξοπρστυφχψω ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ"))),
        section("greek.italic", "Italic", chars(MathAlphabet.italic.apply(to: "αβγδεζηθικλμνξοπρστυφχψω ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ"))),
        section("greek.bolditalic", "Bold italic", chars(MathAlphabet.boldItalic.apply(to: "αβγδεζηθικλμνξοπρστυφχψω ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ"))),
        block("greek.block", "Greek and Coptic block", 0x0370...0x03FF),
        block("greek.ext", "Greek Extended", 0x1F00...0x1FFF),
    ])

    static let math = SymbolCategory(id: "math", title: "Math", glyph: "±", sections: [
        section("math.basic", "Basic", chars("+ − × ÷ ± ∓ = ≠ ≈ ≡ < > ≤ ≥ ≪ ≫ ∝ ∞ · ∘ √ ∛ ∜ % ‰ ‱ ′ ″ ‴ ° ∗ ∕ ⁄ ∣ ∤ ‖")),
        section("math.relations", "Relations", chars("≅ ≃ ∼ ≁ ≆ ≇ ≉ ≊ ≋ ≍ ≐ ≑ ≒ ≓ ≔ ≕ ≖ ≗ ≘ ≙ ≚ ≜ ≝ ≞ ≟ ≢ ≦ ≧ ≨ ≩ ⩽ ⩾ ≲ ≳ ≺ ≻ ≼ ≽ ⊲ ⊳ ⊴ ⊵ ≮ ≯ ≰ ≱")),
        section("math.sets", "Sets", chars("∈ ∉ ∋ ∌ ⊂ ⊃ ⊆ ⊇ ⊄ ⊅ ⊊ ⊋ ⊈ ⊉ ∩ ∪ ∖ ∅ ∁ ⊎ ⊓ ⊔ ⋂ ⋃ ℘ ℵ ℶ ℷ ℕ ℤ ℚ ℝ ℂ ℍ ℙ 𝔽 𝕂 𝟙")),
        section("math.logic", "Logic", chars("∀ ∃ ∄ ¬ ∧ ∨ ⊻ ⊼ ⊽ ⇒ ⇐ ⇔ ⟹ ⟸ ⟺ ⊢ ⊣ ⊨ ⊭ ⊤ ⊥ ∴ ∵ ∎ □ ◇ ⊕ ⊗ ⊙ ⊖ ⊘ ⊚ ⊛ ⊜ ⊝")),
        section("math.brackets", "Brackets", chars("( ) [ ] { } ⟨ ⟩ ⌈ ⌉ ⌊ ⌋ ‖ ⟦ ⟧ ⦃ ⦄ ⟮ ⟯ ⦅ ⦆ ⦇ ⦈ ⎡ ⎤ ⎢ ⎥ ⎣ ⎦ ⎛ ⎞ ⎜ ⎟ ⎝ ⎠ ⎧ ⎫ ⎨ ⎬ ⎩ ⎭ ⎪ ⎰ ⎱ ⌜ ⌝ ⌞ ⌟")),
        section("math.fractions", "Fractions", chars("½ ⅓ ⅔ ¼ ¾ ⅕ ⅖ ⅗ ⅘ ⅙ ⅚ ⅐ ⅛ ⅜ ⅝ ⅞ ⅑ ⅒ ↉ ⁄")),
        section("math.geometry", "Geometry", chars("∠ ∡ ∢ ⊾ ⟂ ∥ ∦ △ ▲ ▽ □ ■ ▭ ▱ ○ ● ◯ ◇ ◆ ⬠ ⬡ ⌀ ° ′ ″ ≅ ∼ ⊥ ⌒ ⏜ ⏝")),
        section("math.functions", "Functions", words("sin cos tan cot sec csc arcsin arccos arctan sinh cosh tanh ln log exp lim max min sup inf det dim ker arg gcd lcm mod Re Im tr rank sgn")),
        section("math.misc", "Miscellaneous", chars("∂ ∇ ∆ ∑ ∏ ∐ ∫ ∮ ℓ ℏ ℵ ⅈ ⅉ ⅇ ⅆ ⅅ ⅀ ℼ ℽ ℾ ℿ ∟ ⊹ ⋆ ⋄ ∶ ∷ ∺ ∻ ⋮ ⋯ ⋰ ⋱ …")),
        block("math.ops", "Mathematical Operators", 0x2200...0x22FF),
        block("math.supp", "Supplemental Mathematical Operators", 0x2A00...0x2AFF),
        block("math.miscA", "Misc Mathematical Symbols-A", 0x27C0...0x27EF),
        block("math.miscB", "Misc Mathematical Symbols-B", 0x2980...0x29FF),
        block("math.tech", "Miscellaneous Technical", 0x2300...0x23FF),
    ])

    static let calculus = SymbolCategory(id: "calculus", title: "Calculus", glyph: "∫", sections: [
        section("calc.ops", "Operators", chars("d ∂ δ Δ ∇ ∫ ∬ ∭ ⨌ ∮ ∯ ∰ ∱ ∲ ∳ ⨍ ⨎ ⨏ ⨐ ⨑ ⨒ ⨓ ⨔ ⨕ ⨖ ⨗ ⨘ ⨙ ⨚ ⨛ ⨜ ∑ ∏ ∐ ⨁ ⨂ ⨀ ⋃ ⋂ ⋀ ⋁")),
        section("calc.notation", "Notation", words("lim → ∞ −∞ ∞ ′ ″ ‴ ẋ ẍ ḟ ∂ₜ ∂ₓ ∂ᵢ dx dy dz dt dV dA dS ∇² ∇· ∇× ∇f ∂/∂x ∂/∂t d/dx d²/dx² ∮ ⅆ ⅇ ⅈ")),
        section("calc.series", "Series", words("∑ₙ₌₀^∞ ∑ᵢ₌₁ⁿ ∏ᵢ₌₁ⁿ n! (2n)! xⁿ aₙ bₙ Sₙ ε δ O(n) o(n) ~ ≍ ⊂")),
        section("calc.transforms", "Transforms", words("ℒ ℱ 𝓕 𝓛 ℋ 𝒵 ∗ ⊛ ⋆ e^(iωt) δ(x) Θ(x) H(x) Γ(z) ζ(s) B(x,y)")),
    ])

    static let arrows = SymbolCategory(id: "arrows", title: "Arrows", glyph: "→", sections: [
        section("arr.common", "Common", chars("→ ← ↑ ↓ ↔ ↕ ⇒ ⇐ ⇔ ⇑ ⇓ ⇕ ⟶ ⟵ ⟷ ⟹ ⟸ ⟺ ↦ ↤ ⟼ ↪ ↩ ↗ ↘ ↙ ↖ ↻ ↺ ⤳ ↝ ↜ ⇝ ⇜")),
        section("arr.harpoons", "Harpoons & equilibria", chars("⇌ ⇋ ⇄ ⇆ ⇀ ⇁ ↼ ↽ ↾ ↿ ⇂ ⇃ ⥂ ⥄ ⥊ ⥋ ⥌ ⥍ ⥎ ⥏ ⥐ ⥑ ⇉ ⇇ ⇈ ⇊ ⇶ ⥮ ⥯")),
        block("arr.block", "Arrows", 0x2190...0x21FF),
        block("arr.suppA", "Supplemental Arrows-A", 0x27F0...0x27FF),
        block("arr.suppB", "Supplemental Arrows-B", 0x2900...0x297F),
        block("arr.misc", "Misc Symbols and Arrows", 0x2B00...0x2BFF),
    ])

    static let scripts = SymbolCategory(id: "scripts", title: "Super/Sub", glyph: "x²", sections: [
        section("sup.digits", "Superscript", chars("⁰ ¹ ² ³ ⁴ ⁵ ⁶ ⁷ ⁸ ⁹ ⁺ ⁻ ⁼ ⁽ ⁾ ⁿ ⁱ")),
        section("sup.letters", "Superscript letters", chars("ᵃ ᵇ ᶜ ᵈ ᵉ ᶠ ᵍ ʰ ⁱ ʲ ᵏ ˡ ᵐ ⁿ ᵒ ᵖ ʳ ˢ ᵗ ᵘ ᵛ ʷ ˣ ʸ ᶻ ᴬ ᴮ ᴰ ᴱ ᴳ ᴴ ᴵ ᴶ ᴷ ᴸ ᴹ ᴺ ᴼ ᴾ ᴿ ᵀ ᵁ ⱽ ᵂ ᵅ ᵝ ᵞ ᵟ ᵋ ᶿ ᶥ ᵠ ᵡ")),
        section("sub.digits", "Subscript", chars("₀ ₁ ₂ ₃ ₄ ₅ ₆ ₇ ₈ ₉ ₊ ₋ ₌ ₍ ₎")),
        section("sub.letters", "Subscript letters", chars("ₐ ₑ ₕ ᵢ ⱼ ₖ ₗ ₘ ₙ ₒ ₚ ᵣ ₛ ₜ ᵤ ᵥ ₓ ₔ ᵦ ᵧ ᵨ ᵩ ᵪ")),
        section("scripts.common", "Common combos", words("x² x³ xⁿ x⁻¹ e⁻ᵗ 10⁻³ 10⁶ m² m³ s⁻¹ s⁻² m·s⁻¹ m·s⁻² kg·m⁻³ mol⁻¹ K⁻¹ J·mol⁻¹ aₙ xᵢ x₀ v₀ t₁ t₂ H₂O CO₂ O₂ N₂")),
        block("scripts.block", "Superscripts and Subscripts block", 0x2070...0x209F),
        block("scripts.phon", "Phonetic Extensions (modifier letters)", 0x1D2C...0x1D6A),
    ])

    static let accents = SymbolCategory(id: "accents", title: "Accents", glyph: "x⃗", sections: [
        section("acc.marks", "Combining marks (applied to the previous letter)", combiningMarks),
        section("acc.ready", "Ready-made", chars("x̄ ȳ ẋ ẍ ẏ ÿ x̂ ŷ ẑ p̂ Ĥ â ê î ô û ñ x̃ ã õ å ů ǎ ě ǐ ǒ ǔ")),
        block("acc.symbols", "Combining Marks for Symbols", 0x20D0...0x20FF),
        block("acc.diacritics", "Combining Diacritical Marks", 0x0300...0x036F),
    ])

    static let chemistry = SymbolCategory(id: "chemistry", title: "Chemistry", glyph: "⚗︎", sections: [
        section("chem.arrows", "Reaction arrows", chars("→ ⟶ ⇌ ⇄ ⇋ ⥂ ⥄ ⟷ ↔ ← ↑ ↓ ⇒ ⟹ ↛ ↯ ⇅")),
        section("chem.charges", "Charges & numbers", words("⁺ ⁻ ²⁺ ²⁻ ³⁺ ³⁻ ⁴⁺ ⁴⁻ δ⁺ δ⁻ ₀ ₁ ₂ ₃ ₄ ₅ ₆ ₇ ₈ ₉ ⁰ ¹ ² ³")),
        section("chem.states", "States & conditions", words("(s) (l) (g) (aq) (cr) (am) Δ hν ‡ ° ⦵ ⊖ STP °C K atm kPa bar cat. Δ/H⁺")),
        section("chem.particles", "Particles", words("e⁻ e⁺ p⁺ n⁰ ⁴₂He ⁰₋₁e ⁰₊₁e ¹₀n ¹₁p ¹₁H ²₁H ³₁H α β⁻ β⁺ γ ν νₑ ν̄ₑ μ⁻ π⁺ π⁻")),
        section("chem.bonds", "Bonds & structure", chars("− = ≡ ⋯ · • : ⌬ ⏣ ⬡ ⬢ ⌇ ⫽ ∕ ⁄ ⦿ ⊙ ⇀ ⇁ ⥮ ↿ ⇂")),
        section("chem.common", "Common species", words("H₂O H₃O⁺ OH⁻ H⁺ CO₂ CO₃²⁻ HCO₃⁻ O₂ N₂ H₂ NH₃ NH₄⁺ CH₄ C₂H₅OH C₆H₁₂O₆ NaCl HCl H₂SO₄ SO₄²⁻ HNO₃ NO₃⁻ PO₄³⁻ CaCO₃ Fe²⁺ Fe³⁺ Cu²⁺ Ag⁺ Cl⁻ MnO₄⁻ Cr₂O₇²⁻ ATP NAD⁺ NADH")),
        section("chem.thermo", "Thermo & kinetics", words("ΔH ΔS ΔG ΔU ΔH° ΔG° ΔS° ΔfH° ΔrH° ΔcH° Kc Kp Ka Kb Kw Ksp pH pOH pKa Eₐ k[A]ⁿ t½ E° Ecell Q R·T·ln")),
        section("chem.alchemy", "Alchemical symbols", scalars(0x1F700...0x1F773)),
    ])

    static let physics = SymbolCategory(id: "physics", title: "Physics", glyph: "⚛︎", sections: [
        section("phys.symbols", "Symbols", chars("ℏ ħ λ μ ν ω Ω Φ φ Ψ ψ ε η ρ σ τ θ κ γ Γ α β χ ξ ζ ∂ ∇ ∮ ⊗ † ⟂ ∥ ° Å ℓ ℰ ℋ ℒ ℱ")),
        section("phys.quantum", "Quantum", words("⟨ ⟩ | ⟨ψ| |ψ⟩ ⟨ψ|ψ⟩ ⟨φ|ψ⟩ |0⟩ |1⟩ |+⟩ |−⟩ |↑⟩ |↓⟩ Ĥ p̂ x̂ L̂ Ŝ â â† ψ* ⊗ ⊕ † ℏω [x̂,p̂] iℏ ∣ ⟩⟨")),
        section("phys.vectors", "Vectors", words("F⃗ v⃗ a⃗ p⃗ r⃗ E⃗ B⃗ k⃗ x̂ ŷ ẑ r̂ θ̂ φ̂ î ĵ k̂ ∇· ∇× ∇² ‖v⃗‖ ⊥ ∥")),
        section("phys.mechanics", "Mechanics", words("Fₙ Fg Fₖ μₖ μₛ v₀ x₀ t₀ Δx Δt Δv ω₀ Eₖ Eₚ W P τ I L⃗ p⃗ g ẋ ẍ θ̇ θ̈")),
        section("phys.em", "Electromagnetism", words("ε₀ μ₀ ε_r μ_r Φ_B Φ_E ρ σ J⃗ I V R Ω C F L H ∮E·dl ∮B·dA ∇·E ∇·B ∇×E ∇×B")),
        section("phys.thermo", "Thermo & stat. mech.", words("k_B Nₐ T S U Q W Cᵥ Cₚ γ η Z ⟨E⟩ β=1/kT Ω e^(−E/kT) ln Ω")),
        section("phys.astro", "Astronomy", words("☉ M☉ R☉ L☉ ⊕ M⊕ R⊕ ☽ ☿ ♀ ♂ ♃ ♄ ♅ ♆ ⯓ AU ly pc H₀ z ★ ✦ ☄")),
        section("phys.nuclear", "Nuclear & particles", words("α β⁻ β⁺ γ n p e⁻ e⁺ ν ν̄ μ τ π⁰ π± K⁰ Λ Σ Ξ Ω⁻ q q̄ u d s c b t g W± Z⁰ H⁰ ☢ ☣ ⚛")),
        section("phys.units", "Unit symbols", words("Å µm nm pm fm km cm mm m² m³ ℓ mL L Hz kHz MHz GHz eV keV MeV GeV TeV J kJ MJ W kW MW Pa kPa MPa N kN V mV kV A mA µA Ω kΩ MΩ C µC nC F µF nF pF T mT G Wb H K °C °F mol M Bq Gy Sv rad sr cd lm lx dB")),
    ])

    static let letterlike = SymbolCategory(id: "letterlike", title: "Letters", glyph: "ℝ", sections: [
        block("ll.block", "Letterlike Symbols", 0x2100...0x214F),
        block("ll.number", "Number Forms", 0x2150...0x218F),
        block("ll.enclosed", "Enclosed Alphanumerics", 0x2460...0x24FF),
        block("ll.cjk", "Unit squares (CJK Compatibility)", 0x3380...0x33FF),
        block("ll.latin1", "Latin-1 Supplement", 0x00A0...0x00FF),
        block("ll.latinA", "Latin Extended-A", 0x0100...0x017F),
        block("ll.ipa", "IPA Extensions", 0x0250...0x02AF),
    ])

    static let shapes = SymbolCategory(id: "shapes", title: "Shapes", glyph: "◆", sections: [
        section("sh.marks", "Marks", chars("✓ ✔ ✗ ✘ ★ ☆ ✦ ✧ • ◦ ‣ ⁃ ∙ ⦿ ◉ ○ ● □ ■ ▢ ▣ ◇ ◆ ▲ △ ▼ ▽ ► ◄ ♠ ♣ ♥ ♦ ☐ ☑ ☒ ⚠ ☢ ☣ ⚛ ⚡ ♻")),
        section("sh.punct", "Punctuation & typography", chars("§ ¶ † ‡ • … ‰ ′ ″ ‹ › « » ¡ ¿ – — ‒ ― ‘ ’ “ ” „ ‚ © ® ™ ℗ № ⁂ ※ ⸮ ‽ ⁇ ⁈ ⁉")),
        section("sh.currency", "Currency", chars("$ € £ ¥ ¢ ₹ ₽ ₩ ₪ ₫ ₺ ₴ ₦ ₱ ₲ ₵ ₸ ₼ ₾ ₿ ¤ ฿")),
        block("sh.geo", "Geometric Shapes", 0x25A0...0x25FF),
        block("sh.geoExt", "Geometric Shapes Extended", 0x1F780...0x1F7D8),
        block("sh.misc", "Miscellaneous Symbols", 0x2600...0x26FF),
        block("sh.dingbats", "Dingbats", 0x2700...0x27BF),
        block("sh.box", "Box Drawing", 0x2500...0x257F),
        block("sh.blocks", "Block Elements", 0x2580...0x259F),
        block("sh.braille", "Braille Patterns", 0x2800...0x28FF),
    ])

    static let all: [SymbolCategory] = [greek, math, calculus, arrows, scripts, accents, chemistry, physics, letterlike, shapes]

    static func category(_ id: String) -> SymbolCategory? {
        all.first { $0.id == id }
    }

    // MARK: Unicode blocks (the "everything" browser)

    static let blocks: [UnicodeBlock] = [
        UnicodeBlock(name: "Latin-1 Supplement", range: 0x00A0...0x00FF),
        UnicodeBlock(name: "Latin Extended-A", range: 0x0100...0x017F),
        UnicodeBlock(name: "Latin Extended-B", range: 0x0180...0x024F),
        UnicodeBlock(name: "IPA Extensions", range: 0x0250...0x02AF),
        UnicodeBlock(name: "Spacing Modifier Letters", range: 0x02B0...0x02FF),
        UnicodeBlock(name: "Combining Diacritical Marks", range: 0x0300...0x036F),
        UnicodeBlock(name: "Greek and Coptic", range: 0x0370...0x03FF),
        UnicodeBlock(name: "Cyrillic", range: 0x0400...0x04FF),
        UnicodeBlock(name: "Hebrew", range: 0x0590...0x05FF),
        UnicodeBlock(name: "Phonetic Extensions", range: 0x1D00...0x1D7F),
        UnicodeBlock(name: "Phonetic Extensions Supplement", range: 0x1D80...0x1DBF),
        UnicodeBlock(name: "Greek Extended", range: 0x1F00...0x1FFF),
        UnicodeBlock(name: "General Punctuation", range: 0x2000...0x206F),
        UnicodeBlock(name: "Superscripts and Subscripts", range: 0x2070...0x209F),
        UnicodeBlock(name: "Currency Symbols", range: 0x20A0...0x20CF),
        UnicodeBlock(name: "Combining Marks for Symbols", range: 0x20D0...0x20FF),
        UnicodeBlock(name: "Letterlike Symbols", range: 0x2100...0x214F),
        UnicodeBlock(name: "Number Forms", range: 0x2150...0x218F),
        UnicodeBlock(name: "Arrows", range: 0x2190...0x21FF),
        UnicodeBlock(name: "Mathematical Operators", range: 0x2200...0x22FF),
        UnicodeBlock(name: "Miscellaneous Technical", range: 0x2300...0x23FF),
        UnicodeBlock(name: "Control Pictures", range: 0x2400...0x243F),
        UnicodeBlock(name: "Optical Character Recognition", range: 0x2440...0x245F),
        UnicodeBlock(name: "Enclosed Alphanumerics", range: 0x2460...0x24FF),
        UnicodeBlock(name: "Box Drawing", range: 0x2500...0x257F),
        UnicodeBlock(name: "Block Elements", range: 0x2580...0x259F),
        UnicodeBlock(name: "Geometric Shapes", range: 0x25A0...0x25FF),
        UnicodeBlock(name: "Miscellaneous Symbols", range: 0x2600...0x26FF),
        UnicodeBlock(name: "Dingbats", range: 0x2700...0x27BF),
        UnicodeBlock(name: "Misc Mathematical Symbols-A", range: 0x27C0...0x27EF),
        UnicodeBlock(name: "Supplemental Arrows-A", range: 0x27F0...0x27FF),
        UnicodeBlock(name: "Braille Patterns", range: 0x2800...0x28FF),
        UnicodeBlock(name: "Supplemental Arrows-B", range: 0x2900...0x297F),
        UnicodeBlock(name: "Misc Mathematical Symbols-B", range: 0x2980...0x29FF),
        UnicodeBlock(name: "Supplemental Mathematical Operators", range: 0x2A00...0x2AFF),
        UnicodeBlock(name: "Misc Symbols and Arrows", range: 0x2B00...0x2BFF),
        UnicodeBlock(name: "Latin Extended-C", range: 0x2C60...0x2C7F),
        UnicodeBlock(name: "Supplemental Punctuation", range: 0x2E00...0x2E7F),
        UnicodeBlock(name: "CJK Compatibility", range: 0x3300...0x33FF),
        UnicodeBlock(name: "Latin Extended-D", range: 0xA720...0xA7FF),
        UnicodeBlock(name: "Small Form Variants", range: 0xFE50...0xFE6F),
        UnicodeBlock(name: "Halfwidth and Fullwidth Forms", range: 0xFF00...0xFFEF),
        UnicodeBlock(name: "Musical Symbols", range: 0x1D100...0x1D1FF),
        UnicodeBlock(name: "Mathematical Alphanumeric Symbols", range: 0x1D400...0x1D7FF),
        UnicodeBlock(name: "Enclosed Alphanumeric Supplement", range: 0x1F100...0x1F1FF),
        UnicodeBlock(name: "Alchemical Symbols", range: 0x1F700...0x1F77F),
        UnicodeBlock(name: "Geometric Shapes Extended", range: 0x1F780...0x1F7FF),
        UnicodeBlock(name: "Supplemental Arrows-C", range: 0x1F800...0x1F8FF),
    ]
}

// MARK: - Physics data

struct PhysicalConstant: Identifiable {
    let name: String
    let symbol: String
    let value: String
    let unit: String
    var id: String { name }
    var full: String { unit.isEmpty ? "\(symbol) = \(value)" : "\(symbol) = \(value) \(unit)" }
}

enum PhysicsData {
    static let constants: [PhysicalConstant] = [
        PhysicalConstant(name: "Speed of light", symbol: "c", value: "299 792 458", unit: "m·s⁻¹"),
        PhysicalConstant(name: "Planck constant", symbol: "h", value: "6.626 070 15 × 10⁻³⁴", unit: "J·s"),
        PhysicalConstant(name: "Reduced Planck constant", symbol: "ℏ", value: "1.054 571 817 × 10⁻³⁴", unit: "J·s"),
        PhysicalConstant(name: "Elementary charge", symbol: "e", value: "1.602 176 634 × 10⁻¹⁹", unit: "C"),
        PhysicalConstant(name: "Boltzmann constant", symbol: "k_B", value: "1.380 649 × 10⁻²³", unit: "J·K⁻¹"),
        PhysicalConstant(name: "Avogadro constant", symbol: "Nₐ", value: "6.022 140 76 × 10²³", unit: "mol⁻¹"),
        PhysicalConstant(name: "Molar gas constant", symbol: "R", value: "8.314 462 618", unit: "J·mol⁻¹·K⁻¹"),
        PhysicalConstant(name: "Faraday constant", symbol: "F", value: "96 485.332 12", unit: "C·mol⁻¹"),
        PhysicalConstant(name: "Gravitational constant", symbol: "G", value: "6.674 30 × 10⁻¹¹", unit: "N·m²·kg⁻²"),
        PhysicalConstant(name: "Standard gravity", symbol: "g₀", value: "9.806 65", unit: "m·s⁻²"),
        PhysicalConstant(name: "Vacuum permittivity", symbol: "ε₀", value: "8.854 187 8188 × 10⁻¹²", unit: "F·m⁻¹"),
        PhysicalConstant(name: "Vacuum permeability", symbol: "μ₀", value: "1.256 637 061 27 × 10⁻⁶", unit: "N·A⁻²"),
        PhysicalConstant(name: "Coulomb constant", symbol: "kₑ", value: "8.987 551 79 × 10⁹", unit: "N·m²·C⁻²"),
        PhysicalConstant(name: "Electron mass", symbol: "mₑ", value: "9.109 383 7139 × 10⁻³¹", unit: "kg"),
        PhysicalConstant(name: "Proton mass", symbol: "mₚ", value: "1.672 621 925 95 × 10⁻²⁷", unit: "kg"),
        PhysicalConstant(name: "Neutron mass", symbol: "mₙ", value: "1.674 927 500 56 × 10⁻²⁷", unit: "kg"),
        PhysicalConstant(name: "Atomic mass unit", symbol: "u", value: "1.660 539 068 92 × 10⁻²⁷", unit: "kg"),
        PhysicalConstant(name: "Fine-structure constant", symbol: "α", value: "7.297 352 5643 × 10⁻³", unit: ""),
        PhysicalConstant(name: "Rydberg constant", symbol: "R∞", value: "10 973 731.568 157", unit: "m⁻¹"),
        PhysicalConstant(name: "Bohr radius", symbol: "a₀", value: "5.291 772 105 44 × 10⁻¹¹", unit: "m"),
        PhysicalConstant(name: "Bohr magneton", symbol: "μ_B", value: "9.274 010 0657 × 10⁻²⁴", unit: "J·T⁻¹"),
        PhysicalConstant(name: "Stefan–Boltzmann constant", symbol: "σ", value: "5.670 374 419 × 10⁻⁸", unit: "W·m⁻²·K⁻⁴"),
        PhysicalConstant(name: "Wien displacement constant", symbol: "b", value: "2.897 771 955 × 10⁻³", unit: "m·K"),
        PhysicalConstant(name: "Electron volt", symbol: "eV", value: "1.602 176 634 × 10⁻¹⁹", unit: "J"),
        PhysicalConstant(name: "Standard atmosphere", symbol: "atm", value: "101 325", unit: "Pa"),
        PhysicalConstant(name: "Molar volume (0 °C, 1 atm)", symbol: "Vₘ", value: "22.414", unit: "L·mol⁻¹"),
        PhysicalConstant(name: "Absolute zero", symbol: "0 K", value: "−273.15", unit: "°C"),
        PhysicalConstant(name: "Astronomical unit", symbol: "AU", value: "149 597 870 700", unit: "m"),
        PhysicalConstant(name: "Light-year", symbol: "ly", value: "9.460 730 472 5808 × 10¹⁵", unit: "m"),
        PhysicalConstant(name: "Parsec", symbol: "pc", value: "3.085 677 581 × 10¹⁶", unit: "m"),
        PhysicalConstant(name: "Solar mass", symbol: "M☉", value: "1.988 × 10³⁰", unit: "kg"),
        PhysicalConstant(name: "Earth mass", symbol: "M⊕", value: "5.972 × 10²⁴", unit: "kg"),
    ]

    static let prefixes: [(symbol: String, name: String, power: Int)] = [
        ("Q", "quetta", 30), ("R", "ronna", 27), ("Y", "yotta", 24), ("Z", "zetta", 21), ("E", "exa", 18),
        ("P", "peta", 15), ("T", "tera", 12), ("G", "giga", 9), ("M", "mega", 6), ("k", "kilo", 3),
        ("h", "hecto", 2), ("da", "deca", 1), ("d", "deci", -1), ("c", "centi", -2), ("m", "milli", -3),
        ("µ", "micro", -6), ("n", "nano", -9), ("p", "pico", -12), ("f", "femto", -15), ("a", "atto", -18),
        ("z", "zepto", -21), ("y", "yocto", -24), ("r", "ronto", -27), ("q", "quecto", -30),
    ]

    static let unitSections: [SymbolSection] = [
        SymbolSection(id: "u.base", title: "SI base units", items: SymbolCatalog.words("m kg s A K mol cd")),
        SymbolSection(id: "u.derived", title: "SI derived units", items: SymbolCatalog.words("Hz N Pa J W C V F Ω S Wb T H °C lm lx Bq Gy Sv kat rad sr")),
        SymbolSection(id: "u.composite", title: "Composite units", items: SymbolCatalog.words("m·s⁻¹ m·s⁻² kg·m⁻³ N·m J·s J·K⁻¹ J·mol⁻¹ J·mol⁻¹·K⁻¹ J·kg⁻¹·K⁻¹ W·m⁻² W·m⁻¹·K⁻¹ V·m⁻¹ A·m⁻² C·m⁻³ mol·L⁻¹ mol·dm⁻³ g·mol⁻¹ g·cm⁻³ kg·m² rad·s⁻¹ rad·s⁻² N·m⁻¹ Pa·s m²·s⁻¹ s⁻¹ m⁻¹ K⁻¹")),
        SymbolSection(id: "u.other", title: "Non-SI & other", items: SymbolCatalog.words("L mL µL Å eV keV MeV GeV u Da atm bar mbar mmHg Torr psi cal kcal Wh kWh h min d y ly AU pc °F °R ppm ppb M mM µM N(normality) D G Ci R(rem) ha t")),
        SymbolSection(id: "u.prefixed", title: "Prefixed", items: SymbolCatalog.words("km cm mm µm nm pm fm mg µg ng kJ MJ kW MW GW kPa MPa GPa mV kV mA µA nA kΩ MΩ µF nF pF mT µT kHz MHz GHz THz ms µs ns ps fs mmol µmol")),
        SymbolSection(id: "u.prefixes", title: "SI prefixes", items: prefixes.map(\.symbol)),
    ]
}

// MARK: - Search index

struct UnicodeEntry: Identifiable, Hashable {
    let id: UInt32
    let char: String
    let name: String
    let keywords: String
}

final class UnicodeIndex {
    static let shared = UnicodeIndex()

    private(set) var entries: [UnicodeEntry] = []
    private var isBuilding = false
    private var waiting: [() -> Void] = []

    var isReady: Bool { !entries.isEmpty }

    /// Builds the index on a background queue; completion runs on the main queue.
    func prepare(_ completion: @escaping () -> Void = {}) {
        if isReady { completion(); return }
        waiting.append(completion)
        if isBuilding { return }
        isBuilding = true
        DispatchQueue.global(qos: .userInitiated).async {
            let built = Self.build()
            DispatchQueue.main.async {
                self.entries = built
                self.isBuilding = false
                let callbacks = self.waiting
                self.waiting = []
                callbacks.forEach { $0() }
            }
        }
    }

    private static func build() -> [UnicodeEntry] {
        var seen = Set<UInt32>()
        var result: [UnicodeEntry] = []
        let aliases = LatexConverter.aliases
        for block in SymbolCatalog.blocks {
            for v in block.range {
                guard !seen.contains(v), let s = Unicode.Scalar(v) else { continue }
                switch s.properties.generalCategory {
                case .unassigned, .control, .format, .surrogate, .privateUse: continue
                default: break
                }
                guard let name = s.properties.name ?? s.properties.nameAlias else { continue }
                seen.insert(v)
                let ch = String(Character(s))
                var kw = name.lowercased()
                if let a = aliases[ch] { kw += " " + a.joined(separator: " ").lowercased() }
                kw += " " + String(format: "u+%04x", v)
                result.append(UnicodeEntry(id: v, char: ch, name: name, keywords: kw))
            }
        }
        // Basic Greek & ASCII-adjacent symbols are already inside the blocks above.
        return result
    }

    func search(_ query: String, limit: Int = 240) -> [UnicodeEntry] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        if q.hasPrefix("u+") || q.hasPrefix("0x"), let v = UInt32(q.dropFirst(2), radix: 16),
           let s = Unicode.Scalar(v) {
            let ch = String(Character(s))
            return [UnicodeEntry(id: v, char: ch, name: s.properties.name ?? "U+\(String(v, radix: 16))", keywords: "")]
        }
        let words = q.split(separator: " ").map(String.init)
        var exact: [UnicodeEntry] = []
        var prefix: [UnicodeEntry] = []
        var rest: [UnicodeEntry] = []
        for e in entries {
            guard words.allSatisfy({ e.keywords.contains($0) }) else { continue }
            let lname = e.name.lowercased()
            if lname == q || e.keywords.contains(" \(q) ") || e.keywords.hasSuffix(" \(q)") {
                exact.append(e)
            } else if lname.hasPrefix(q) || lname.contains(" \(q)") {
                prefix.append(e)
            } else {
                rest.append(e)
            }
            if exact.count + prefix.count >= limit { break }
        }
        return Array((exact + prefix + rest).prefix(limit))
    }
}
