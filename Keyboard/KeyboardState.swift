import SwiftUI
import UIKit

enum KeyPage: Equatable {
    case letters, numbers, symbols
}

enum ShiftState: Equatable {
    case off, once, capsLock
}

enum PanelID: String, CaseIterable, Identifiable {
    case recents, greek, math, calculus, arrows, scripts, accents, alphabets
    case chemistry, physics, presets, clipboard, snippets, tools, letterlike, shapes, unicode

    var id: String { rawValue }

    var glyph: String {
        switch self {
        case .recents: return "★"
        case .greek: return "αβ"
        case .math: return "±≤"
        case .calculus: return "∫∂"
        case .arrows: return "→"
        case .scripts: return "x²"
        case .accents: return "x⃗"
        case .alphabets: return "𝔸𝒷"
        case .chemistry: return "⚗︎"
        case .physics: return "⚛︎"
        case .presets: return "✦"
        case .clipboard: return "📋"
        case .snippets: return "❝"
        case .tools: return "🧮"
        case .letterlike: return "ℝ"
        case .shapes: return "◆"
        case .unicode: return "U+"
        }
    }

    var title: String {
        switch self {
        case .recents: return "Recents"
        case .greek: return "Greek"
        case .math: return "Math"
        case .calculus: return "Calculus"
        case .arrows: return "Arrows"
        case .scripts: return "Super/Sub"
        case .accents: return "Accents"
        case .alphabets: return "Styles"
        case .chemistry: return "Chemistry"
        case .physics: return "Physics"
        case .presets: return "Builders"
        case .clipboard: return "Clipboard"
        case .snippets: return "Snippets"
        case .tools: return "Tools"
        case .letterlike: return "Letters"
        case .shapes: return "Shapes"
        case .unicode: return "All Unicode"
        }
    }

    var symbolCategory: SymbolCategory? { SymbolCatalog.category(rawValue) }
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
}

struct Suggestion: Identifiable, Equatable {
    let replacement: String
    let tokenLength: Int
    var id: String { replacement }
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
    @Published var status = ""
    @Published var recents: [String] = []
    @Published var favorites: [String] = []
    @Published var clipboard: [ClipItem] = []
    @Published var snippets: [Snippet] = []
    @Published var customPresets: [Preset] = []
    @Published var wizard: WizardState?
    @Published var lastPanel: PanelID = .greek
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

    private var lastShiftTap: Date?
    private var lastSpaceTime: Date?
    private var blockCache: [Int: [String]] = [:]
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

    // MARK: Feedback

    func feedback() {
        if settings.keyClicks { UIDevice.current.playInputClick() }
        if settings.haptics && hasFullAccess { haptic.impactOccurred(intensity: 0.55) }
    }

    func tabBinding(_ key: String) -> Binding<Int> {
        Binding(get: { self.tabs[key] ?? 0 }, set: { self.tabs[key] = $0 })
    }

    // MARK: Typing

    func typeKey(_ raw: String, literal: Bool = false) {
        var text = raw
        if !literal && shift != .off { text = raw.uppercased() }
        if sink != nil {
            appendToBuffer(text)
        } else {
            if let a = alphabet { text = a.apply(to: text) }
            if let s = scriptMode { text = Scripts.apply(s, to: text) }
            proxy?.insertText(text)
        }
        if shift == .once { shift = .off }
        afterEdit()
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
        proxy?.deleteBackward()
        afterEdit()
    }

    func deleteWord() {
        guard sink == nil, let p = proxy else { deleteBackward(); return }
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
                afterEdit()
                return
            }
        }
        p.insertText(" ")
        lastSpaceTime = now
        afterEdit()
    }

    func returnKey() {
        switch sink {
        case .search?: closeSink()
        case .wizardField?: wizardNext()
        case nil:
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

    func currentLine() -> String {
        guard let before = proxy?.documentContextBeforeInput else { return "" }
        if let nl = before.lastIndex(of: "\n") { return String(before[before.index(after: nl)...]) }
        return before
    }

    func updateSuggestions() {
        guard settings.smartSuggestions, sink == nil else {
            if !suggestions.isEmpty { suggestions = [] }
            return
        }
        let next = SmartSuggest.suggestions(for: lastToken())
        if next != suggestions { suggestions = next }
    }

    func applySuggestion(_ s: Suggestion) {
        guard let p = proxy else { return }
        for _ in 0..<s.tokenLength { p.deleteBackward() }
        p.insertText(s.replacement)
        feedback()
        afterEdit()
    }

    func updateStatus(for s: String) {
        if let name = s.unicodeName {
            status = "\(s.displayForm)  \(name.capitalized)  \(s.codepointLabel)"
        } else if s.count <= 24 {
            status = "Inserted \(s)"
        } else {
            status = "Inserted \(s.count) characters"
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

    func sinkDidChange() {
        switch sink {
        case .search?:
            searchResults = UnicodeIndex.shared.search(buffer)
        case .wizardField?:
            if var w = wizard, let f = w.field {
                w.values[f.key] = buffer
                wizard = w
            }
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
        let wasWizard = sink == .wizardField
        sink = nil
        if wasWizard {
            wizardCancel()
        } else {
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
        list.sort { ($0.pinned ? 1 : 0, $0.date) > ($1.pinned ? 1 : 0, $1.date) }
        store.clipboard = list
        clipboard = list
    }

    func deleteClip(_ item: ClipItem) {
        store.clipboard = store.clipboard.filter { $0.id != item.id }
        clipboard = store.clipboard
    }

    func clearClipboardHistory() {
        store.clipboard = store.clipboard.filter(\.pinned)
        clipboard = store.clipboard
        status = "Cleared (pinned items kept)"
    }

    // MARK: Cursor

    func moveCursor(_ offset: Int) {
        guard offset != 0 else { return }
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
        case "Ins":
            if case .success(let d) = calcEvaluate() { insertSymbol(NumberFormat.general(d), record: false) }
        case "Ins=":
            if case .success(let d) = calcEvaluate() {
                insertSymbol("\(calcInput) = \(NumberFormat.general(d))", record: false)
            }
        case "Sci":
            if case .success(let d) = calcEvaluate() { insertSymbol(NumberFormat.scientific(d, significant: 4), record: false) }
        default:
            calcInput += key
        }
    }
}
