import SwiftUI
import UIKit

enum KeyPage: Equatable {
    case letters, numbers, symbols
}

enum ShiftState: Equatable {
    case off, once, capsLock
}

/// Top-level panels shown in the top bar. Each one has its own tabs.
enum PanelID: String, CaseIterable, Identifiable {
    case recents, symbols, chemistry, physics, calculator, clipboard, builders, tools

    var id: String { rawValue }

    var glyph: String {
        switch self {
        case .recents: return "★"
        case .symbols: return "∑"
        case .chemistry: return "⚗︎"
        case .physics: return "⚛︎"
        case .calculator: return "="
        case .clipboard: return "📋"
        case .builders: return "✦"
        case .tools: return "⚙︎"
        }
    }

    var title: String {
        switch self {
        case .recents: return "Favorites"
        case .symbols: return "Symbols"
        case .chemistry: return "Chemistry"
        case .physics: return "Physics"
        case .calculator: return "Calculator"
        case .clipboard: return "Clipboard"
        case .builders: return "Builders"
        case .tools: return "Tools"
        }
    }
}

/// Sub-tabs of the Symbols panel.
enum SymbolTab: String, CaseIterable, Identifiable {
    case greek, math, calculus, arrows, scripts, accents, styles, letterlike, shapes, unicode

    var id: String { rawValue }

    var title: String {
        switch self {
        case .greek: return "αβ Greek"
        case .math: return "± Math"
        case .calculus: return "∫ Calculus"
        case .arrows: return "→ Arrows"
        case .scripts: return "x² Super/Sub"
        case .accents: return "x⃗ Accents"
        case .styles: return "𝔸 Styles"
        case .letterlike: return "ℝ Letters"
        case .shapes: return "◆ Shapes"
        case .unicode: return "U+ All"
        }
    }

    var category: SymbolCategory? { SymbolCatalog.category(rawValue) }
}

enum Screen: Equatable {
    case keys(KeyPage)
    case panel(PanelID)
    case wizard
}

/// Where letter-key input goes when it does not go to the document.
enum InputSink: Equatable {
    case search
    case wizardField
    case molar
}

struct Suggestion: Identifiable, Equatable {
    enum Kind: Equatable {
        /// Science conversion of the token before the cursor (H2O → H₂O).
        case conversion
        /// Keep the word as typed (shown in quotes when a correction is pending).
        case literal
        /// The autocorrection that space will apply.
        case correction
        /// A spelling alternative or word completion.
        case word
    }

    let replacement: String
    let tokenLength: Int
    var kind: Kind = .conversion
    var id: String { "\(kind)-\(replacement)" }

    var label: String { kind == .literal ? "“\(replacement)”" : replacement }
}

struct WizardState: Equatable {
    var preset: Preset
    var step = 0
    var values: [String: String] = [:]
    /// The next keypad/letter press replaces the pre-filled default.
    var fresh = true

    var field: PresetField? { step < preset.fields.count ? preset.fields[step] : nil }
    var isLast: Bool { step >= preset.fields.count - 1 }
    var preview: String { PresetEngine.render(preset, values: values) }
}

/// Key pop-ups are drawn in one overlay at the root so they are never clipped,
/// and live in their own object so showing them doesn't redraw every key.
final class PopupModel: ObservableObject {
    struct Alternates: Equatable {
        var options: [String]
        var keyFrame: CGRect
        var trailing: Bool
        var index = 0
    }

    struct Preview: Equatable {
        var text: String
        var keyFrame: CGRect
    }

    @Published var alternates: Alternates?
    @Published var preview: Preview?
    var containerSize: CGSize = .zero

    struct Layout {
        var frame: CGRect
        var cell: CGFloat
    }

    /// Places the alternates bubble above the key, clamped inside the keyboard.
    static func layout(_ a: Alternates, in size: CGSize) -> Layout {
        let count = CGFloat(max(a.options.count, 1))
        var cell = max(min(a.keyFrame.width, 54), 40)
        if size.width > 0 { cell = min(cell, (size.width - 16) / count) }
        let height = min(max(a.keyFrame.height, 40), 58)
        let width = count * cell + 8
        var x = a.trailing ? a.keyFrame.maxX - width : a.keyFrame.minX
        x = min(max(x, 4), max(size.width - width - 4, 4))
        let y = max(2, a.keyFrame.minY - height - 14)
        return Layout(frame: CGRect(x: x, y: y, width: width, height: height + 8), cell: cell)
    }
}

enum SmartSuggest {
    static let shortcuts: [String: String] = [
        "->": "→", "<-": "←", "<->": "↔", "=>": "⇒", "<=>": "⇌", "<==>": "⇔", "<=": "≤", ">=": "≥",
        "!=": "≠", "+-": "±", "-+": "∓", "~=": "≈", "~~": "≈", "===": "≡", "inf": "∞", "deg": "°",
        "...": "…", "sqrt": "√", "cbrt": "∛", "int": "∫", "iint": "∬", "oint": "∮", "sum": "∑",
        "prod": "∏", "nabla": "∇", "del": "∇", "partial": "∂", "hbar": "ℏ", "angstrom": "Å",
        "micro": "µ", "ohm": "Ω", "degC": "℃", "<<": "≪", ">>": "≫", "*": "×", "/": "÷",
        "forall": "∀", "exists": "∃", "notin": "∉", "therefore": "∴", "because": "∵",
        "approx": "≈", "prop": "∝", "perp": "⊥", "cross": "×",
        "|>": "⟩", "<|": "⟨", "(c)": "©", "tm": "™", "permil": "‰",
    ]

    static func suggestions(for token: String) -> [Suggestion] {
        guard !token.isEmpty, token.count <= 80 else { return [] }
        var out: [String] = []
        func add(_ s: String) {
            if !s.isEmpty, s != token, !out.contains(s) { out.append(s) }
        }
        if let s = shortcuts[token] { add(s) }
        if let g = LatexConverter.greek[token] { add(g) }
        if token.contains("\\") || token.contains("^") || token.contains("_") {
            add(LatexConverter.convert(token))
        }
        let isFormula = ChemFormatter.looksLikeFormula(token)
        if isFormula { add(ChemFormatter.formatFormula(token)) }
        if !isFormula, let first = token.first, first.isLetter,
           token.contains(where: { $0.isASCII && $0.isNumber }) {
            add(ChemFormatter.formatUnits(token))
        }
        let upper = token.uppercased()
        if upper.hasPrefix("U+"), let v = UInt32(upper.dropFirst(2), radix: 16), let s = Unicode.Scalar(v) {
            add(String(Character(s)))
        }
        if token.lowercased().contains("e"), let d = Double(token), d.isFinite {
            add(NumberFormat.scientific(d, significant: 6))
        }
        let parts = token.split(separator: "/")
        if parts.count == 2, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) {
            add(LatexConverter.fraction(String(parts[0]), String(parts[1])))
        }
        if token.count > 1, token.allSatisfy({ $0.isASCII && $0.isNumber }) {
            add(Scripts.superscript(token))
            add(Scripts.subscripted(token))
        }
        return out.prefix(3).map { Suggestion(replacement: $0, tokenLength: token.count) }
    }
}

final class KeyboardState: ObservableObject {
    weak var controller: KeyboardViewController?
    let store = SharedStore.shared
    let popup = PopupModel()
    let autocorrector = Autocorrector()

    var onScreenChange: (() -> Void)?

    @Published var screen: Screen = .keys(.letters) {
        didSet { if oldValue != screen { onScreenChange?() } }
    }
    @Published var shift: ShiftState = .off
    @Published var settings = KeyboardSettings()
    @Published var sink: InputSink?
    @Published var buffer = ""
    @Published var scriptMode: ScriptStyle?
    @Published var alphabet: MathAlphabet?
    @Published var suggestions: [Suggestion] = []
    @Published var status = "" {
        didSet { if !status.isEmpty { scheduleStatusClear() } }
    }
    @Published var recents: [String] = []
    @Published var favorites: [String] = []
    @Published var clipboard: [ClipItem] = []
    @Published var selectedClip: UUID?
    @Published var snippets: [Snippet] = []
    @Published var customPresets: [Preset] = []
    @Published var wizard: WizardState?
    @Published var lastPanel: PanelID = .symbols
    @Published var hasFullAccess = false
    @Published var needsGlobe = true
    @Published var returnLabel = "return"
    @Published var returnIsPrimary = false
    @Published var selectedElement: Element?
    @Published var calcInput = ""
    @Published var calcAns: Double = 0
    @Published var degrees = false
    @Published var hexBuffer = ""
    @Published var tabs: [String: Int] = [:]
    @Published var searchResults: [UnicodeEntry] = []
    @Published var unicodeBlock = 0
    @Published var alphabetPreview: MathAlphabet = .bold
    @Published var convertLine = false
    @Published var molarInput = ""
    @Published var molarKind: MassKind = .molar
    @Published var molarPrecision: MassPrecision = .precise
    @Published var molarStyle: MultiplyStyle = .dot
    @Published var molarUnit: MassUnitStyle = .superscript

    private var lastShiftTap: Date?
    private var lastSpaceTime: Date?
    private var blockCache: [Int: [String]] = [:]
    private var statusClear: DispatchWorkItem?
    /// The last automatic correction, so an immediate backspace can undo it.
    private var lastCorrection: (original: String, corrected: String)?
    private lazy var haptic = UIImpactFeedbackGenerator(style: .light)

    var proxy: UITextDocumentProxy? { controller?.textDocumentProxy }
    var allPresets: [Preset] { PresetLibrary.builtIn + customPresets }

    // MARK: Lifecycle

    func reload() {
        settings = store.settings
        recents = store.recents
        favorites = store.favorites
        clipboard = store.clipboard
        snippets = store.snippets
        customPresets = store.customPresets
        degrees = settings.angleInDegrees
        hasFullAccess = controller?.hasFullAccess ?? false
        needsGlobe = controller?.needsInputModeSwitchKey ?? true
    }

    func textDidChange() {
        if let type = proxy?.returnKeyType {
            switch type {
            case .go: returnLabel = "go"
            case .google, .yahoo, .search: returnLabel = "search"
            case .send: returnLabel = "send"
            case .done: returnLabel = "done"
            case .next: returnLabel = "next"
            case .join: returnLabel = "join"
            case .route: returnLabel = "route"
            case .continue: returnLabel = "continue"
            case .emergencyCall: returnLabel = "SOS"
            default: returnLabel = "return"
            }
            returnIsPrimary = returnLabel != "return"
        }
        afterEdit()
    }

    private func scheduleStatusClear() {
        statusClear?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.status = "" }
        statusClear = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: work)
    }

    // MARK: Feedback

    func feedback() {
        if settings.keyClicks { UIDevice.current.playInputClick() }
        if settings.haptics && hasFullAccess { haptic.impactOccurred(intensity: 0.55) }
    }

    func tabBinding(_ key: String) -> Binding<Int> {
        Binding(get: { self.tabs[key] ?? 0 }, set: { self.tabs[key] = $0 })
    }

    func saveSettings() {
        store.settings = settings
    }

    func cycleLanguage() {
        let all = TypingLanguage.allCases
        let next = all[((all.firstIndex(of: settings.language) ?? 0) + 1) % all.count]
        settings.language = next
        saveSettings()
        feedback()
        status = next == .off ? "Autocorrect off" : "Typing language: \(next.title)"
        if next != .off && !Autocorrector.isAvailable(next) {
            status = "\(next.title) dictionary isn’t available on this device"
        }
        afterEdit()
    }

    // MARK: Typing

    private static let wordEnders: Set<String> = [".", ",", "!", "?", ";", ":", ")", "\"", "'"]

    func typeKey(_ raw: String, literal: Bool = false) {
        var text = raw
        if !literal && shift != .off { text = raw.uppercased() }
        if sink == .molar {
            if !literal && shift == .off { text = molarCase(raw) }
            appendToBuffer(text)
        } else if sink != nil {
            appendToBuffer(text)
        } else {
            if Self.wordEnders.contains(text) { applyAutocorrection() } else { lastCorrection = nil }
            if let a = alphabet { text = a.apply(to: text) }
            if let s = scriptMode { text = Scripts.apply(s, to: text) }
            proxy?.insertText(text)
        }
        if shift == .once { shift = .off }
        afterEdit()
    }

    /// While typing a formula, guess capitals: "h2o" → H2O, "nacl" → NaCl.
    private func molarCase(_ raw: String) -> String {
        guard raw.count == 1, let ch = raw.first, ch.isLetter else { return raw }
        if let prev = buffer.last, prev.isUppercase, PeriodicTable.isSymbol(String(prev) + raw.lowercased()) {
            return raw.lowercased()
        }
        return raw.uppercased()
    }

    private func appendToBuffer(_ text: String) {
        if sink == .wizardField, var w = wizard, w.fresh {
            buffer = ""
            w.fresh = false
            wizard = w
        }
        buffer += text
        sinkDidChange()
    }

    /// Inserts a ready-made symbol or string (from panels, builders, clipboard…).
    func insertSymbol(_ s: String, record: Bool = true) {
        lastCorrection = nil
        if sink != nil {
            appendToBuffer(s)
        } else {
            proxy?.insertText(s)
        }
        if record && s.count <= 40 {
            store.addRecent(s)
            recents = store.recents
        }
        updateStatus(for: s)
        afterEdit()
    }

    func deleteBackward() {
        if sink != nil {
            if sink == .wizardField, var w = wizard, w.fresh {
                w.fresh = false
                wizard = w
                buffer = ""
            } else if !buffer.isEmpty {
                buffer.removeLast()
            }
            sinkDidChange()
            return
        }
        if revertAutocorrection() { return }
        proxy?.deleteBackward()
        afterEdit()
    }

    func deleteWord() {
        guard sink == nil, let p = proxy else { deleteBackward(); return }
        lastCorrection = nil
        let before = p.documentContextBeforeInput ?? ""
        var count = 0
        var sawWord = false
        for ch in before.reversed() {
            if ch.isWhitespace || ch.isPunctuation {
                if sawWord { break }
            } else {
                sawWord = true
            }
            count += 1
        }
        for _ in 0..<max(count, 1) { p.deleteBackward() }
        afterEdit()
    }

    func space() {
        if sink != nil { appendToBuffer(" "); return }
        guard let p = proxy else { return }
        let now = Date()
        if settings.doubleSpacePeriod, let last = lastSpaceTime, now.timeIntervalSince(last) < 0.45 {
            let before = p.documentContextBeforeInput ?? ""
            if before.hasSuffix(" "), let prev = before.dropLast().last, prev.isLetter || prev.isNumber {
                p.deleteBackward()
                p.insertText(". ")
                lastSpaceTime = nil
                lastCorrection = nil
                afterEdit()
                return
            }
        }
        applyAutocorrection()
        p.insertText(" ")
        lastSpaceTime = now
        afterEdit()
    }

    func returnKey() {
        switch sink {
        case .search?, .molar?: closeSink()
        case .wizardField?: wizardNext()
        case nil:
            applyAutocorrection()
            proxy?.insertText("\n")
            afterEdit()
        }
    }

    func tapShift() {
        let now = Date()
        if shift == .capsLock {
            shift = .off
        } else if let last = lastShiftTap, now.timeIntervalSince(last) < 0.35 {
            shift = .capsLock
        } else {
            shift = shift == .off ? .once : .off
        }
        lastShiftTap = now
    }

    func showPage(_ page: KeyPage) {
        screen = .keys(page)
        if page == .letters { updateAutoShift() }
    }

    func afterEdit() {
        updateAutoShift()
        updateSuggestions()
    }

    func updateAutoShift() {
        guard settings.autoCapitalize, sink == nil, shift == .off,
              case .keys(.letters) = screen, let p = proxy else { return }
        if let type = p.autocapitalizationType, type == UITextAutocapitalizationType.none { return }
        let before = p.documentContextBeforeInput ?? ""
        let trimmed = before.trimmingCharacters(in: .whitespaces)
        let sentenceEnd = trimmed.hasSuffix(".") || trimmed.hasSuffix("!") || trimmed.hasSuffix("?")
        if before.isEmpty || before.hasSuffix("\n") || (sentenceEnd && before.hasSuffix(" ")) {
            shift = .once
        }
    }

    // MARK: Context helpers

    func lastToken() -> String {
        guard let before = proxy?.documentContextBeforeInput else { return "" }
        var token = ""
        for ch in before.reversed() {
            if ch.isWhitespace { break }
            token.insert(ch, at: token.startIndex)
        }
        return token
    }

    /// The word being typed (letters only) and the character just before it.
    func currentWord() -> (word: String, previous: Character?) {
        guard let before = proxy?.documentContextBeforeInput else { return ("", nil) }
        var word = ""
        var previous: Character?
        for ch in before.reversed() {
            if ch.isLetter || ch == "'" || ch == "’" {
                word.insert(ch, at: word.startIndex)
            } else {
                previous = ch
                break
            }
        }
        return (word, previous)
    }

    func currentLine() -> String {
        guard let before = proxy?.documentContextBeforeInput else { return "" }
        if let nl = before.lastIndex(of: "\n") { return String(before[before.index(after: nl)...]) }
        return before
    }

    // MARK: Suggestions & autocorrect

    private var autocorrectActive: Bool {
        guard settings.language != .off, sink == nil, scriptMode == nil, alphabet == nil else { return false }
        if let type = proxy?.autocorrectionType, type == .no { return false }
        if let kb = proxy?.keyboardType, [.URL, .emailAddress, .numberPad, .decimalPad, .phonePad, .webSearch].contains(kb) {
            return false
        }
        return true
    }

    func updateSuggestions() {
        guard sink == nil else {
            if !suggestions.isEmpty { suggestions = [] }
            return
        }
        var list: [Suggestion] = []
        if settings.smartSuggestions {
            list = SmartSuggest.suggestions(for: lastToken())
        }
        if autocorrectActive && (settings.predictions || settings.autocorrect) {
            let (word, previous) = currentWord()
            if Autocorrector.shouldCheck(word, precededBy: previous) {
                let analysis = autocorrector.analyze(word, language: settings.language)
                if let correction = analysis.correction {
                    list.append(Suggestion(replacement: word, tokenLength: word.count, kind: .literal))
                    list.append(Suggestion(replacement: correction, tokenLength: word.count,
                                           kind: settings.autocorrect ? .correction : .word))
                    for alt in analysis.alternatives {
                        list.append(Suggestion(replacement: alt, tokenLength: word.count, kind: .word))
                    }
                } else if settings.predictions {
                    for c in analysis.completions {
                        list.append(Suggestion(replacement: c, tokenLength: word.count, kind: .word))
                    }
                }
            }
        }
        var seen = Set<String>()
        let next = Array(list.filter { seen.insert($0.id).inserted }.prefix(3))
        if next != suggestions { suggestions = next }
    }

    func applySuggestion(_ s: Suggestion) {
        guard let p = proxy else { return }
        lastCorrection = nil
        switch s.kind {
        case .conversion:
            for _ in 0..<s.tokenLength { p.deleteBackward() }
            p.insertText(s.replacement)
        case .literal:
            autocorrector.learn(s.replacement)
            p.insertText(" ")
        case .correction, .word:
            for _ in 0..<s.tokenLength { p.deleteBackward() }
            p.insertText(s.replacement + " ")
        }
        feedback()
        afterEdit()
    }

    /// Replaces the word before the cursor with the pending correction, if any.
    private func applyAutocorrection() {
        lastCorrection = nil
        guard settings.autocorrect, autocorrectActive, let p = proxy else { return }
        let (word, previous) = currentWord()
        guard Autocorrector.shouldCheck(word, precededBy: previous) else { return }
        guard let correction = autocorrector.analyze(word, language: settings.language).correction,
              correction != word else { return }
        for _ in 0..<word.count { p.deleteBackward() }
        p.insertText(correction)
        lastCorrection = (word, correction)
    }

    /// Backspace right after an autocorrection restores what was typed.
    private func revertAutocorrection() -> Bool {
        guard let last = lastCorrection, let p = proxy else { return false }
        lastCorrection = nil
        let before = p.documentContextBeforeInput ?? ""
        guard let end = before.last, !end.isLetter else { return false }
        let body = before.dropLast()
        guard body.hasSuffix(last.corrected) else { return false }
        for _ in 0..<(last.corrected.count + 1) { p.deleteBackward() }
        p.insertText(last.original)
        autocorrector.learn(last.original)
        status = "Kept “\(last.original)”"
        afterEdit()
        return true
    }

    func updateStatus(for s: String) {
        if let name = s.unicodeName {
            status = "\(s.displayForm)  \(name.capitalized)  \(s.codepointLabel)"
        }
    }

    func toggleFavorite(_ s: String) {
        let added = store.toggleFavorite(s)
        favorites = store.favorites
        status = added ? "★ Added \(s.displayForm) to favorites" : "Removed \(s.displayForm) from favorites"
        feedback()
    }

    func clearRecents() {
        store.recents = []
        recents = []
    }

    // MARK: Navigation

    func openPanel(_ p: PanelID) {
        if sink != nil { sink = nil; wizard = nil }
        popup.alternates = nil
        popup.preview = nil
        screen = .panel(p)
        lastPanel = p
        if p == .clipboard { captureClipboard(force: false) }
    }

    func toggleScience() {
        if case .keys = screen {
            openPanel(lastPanel)
        } else {
            showPage(.letters)
        }
    }

    func beginSearch() {
        buffer = ""
        searchResults = []
        sink = .search
        shift = .off
        screen = .keys(.letters)
        UnicodeIndex.shared.prepare { [weak self] in self?.sinkDidChange() }
    }

    func beginMolarTyping() {
        buffer = molarInput
        sink = .molar
        shift = .off
        screen = .keys(.letters)
    }

    func sinkDidChange() {
        switch sink {
        case .search?:
            searchResults = UnicodeIndex.shared.search(buffer)
        case .wizardField?:
            if var w = wizard, let f = w.field {
                w.values[f.key] = buffer
                wizard = w
            }
        case .molar?:
            molarInput = buffer
        case nil:
            break
        }
    }

    /// Search results go straight into the document, not into the search buffer.
    func insertSearchResult(_ entry: UnicodeEntry) {
        feedback()
        proxy?.insertText(entry.char)
        store.addRecent(entry.char)
        recents = store.recents
        updateStatus(for: entry.char)
    }

    func closeSink() {
        let previous = sink
        sink = nil
        switch previous {
        case .wizardField?:
            wizardCancel()
        case .molar?:
            tabs["chem"] = 1
            openPanel(.chemistry)
        default:
            showPage(.letters)
        }
    }

    func blockItems(_ index: Int) -> [String] {
        if let cached = blockCache[index] { return cached }
        guard SymbolCatalog.blocks.indices.contains(index) else { return [] }
        let items = SymbolCatalog.blocks[index].items
        blockCache[index] = items
        return items
    }

    // MARK: Molar mass

    var molarReport: Result<MolarMassReport, Error> { MolarMass.report(molarInput) }

    func molarKey(_ key: String) {
        feedback()
        switch key {
        case "⌫": if !molarInput.isEmpty { molarInput.removeLast() }
        case "C": molarInput = ""
        default: molarInput += key
        }
    }

    func useTokenAsFormula() {
        let token = lastToken()
        guard !token.isEmpty else {
            status = "No formula before the cursor"
            return
        }
        molarInput = token
    }

    // MARK: Builders (presets)

    func startWizard(_ preset: Preset, element: Element? = nil) {
        var w = WizardState(preset: preset)
        if let e = element, let first = preset.fields.first, case .element = first.kind {
            w.values[first.key] = e.symbol
            w.step = 1
        }
        wizard = w
        prepareStep()
    }

    func prepareStep() {
        guard var w = wizard else { return }
        guard let f = w.field else { wizardFinish(); return }
        if (w.values[f.key] ?? "").isEmpty {
            w.values[f.key] = PresetEngine.defaultValue(for: f, in: w.preset, values: w.values)
        }
        w.fresh = true
        wizard = w
        if case .text = f.kind {
            buffer = w.values[f.key] ?? ""
            shift = .off
            sink = .wizardField
            screen = .keys(.letters)
        } else {
            sink = nil
            screen = .wizard
        }
    }

    func wizardSet(_ value: String, advance: Bool) {
        guard var w = wizard, let f = w.field else { return }
        if w.values[f.key] != value {
            for later in w.preset.fields[(w.step + 1)...] { w.values[later.key] = nil }
        }
        w.values[f.key] = value
        w.fresh = false
        wizard = w
        feedback()
        if advance { wizardNext() }
    }

    func wizardKeypad(_ key: String) {
        guard var w = wizard, let f = w.field else { return }
        let current = w.values[f.key] ?? ""
        var v = w.fresh ? "" : current
        switch key {
        case "⌫": v = String(v.dropLast())
        case "C": v = ""
        case "±": v = current.hasPrefix("-") ? String(current.dropFirst()) : "-" + current
        case "−": v += "-"
        default: v += key
        }
        w.values[f.key] = v
        w.fresh = false
        wizard = w
        feedback()
    }

    func wizardNext() {
        guard var w = wizard else { return }
        if sink == .wizardField, let f = w.field { w.values[f.key] = buffer }
        w.step += 1
        wizard = w
        prepareStep()
    }

    func wizardBack() {
        guard var w = wizard else { return }
        if sink == .wizardField, let f = w.field { w.values[f.key] = buffer }
        if w.step == 0 { wizardCancel(); return }
        w.step -= 1
        wizard = w
        prepareStep()
    }

    func wizardFinish() {
        guard var w = wizard else { return }
        if sink == .wizardField, let f = w.field { w.values[f.key] = buffer }
        for f in w.preset.fields where (w.values[f.key] ?? "").isEmpty && !f.optional {
            w.values[f.key] = PresetEngine.defaultValue(for: f, in: w.preset, values: w.values)
        }
        let text = PresetEngine.render(w.preset, values: w.values)
        wizard = nil
        sink = nil
        insertSymbol(text, record: false)
        screen = .panel(lastPanel)
    }

    func wizardCancel() {
        wizard = nil
        sink = nil
        screen = .panel(lastPanel)
    }

    // MARK: Clipboard

    func captureClipboard(force: Bool) {
        guard hasFullAccess else {
            if force { status = "Turn on Allow Full Access to use the clipboard" }
            return
        }
        guard force || settings.clipboardAutoCapture else { return }
        let pb = UIPasteboard.general
        guard force || pb.changeCount != store.lastPasteboardChangeCount else { return }
        store.lastPasteboardChangeCount = pb.changeCount
        guard pb.hasStrings, let s = pb.string else {
            if force { status = "Clipboard has no text" }
            return
        }
        if store.addClip(s, limit: settings.clipboardLimit) { status = "Saved clipboard" }
        clipboard = store.clipboard
    }

    var selectedClipItem: ClipItem? {
        guard let id = selectedClip else { return nil }
        return clipboard.first { $0.id == id }
    }

    func selectClip(_ item: ClipItem) {
        feedback()
        selectedClip = selectedClip == item.id ? nil : item.id
    }

    func pasteSelectedClip() {
        guard let item = selectedClipItem else {
            status = "Tap an item first, then Paste"
            return
        }
        insertSymbol(item.text, record: false)
        status = "Pasted"
    }

    func saveSelection() {
        guard let sel = proxy?.selectedText, !sel.isEmpty else {
            status = "Select some text first"
            return
        }
        if hasFullAccess {
            UIPasteboard.general.string = sel
            store.lastPasteboardChangeCount = UIPasteboard.general.changeCount
        }
        store.addClip(sel, limit: settings.clipboardLimit)
        clipboard = store.clipboard
        status = "Copied selection"
    }

    func cutSelection() {
        guard let sel = proxy?.selectedText, !sel.isEmpty else {
            status = "Select some text first"
            return
        }
        saveSelection()
        proxy?.deleteBackward()
        afterEdit()
    }

    func pasteSystemClipboard() {
        guard hasFullAccess else {
            status = "Turn on Allow Full Access to paste"
            return
        }
        guard let s = UIPasteboard.general.string else {
            status = "Clipboard has no text"
            return
        }
        insertSymbol(s, record: false)
    }

    func togglePin(_ item: ClipItem) {
        var list = store.clipboard
        if let i = list.firstIndex(where: { $0.id == item.id }) { list[i].pinned.toggle() }
        let pinned = list.filter(\.pinned)
        let rest = list.filter { !$0.pinned }
        store.clipboard = pinned + rest
        clipboard = store.clipboard
    }

    func deleteClip(_ item: ClipItem) {
        store.clipboard = store.clipboard.filter { $0.id != item.id }
        clipboard = store.clipboard
        if selectedClip == item.id { selectedClip = nil }
    }

    func clearClipboardHistory() {
        store.clipboard = store.clipboard.filter(\.pinned)
        clipboard = store.clipboard
        selectedClip = nil
        status = "Cleared (pinned items kept)"
    }

    // MARK: Cursor

    func moveCursor(_ offset: Int) {
        guard offset != 0 else { return }
        lastCorrection = nil
        proxy?.adjustTextPosition(byCharacterOffset: offset)
        afterEdit()
    }

    func moveWord(forward: Bool) {
        guard let p = proxy else { return }
        let text = forward ? Array(p.documentContextAfterInput ?? "") : Array((p.documentContextBeforeInput ?? "").reversed())
        var count = 0
        var sawWord = false
        for ch in text {
            if ch.isWhitespace || ch.isPunctuation {
                if sawWord { break }
            } else {
                sawWord = true
            }
            count += 1
        }
        moveCursor(forward ? count : -count)
    }

    func moveToLineEdge(start: Bool) {
        guard let p = proxy else { return }
        if start {
            moveCursor(-currentLine().count)
        } else {
            let after = p.documentContextAfterInput ?? ""
            let line = after.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
            moveCursor(line.count)
        }
    }

    // MARK: Conversions

    func transform(_ f: (String) -> String) {
        guard let p = proxy else { return }
        lastCorrection = nil
        if let sel = p.selectedText, !sel.isEmpty {
            p.insertText(f(sel))
            afterEdit()
            return
        }
        let target = convertLine ? currentLine() : lastToken()
        guard !target.isEmpty else {
            status = "Nothing before the cursor to convert"
            return
        }
        let result = f(target)
        guard result != target else {
            status = "Nothing to change"
            return
        }
        for _ in 0..<target.count { p.deleteBackward() }
        p.insertText(result)
        feedback()
        afterEdit()
    }

    // MARK: Calculator

    func calcEvaluate() -> Result<Double, Error> {
        let evaluator = ExpressionEvaluator(variables: ["ans": .number(calcAns)], degrees: degrees)
        do {
            let v = try evaluator.evaluate(calcInput)
            guard let d = v.asNumber else { throw ExprError.type("Not a number") }
            return .success(d)
        } catch {
            return .failure(error)
        }
    }

    func calcPress(_ key: String) {
        feedback()
        switch key {
        case "AC": calcInput = ""
        case "⌫": if !calcInput.isEmpty { calcInput.removeLast() }
        case "=":
            if case .success(let d) = calcEvaluate() {
                calcAns = d
                calcInput = NumberFormat.general(d)
            }
        case "E": calcInput += "×10^"
        default:
            calcInput += key
        }
    }

    enum CalcOutput { case result, equation, scientific }

    func calcInsert(_ output: CalcOutput) {
        guard case .success(let d) = calcEvaluate() else {
            status = calcInput.isEmpty ? "Type a calculation first" : "Fix the expression first"
            return
        }
        let text: String
        switch output {
        case .result: text = NumberFormat.general(d)
        case .equation: text = "\(calcInput) = \(NumberFormat.general(d))"
        case .scientific: text = NumberFormat.scientific(d, significant: 4)
        }
        calcAns = d
        insertSymbol(text, record: false)
        status = "Pasted \(text)"
    }

    /// Loads the current line of the document into the calculator.
    func calcFromDocument() {
        var line = currentLine().trimmingCharacters(in: .whitespaces)
        if line.hasSuffix("=") { line.removeLast() }
        guard !line.isEmpty else {
            status = "No text before the cursor"
            return
        }
        calcInput = line.trimmingCharacters(in: .whitespaces)
    }
}
