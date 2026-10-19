import SwiftUI

// MARK: - Generic symbol panels

struct SymbolCategoryPanel: View {
    @ObservedObject var state: KeyboardState
    let category: SymbolCategory
    let builderCategory: String?

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: category.title,
                        tabs: builderCategory == nil ? [] : ["Symbols", "Builders"], tabKey: category.id)
            if builderCategory != nil && state.tabs[category.id] == 1 {
                PresetGrid(state: state, category: builderCategory)
            } else {
                SymbolGrid(state: state, sections: category.sections)
            }
        }
    }
}

struct RecentsPanel: View {
    @ObservedObject var state: KeyboardState

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Recents & favorites") {
                SmallButton(title: "Clear recents", icon: "trash") { state.clearRecents() }
            }
            if state.recents.isEmpty && state.favorites.isEmpty {
                EmptyHint(text: "Symbols you insert show up here. Long-press any symbol to make it a favorite.")
            } else {
                SymbolGrid(state: state, sections: [
                    SymbolSection(id: "fav", title: "Favorites", items: state.favorites),
                    SymbolSection(id: "recent", title: "Recently used", items: state.recents),
                ])
            }
        }
    }
}

struct EmptyHint: View {
    let text: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Text(text)
            .font(.system(size: 14))
            .multilineTextAlignment(.center)
            .foregroundColor(KeyPalette(scheme).secondaryText)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ScriptsPanel: View {
    @ObservedObject var state: KeyboardState

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Super/Sub") {
                SmallButton(title: "Type x²", selected: state.scriptMode == .sup) {
                    state.scriptMode = state.scriptMode == .sup ? nil : .sup
                    if state.scriptMode != nil { state.showPage(.letters) }
                }
                SmallButton(title: "Type x₂", selected: state.scriptMode == .sub) {
                    state.scriptMode = state.scriptMode == .sub ? nil : .sub
                    if state.scriptMode != nil { state.showPage(.letters) }
                }
            }
            SymbolGrid(state: state, sections: SymbolCatalog.scripts.sections)
        }
    }
}

struct AlphabetPanel: View {
    @ObservedObject var state: KeyboardState

    private var sections: [SymbolSection] {
        let style = state.alphabetPreview
        let upper = SymbolCatalog.chars(style.apply(to: "ABCDEFGHIJKLMNOPQRSTUVWXYZ"))
        let lower = SymbolCatalog.chars(style.apply(to: "abcdefghijklmnopqrstuvwxyz"))
        let digits = SymbolCatalog.chars(style.apply(to: "0123456789"))
        let greek = SymbolCatalog.chars(style.apply(to: "αβγδεζηθικλμνξοπρστυφχψωΓΔΘΛΞΠΣΦΨΩ"))
        var out = [SymbolSection(id: "a.up", title: "\(style.title) A–Z", items: upper),
                   SymbolSection(id: "a.low", title: "\(style.title) a–z", items: lower)]
        if digits.joined() != "0123456789" { out.append(SymbolSection(id: "a.dig", title: "Digits", items: digits)) }
        if greek.joined() != "αβγδεζηθικλμνξοπρστυφχψωΓΔΘΛΞΠΣΦΨΩ" {
            out.append(SymbolSection(id: "a.greek", title: "Greek", items: greek))
        }
        return out
    }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Math styles") {
                SmallButton(title: state.alphabet == state.alphabetPreview ? "Typing ✓" : "Type in style",
                            selected: state.alphabet == state.alphabetPreview) {
                    state.alphabet = state.alphabet == state.alphabetPreview ? nil : state.alphabetPreview
                    if state.alphabet != nil { state.showPage(.letters) }
                }
                SmallButton(title: "Apply to word") {
                    let style = state.alphabetPreview
                    state.transform { style.apply(to: $0) }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(MathAlphabet.allCases) { style in
                        BarChip(text: style.sample, selected: state.alphabetPreview == style) {
                            state.alphabetPreview = style
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(height: 36)
            SymbolGrid(state: state, sections: sections)
        }
    }
}

// MARK: - Chemistry

struct ChemistryPanel: View {
    @ObservedObject var state: KeyboardState
    let pad: Bool

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Chemistry", tabs: ["Table", "Symbols", "Builders"], tabKey: "chem")
            switch state.tabs["chem"] ?? 0 {
            case 1:
                SymbolGrid(state: state, sections: SymbolCatalog.chemistry.sections, minCell: 50)
            case 2:
                PresetGrid(state: state, category: "Chemistry")
            default:
                VStack(spacing: 4) {
                    ElementStrip(state: state)
                    PeriodicTableGrid(selected: state.selectedElement) { element in
                        state.selectedElement = element
                        state.feedback()
                        state.insertSymbol(element.symbol)
                        state.status = "\(element.number) · \(element.name) · \(element.massText) · \(element.configuration)"
                    }
                    .padding(.horizontal, 6)
                }
            }
        }
    }
}

struct ElementStrip: View {
    @ObservedObject var state: KeyboardState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = KeyPalette(scheme)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                if let e = state.selectedElement {
                    Text("\(e.symbol) · \(e.name)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(p.text)
                    action("Name") { e.name }
                    action("Nuclide \(e.nuclide)") { e.nuclide }
                    action("Isotope \(Scripts.superscript(String(e.massNumber)))\(e.symbol)") {
                        Scripts.superscript(String(e.massNumber)) + e.symbol
                    }
                    action("Config") { e.configuration }
                    action("Full config") { e.fullConfiguration }
                    action("M = \(e.massText)") { "M(\(e.symbol)) = \(e.massText.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))) g·mol⁻¹" }
                    action("Z = \(e.number)") { String(e.number) }
                    SmallButton(title: "Nuclide builder…", icon: "wand.and.stars") {
                        if let preset = PresetLibrary.chemistry.first(where: { $0.id == "nuclide" }) {
                            state.startWizard(preset, element: e)
                        }
                    }
                    SmallButton(title: "Ion…") {
                        if let preset = PresetLibrary.chemistry.first(where: { $0.id == "ion" }) {
                            state.startWizard(preset, element: e)
                        }
                    }
                    SmallButton(title: "Decay…") {
                        if let preset = PresetLibrary.chemistry.first(where: { $0.id == "alpha" }) {
                            state.startWizard(preset, element: e)
                        }
                    }
                } else {
                    Text("Tap an element to insert its symbol — then use these buttons for name, nuclide, configuration…")
                        .font(.system(size: 12))
                        .foregroundColor(p.secondaryText)
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 30)
    }

    private func action(_ title: String, _ text: @escaping () -> String) -> some View {
        SmallButton(title: title) {
            state.feedback()
            state.insertSymbol(text(), record: false)
        }
    }
}

struct PeriodicTableGrid: View {
    var selected: Element?
    let onTap: (Element) -> Void

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 2
            let w = max((geo.size.width - spacing * 17) / 18, 20)
            let h = max((geo.size.height - spacing * 9) / 9.4, 18)
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                VStack(spacing: spacing) {
                    ForEach(0..<10, id: \.self) { r in
                        if r == 7 {
                            Color.clear.frame(height: h * 0.4)
                        } else {
                            HStack(spacing: spacing) {
                                ForEach(0..<18, id: \.self) { c in
                                    cell(row: r, column: c, w: w, h: h)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private func cell(row: Int, column: Int, w: CGFloat, h: CGFloat) -> some View {
        if let e = PeriodicTable.grid[row][column] {
            Button {
                onTap(e)
            } label: {
                VStack(spacing: 0) {
                    if h > 30 {
                        Text("\(e.number)").font(.system(size: 8)).opacity(0.75)
                    }
                    Text(e.symbol)
                        .font(.system(size: min(w, h) * 0.45, weight: .semibold))
                        .minimumScaleFactor(0.5)
                }
                .foregroundColor(.black)
                .frame(width: w, height: h)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(e.category.color.opacity(selected?.number == e.number ? 1 : 0.78))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Color.primary, lineWidth: selected?.number == e.number ? 2 : 0)
                )
            }
            .buttonStyle(.plain)
        } else if column == 2 && (row == 5 || row == 6) {
            Text(row == 5 ? "57–71" : "89–103")
                .font(.system(size: 7))
                .foregroundColor(.secondary)
                .frame(width: w, height: h)
        } else {
            Color.clear.frame(width: w, height: h)
        }
    }
}

// MARK: - Physics

struct PhysicsPanel: View {
    @ObservedObject var state: KeyboardState

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Physics", tabs: ["Constants", "Units", "Symbols", "Builders"], tabKey: "phys")
            switch state.tabs["phys"] ?? 0 {
            case 1: SymbolGrid(state: state, sections: PhysicsData.unitSections, minCell: 58)
            case 2: SymbolGrid(state: state, sections: SymbolCatalog.physics.sections, minCell: 50)
            case 3: PresetGrid(state: state, category: "Physics")
            default: ConstantsGrid(state: state)
            }
        }
    }
}

struct ConstantsGrid: View {
    let state: KeyboardState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = KeyPalette(scheme)
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 6)], spacing: 6) {
                ForEach(PhysicsData.constants) { k in
                    HStack(spacing: 6) {
                        Button {
                            state.feedback()
                            state.insertSymbol(k.symbol)
                        } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(k.name).font(.system(size: 10)).foregroundColor(p.secondaryText).lineLimit(1)
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text(k.symbol).font(.system(size: 18, weight: .semibold))
                                    Text("\(k.value) \(k.unit)").font(.system(size: 11)).lineLimit(1).minimumScaleFactor(0.6)
                                }
                            }
                            .padding(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(KeyCapButtonStyle(radius: 6))
                        Button {
                            state.feedback()
                            state.insertSymbol(k.full, record: false)
                        } label: {
                            Text("=").font(.system(size: 17, weight: .semibold)).frame(width: 30, height: 40)
                        }
                        .buttonStyle(KeyCapButtonStyle(kind: .function, radius: 6))
                    }
                }
            }
            .padding(8)
        }
    }
}

// MARK: - Builders

struct PresetsPanel: View {
    @ObservedObject var state: KeyboardState
    private let categories = ["All", "Chemistry", "Physics", "Math", "Custom"]

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Builders", tabs: categories, tabKey: "presets")
            let index = state.tabs["presets"] ?? 0
            PresetGrid(state: state, category: index == 0 ? nil : categories[index])
        }
    }
}

struct PresetGrid: View {
    @ObservedObject var state: KeyboardState
    let category: String?
    @Environment(\.colorScheme) private var scheme

    private var presets: [Preset] {
        let all = state.allPresets
        guard let c = category else { return all }
        if c == "Custom" { return all.filter(\.isCustom) }
        return all.filter { $0.category == c }
    }

    var body: some View {
        let p = KeyPalette(scheme)
        if presets.isEmpty {
            EmptyHint(text: "No builders here yet. Create your own in the Science Keyboard app → Builders.")
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 6)], spacing: 6) {
                    ForEach(presets) { preset in
                        Button {
                            state.feedback()
                            state.startWizard(preset)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .lineLimit(1)
                                Text(preset.example.isEmpty ? PresetEngine.sample(preset) : preset.example)
                                    .font(.system(size: 15))
                                    .foregroundColor(p.secondaryText)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(KeyCapButtonStyle(radius: 8))
                    }
                }
                .padding(8)
            }
        }
    }
}

struct WizardView: View {
    @ObservedObject var state: KeyboardState
    let pad: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = KeyPalette(scheme)
        if let w = state.wizard, let field = w.field {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    SmallButton(title: w.step == 0 ? "Cancel" : "Back", icon: "chevron.left") { state.wizardBack() }
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(w.preset.name) · step \(w.step + 1) of \(w.preset.fields.count)")
                            .font(.system(size: 11))
                            .foregroundColor(p.secondaryText)
                        Text(field.label)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(p.text)
                    }
                    Spacer(minLength: 4)
                    Text(w.preview)
                        .font(.system(size: 22))
                        .foregroundColor(p.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                    if field.optional {
                        SmallButton(title: "Skip") { state.wizardSet("", advance: true) }
                    }
                    SmallButton(title: "Insert", icon: "return", selected: true) { state.wizardFinish() }
                    if !w.isLast {
                        SmallButton(title: "Next", icon: "chevron.right") { state.wizardNext() }
                    }
                }
                .padding(.horizontal, 6)
                fieldBody(w, field)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.top, 4)
            .padding(.bottom, 6)
        } else {
            Color.clear
        }
    }

    @ViewBuilder private func fieldBody(_ w: WizardState, _ field: PresetField) -> some View {
        switch field.kind {
        case .element:
            PeriodicTableGrid(selected: PeriodicTable.element(symbol: w.values[field.key] ?? "")) { e in
                state.wizardSet(e.symbol, advance: true)
            }
            .padding(.horizontal, 6)
        case .choice(let options):
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 6)], spacing: 6) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            state.wizardSet(option, advance: true)
                        } label: {
                            Text(option.isEmpty ? "(none)" : option)
                                .font(.system(size: 18))
                                .frame(maxWidth: .infinity, minHeight: 42)
                        }
                        .buttonStyle(KeyCapButtonStyle(selected: w.values[field.key] == option, radius: 7))
                    }
                }
                .padding(8)
            }
        case .integer, .number, .charge:
            HStack(spacing: 10) {
                VStack(spacing: 4) {
                    Text((w.values[field.key] ?? "").isEmpty ? "—" : (w.values[field.key] ?? ""))
                        .font(.system(size: 34, weight: .medium, design: .rounded))
                        .foregroundColor(w.fresh ? .secondary : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                    Text(w.fresh ? "default — type to replace" : "")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: 220)
                NumericPad(kind: field.kind) { state.wizardKeypad($0) } next: {
                    if w.isLast { state.wizardFinish() } else { state.wizardNext() }
                }
            }
            .padding(.horizontal, 8)
        case .text:
            EmptyHint(text: "Type with the keyboard…")
        }
    }
}

struct NumericPad: View {
    let kind: PresetFieldKind
    let press: (String) -> Void
    let next: () -> Void

    private var rows: [[String]] {
        switch kind {
        case .charge:
            return [["7", "8", "9", "⌫"], ["4", "5", "6", "C"], ["1", "2", "3", "+"], ["0", "−", "Next"]]
        case .number:
            return [["7", "8", "9", "⌫"], ["4", "5", "6", "±"], ["1", "2", "3", "."], ["0", "e", "Next"]]
        default:
            return [["7", "8", "9", "⌫"], ["4", "5", "6", "±"], ["1", "2", "3", "C"], ["0", "Next"]]
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { key in
                        Button {
                            if key == "Next" { next() } else { press(key) }
                        } label: {
                            Text(key == "Next" ? "Next ›" : key)
                                .font(.system(size: key.count > 1 ? 16 : 22))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(KeyCapButtonStyle(kind: key.first?.isNumber == true || key == "." ? .letter : .function,
                                                       selected: key == "Next", radius: 6))
                    }
                }
            }
        }
    }
}

// MARK: - Clipboard & snippets

struct ClipboardPanel: View {
    @ObservedObject var state: KeyboardState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = KeyPalette(scheme)
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Clipboard") {
                SmallButton(title: "Save clipboard", icon: "square.and.arrow.down") { state.captureClipboard(force: true) }
                SmallButton(title: "Copy sel.", icon: "doc.on.doc") { state.saveSelection() }
                SmallButton(title: "Cut", icon: "scissors") { state.cutSelection() }
                SmallButton(title: "Paste", icon: "doc.on.clipboard") { state.pasteSystemClipboard() }
                SmallButton(title: "Clear", icon: "trash") { state.clearClipboardHistory() }
            }
            if !state.hasFullAccess {
                Text("Clipboard history needs “Allow Full Access” (Settings → General → Keyboard → Keyboards → Science Keyboard). Without it you can still use items saved from the app.")
                    .font(.system(size: 12))
                    .foregroundColor(p.secondaryText)
                    .padding(.horizontal, 10)
            }
            if state.clipboard.isEmpty {
                EmptyHint(text: "Nothing saved yet. Copy something, then open this tab or tap “Save clipboard”.")
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 6)], spacing: 6) {
                        ForEach(state.clipboard) { item in
                            ClipCard(item: item, state: state)
                        }
                    }
                    .padding(8)
                }
            }
        }
    }
}

struct ClipCard: View {
    let item: ClipItem
    let state: KeyboardState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = KeyPalette(scheme)
        VStack(alignment: .leading, spacing: 4) {
            Button {
                state.feedback()
                state.insertSymbol(item.text, record: false)
            } label: {
                Text(item.text)
                    .font(.system(size: 14))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .topLeading)
            }
            .buttonStyle(.plain)
            HStack(spacing: 10) {
                Text(item.date, style: .relative)
                    .font(.system(size: 10))
                    .foregroundColor(p.secondaryText)
                Spacer()
                Button { state.togglePin(item) } label: {
                    Image(systemName: item.pinned ? "pin.fill" : "pin")
                }
                Button { state.deleteClip(item) } label: {
                    Image(systemName: "trash")
                }
            }
            .font(.system(size: 13))
            .buttonStyle(.plain)
            .foregroundColor(p.secondaryText)
        }
        .padding(8)
        .foregroundColor(p.text)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(p.letter)
                .shadow(color: p.shadow, radius: 0, y: 1)
        )
    }
}

struct SnippetsPanel: View {
    @ObservedObject var state: KeyboardState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = KeyPalette(scheme)
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Snippets")
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 6)], spacing: 6) {
                    ForEach(state.snippets) { snippet in
                        Button {
                            state.feedback()
                            state.insertSymbol(snippet.text, record: false)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(snippet.title).font(.system(size: 11)).foregroundColor(p.secondaryText)
                                Text(snippet.text).font(.system(size: 16)).lineLimit(2).minimumScaleFactor(0.6)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(KeyCapButtonStyle(radius: 8))
                    }
                }
                .padding(8)
                Text("Add or edit snippets in the Science Keyboard app.")
                    .font(.system(size: 11))
                    .foregroundColor(p.secondaryText)
                    .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Tools

struct ToolsPanel: View {
    @ObservedObject var state: KeyboardState
    let pad: Bool

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Tools", tabs: ["Calculator", "Convert", "Hex", "Cursor"], tabKey: "tools")
            switch state.tabs["tools"] ?? 0 {
            case 1: ConvertTool(state: state)
            case 2: HexTool(state: state)
            case 3: CursorTool(state: state)
            default: CalculatorTool(state: state)
            }
        }
    }
}

struct CalculatorTool: View {
    @ObservedObject var state: KeyboardState
    @Environment(\.colorScheme) private var scheme

    private let rows: [[(label: String, input: String)]] = [
        [("sin", "sin("), ("cos", "cos("), ("tan", "tan("), ("ln", "ln("), ("log", "log("), ("√", "√("), ("xʸ", "^"), ("(", "("), (")", ")")],
        [("sin⁻¹", "asin("), ("cos⁻¹", "acos("), ("tan⁻¹", "atan("), ("7", "7"), ("8", "8"), ("9", "9"), ("÷", "÷"), ("π", "π"), ("⌫", "⌫")],
        [("x²", "²"), ("x³", "³"), ("n!", "!"), ("4", "4"), ("5", "5"), ("6", "6"), ("×", "×"), ("e", "e"), ("AC", "AC")],
        [("ans", "ans"), ("×10ⁿ", "E"), ("%", "%"), ("1", "1"), ("2", "2"), ("3", "3"), ("−", "−"), ("ℏ", "ℏ"), ("=", "=")],
        [("Sci ⏎", "Sci"), ("c", "c"), ("Nₐ", "NA"), ("0", "0"), (".", "."), (",", ","), ("+", "+"), ("⏎", "Ins"), ("= ⏎", "Ins=")],
    ]

    var body: some View {
        let p = KeyPalette(scheme)
        VStack(spacing: 4) {
            HStack {
                Button(state.degrees ? "DEG" : "RAD") { state.degrees.toggle() }
                    .font(.system(size: 12, weight: .semibold))
                    .buttonStyle(.plain)
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(state.calcInput.isEmpty ? "0" : state.calcInput)
                        .font(.system(size: 18, design: .monospaced))
                        .foregroundColor(p.text)
                        .lineLimit(1)
                        .truncationMode(.head)
                    Text(resultText)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(p.secondaryText)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            VStack(spacing: 4) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 4) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, key in
                            Button {
                                state.calcPress(key.input)
                            } label: {
                                Text(key.label)
                                    .font(.system(size: 16))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .buttonStyle(KeyCapButtonStyle(kind: isDigit(key.input) ? .letter : .function,
                                                           selected: key.input.hasPrefix("Ins") || key.input == "Sci", radius: 6))
                        }
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 4)
        }
    }

    private func isDigit(_ s: String) -> Bool { s.count == 1 && (s.first?.isNumber ?? false || s == ".") }

    private var resultText: String {
        guard !state.calcInput.isEmpty else { return "ans = \(NumberFormat.general(state.calcAns))" }
        switch state.calcEvaluate() {
        case .success(let d): return "= \(NumberFormat.general(d))"
        case .failure(let e): return e.localizedDescription
        }
    }
}

struct ConvertTool: View {
    @ObservedObject var state: KeyboardState

    private var actions: [(String, (String) -> String)] {
        var list: [(String, (String) -> String)] = [
            ("LaTeX → Unicode", LatexConverter.convert),
            ("Chem formula", ChemFormatter.formatText),
            ("Units (m/s2 → m/s²)", ChemFormatter.formatUnits),
            ("Superscript", Scripts.superscript),
            ("Subscript", Scripts.subscripted),
            ("Evaluate = result", { text in
                let e = ExpressionEvaluator(variables: [:], degrees: state.degrees)
                guard let v = try? e.evaluate(text) else { return text }
                return "\(text) = \(v.text)"
            }),
            ("Plain text (NFKC)", { $0.precomposedStringWithCompatibilityMapping }),
            ("UPPERCASE", { $0.uppercased() }),
            ("lowercase", { $0.lowercased() }),
        ]
        for mark in CombiningMark.allCases.prefix(12) {
            list.append(("\(mark.title)  \(mark.apply(to: "x"))", { mark.apply(to: $0) }))
        }
        for style in MathAlphabet.allCases {
            list.append((style.sample + "  " + style.title, { style.apply(to: $0) }))
        }
        return list
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Applies to the selection, or else to the")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                SegmentTabs(titles: ["last word", "whole line"], selection: Binding(
                    get: { state.convertLine ? 1 : 0 },
                    set: { state.convertLine = $0 == 1 }))
                Spacer()
            }
            .padding(.horizontal, 10)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 6)], spacing: 6) {
                    ForEach(Array(actions.enumerated()), id: \.offset) { _, item in
                        Button {
                            state.transform(item.1)
                        } label: {
                            Text(item.0)
                                .font(.system(size: 14))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .frame(maxWidth: .infinity, minHeight: 38)
                        }
                        .buttonStyle(KeyCapButtonStyle(radius: 7))
                    }
                }
                .padding(8)
            }
        }
    }
}

struct HexTool: View {
    @ObservedObject var state: KeyboardState
    @Environment(\.colorScheme) private var scheme

    private var scalar: Unicode.Scalar? {
        UInt32(state.hexBuffer, radix: 16).flatMap { Unicode.Scalar($0) }
    }

    var body: some View {
        let p = KeyPalette(scheme)
        HStack(spacing: 10) {
            VStack(spacing: 4) {
                Text(scalar.map { String(Character($0)).displayForm } ?? "?")
                    .font(.system(size: 52))
                    .foregroundColor(p.text)
                Text("U+" + (state.hexBuffer.isEmpty ? "____" : state.hexBuffer.uppercased()))
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(p.text)
                Text(scalar.flatMap { $0.properties.name } ?? "Type a hex code point")
                    .font(.system(size: 11))
                    .foregroundColor(p.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: 240)
            VStack(spacing: 5) {
                ForEach([["7", "8", "9", "A", "B"], ["4", "5", "6", "C", "D"], ["1", "2", "3", "E", "F"], ["0", "⌫", "Clear", "Insert"]], id: \.self) { row in
                    HStack(spacing: 5) {
                        ForEach(row, id: \.self) { key in
                            Button {
                                press(key)
                            } label: {
                                Text(key)
                                    .font(.system(size: key.count > 1 ? 15 : 20))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .buttonStyle(KeyCapButtonStyle(kind: key.count > 1 ? .function : .letter,
                                                           selected: key == "Insert", radius: 6))
                        }
                    }
                }
            }
        }
        .padding(8)
    }

    private func press(_ key: String) {
        state.feedback()
        switch key {
        case "⌫": if !state.hexBuffer.isEmpty { state.hexBuffer.removeLast() }
        case "Clear": state.hexBuffer = ""
        case "Insert":
            if let s = scalar { state.insertSymbol(String(Character(s))) }
        default:
            if state.hexBuffer.count < 6 { state.hexBuffer += key }
        }
    }
}

struct CursorTool: View {
    @ObservedObject var state: KeyboardState

    var body: some View {
        let items: [(String, String, () -> Void)] = [
            ("Line start", "arrow.left.to.line", { state.moveToLineEdge(start: true) }),
            ("Word ←", "arrow.left.circle", { state.moveWord(forward: false) }),
            ("←", "arrow.left", { state.moveCursor(-1) }),
            ("→", "arrow.right", { state.moveCursor(1) }),
            ("Word →", "arrow.right.circle", { state.moveWord(forward: true) }),
            ("Line end", "arrow.right.to.line", { state.moveToLineEdge(start: false) }),
            ("Delete word", "delete.left.fill", { state.deleteWord() }),
            ("Copy selection", "doc.on.doc", { state.saveSelection() }),
            ("Cut selection", "scissors", { state.cutSelection() }),
            ("Paste", "doc.on.clipboard", { state.pasteSystemClipboard() }),
            ("Tab", "arrow.right.to.line.compact", { state.insertSymbol("\t", record: false) }),
            ("New line", "return", { state.insertSymbol("\n", record: false) }),
        ]
        return ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 6)], spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    Button {
                        state.feedback()
                        item.2()
                    } label: {
                        Label(item.0, systemImage: item.1)
                            .font(.system(size: 14))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(KeyCapButtonStyle(kind: .function, radius: 7))
                }
            }
            .padding(8)
            Text("Tip: drag along the space bar to move the cursor like a trackpad.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - All Unicode

struct UnicodePanel: View {
    @ObservedObject var state: KeyboardState

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "All Unicode")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(SymbolCatalog.blocks.enumerated()), id: \.offset) { i, block in
                        BarChip(text: block.name, selected: state.unicodeBlock == i) {
                            state.unicodeBlock = i
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(height: 36)
            let block = SymbolCatalog.blocks[min(state.unicodeBlock, SymbolCatalog.blocks.count - 1)]
            SymbolGrid(state: state, sections: [
                SymbolSection(id: block.name, title: "\(block.name) · U+\(String(format: "%04X", block.range.lowerBound))–U+\(String(format: "%04X", block.range.upperBound))",
                              items: state.blockItems(state.unicodeBlock)),
            ])
        }
    }
}
