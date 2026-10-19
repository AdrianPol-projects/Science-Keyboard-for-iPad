import SwiftUI

// MARK: - Snippets

struct SnippetsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editing: Snippet?

    var body: some View {
        List {
            Section {
                ForEach(model.snippets) { snippet in
                    Button {
                        model.copy(snippet.text)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(snippet.title).font(.caption).foregroundStyle(.secondary)
                            Text(snippet.text).font(.title3)
                        }
                    }
                    .foregroundStyle(.primary)
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            model.snippets.removeAll { $0.id == snippet.id }
                        }
                        Button("Edit") { editing = snippet }
                    }
                }
                .onMove { model.snippets.move(fromOffsets: $0, toOffset: $1) }
            } footer: {
                Text("Snippets appear in the keyboard under ❝ Snippets. Tap to copy, swipe to edit.")
            }
            Section {
                Button("Restore default snippets") {
                    let existing = Set(model.snippets.map(\.text))
                    model.snippets += Snippet.defaults.filter { !existing.contains($0.text) }
                }
            }
        }
        .navigationTitle("Snippets")
        .toolbar {
            ToolbarItemGroup {
                EditButton()
                Button {
                    editing = Snippet(title: "", text: "")
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editing) { snippet in
            SnippetEditor(snippet: snippet) { saved in
                if let i = model.snippets.firstIndex(where: { $0.id == saved.id }) {
                    model.snippets[i] = saved
                } else {
                    model.snippets.append(saved)
                }
            }
        }
    }
}

struct SnippetEditor: View {
    @State var snippet: Snippet
    let onSave: (Snippet) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $snippet.title)
                Section("Text (LaTeX like \\alpha or x^2 is converted when you tap Convert)") {
                    TextEditor(text: $snippet.text)
                        .font(.title3)
                        .frame(minHeight: 120)
                    Button("Convert LaTeX → Unicode") { snippet.text = LatexConverter.convert(snippet.text) }
                    Button("Format as chemistry") { snippet.text = ChemFormatter.formatText(snippet.text) }
                }
            }
            .navigationTitle(snippet.title.isEmpty ? "Snippet" : snippet.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var s = snippet
                        if s.title.isEmpty { s.title = String(s.text.prefix(20)) }
                        onSave(s)
                        dismiss()
                    }
                    .disabled(snippet.text.isEmpty)
                }
            }
        }
    }
}

// MARK: - Clipboard history

struct ClipboardHistoryView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List {
            if model.clipboard.isEmpty {
                Text("Nothing yet. Items copied in the keyboard’s Clipboard tab or in this app show up here.")
                    .foregroundStyle(.secondary)
            }
            ForEach(model.clipboard) { item in
                Button {
                    model.copy(item.text)
                } label: {
                    HStack(alignment: .top) {
                        if item.pinned { Image(systemName: "pin.fill").foregroundStyle(.orange) }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.text).lineLimit(4)
                            Text(item.date, style: .relative).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .foregroundStyle(.primary)
                .swipeActions(edge: .leading) {
                    Button(item.pinned ? "Unpin" : "Pin") { togglePin(item) }.tint(.orange)
                }
                .swipeActions {
                    Button("Delete", role: .destructive) {
                        model.clipboard.removeAll { $0.id == item.id }
                    }
                }
            }
        }
        .navigationTitle("Clipboard history")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    model.captureClipboard()
                } label: {
                    Label("Save current clipboard", systemImage: "square.and.arrow.down")
                }
                Button(role: .destructive) {
                    model.clipboard.removeAll { !$0.pinned }
                } label: {
                    Label("Clear unpinned", systemImage: "trash")
                }
            }
        }
    }

    private func togglePin(_ item: ClipItem) {
        guard let i = model.clipboard.firstIndex(where: { $0.id == item.id }) else { return }
        model.clipboard[i].pinned.toggle()
    }
}

// MARK: - Converter

struct ConverterView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("converterInput") private var input = "\\int_0^\\infty e^{-x} dx = 1, CuSO4.5H2O, m/s2"
    @State private var mode = 0

    private var modes: [(String, (String) -> String)] {
        var list: [(String, (String) -> String)] = [
            ("LaTeX → Unicode", LatexConverter.convert),
            ("Chemistry", ChemFormatter.formatText),
            ("Units", ChemFormatter.formatUnits),
            ("Superscript", Scripts.superscript),
            ("Subscript", Scripts.subscripted),
            ("Plain text (NFKC)", { $0.precomposedStringWithCompatibilityMapping }),
        ]
        for style in MathAlphabet.allCases { list.append((style.title, { style.apply(to: $0) })) }
        for mark in CombiningMark.allCases { list.append((mark.title, { mark.apply(to: $0) })) }
        return list
    }

    private var output: String { modes[min(mode, modes.count - 1)].1(input) }

    var body: some View {
        Form {
            Picker("Conversion", selection: $mode) {
                ForEach(Array(modes.enumerated()), id: \.offset) { i, m in Text(m.0).tag(i) }
            }
            Section("Input") {
                TextEditor(text: $input)
                    .font(.body.monospaced())
                    .frame(minHeight: 120)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            Section("Output") {
                Text(output)
                    .font(.title3)
                    .textSelection(.enabled)
                Button {
                    model.copy(output)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
        }
        .navigationTitle("Converter")
    }
}

// MARK: - Calculator

struct CalculatorView: View {
    @EnvironmentObject private var model: AppModel
    @State private var expression = ""
    @State private var history: [(String, String)] = []
    @State private var ans: Double = 0

    private var evaluation: Result<Double, Error>? {
        guard !expression.isEmpty else { return nil }
        let e = ExpressionEvaluator(variables: ["ans": .number(ans)], degrees: model.settings.angleInDegrees)
        do {
            guard let d = try e.evaluate(expression).asNumber else { throw ExprError.type("Not a number") }
            return .success(d)
        } catch {
            return .failure(error)
        }
    }

    var body: some View {
        Form {
            Section {
                TextField("e.g. 2π·sqrt(9.81/4) or h*c/500e-9", text: $expression)
                    .font(.title3.monospaced())
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit(commit)
                switch evaluation {
                case .success(let d)?:
                    HStack {
                        Text("= \(NumberFormat.general(d))").font(.title2)
                        Spacer()
                        Button("Copy") { model.copy(NumberFormat.general(d)) }
                        Button("Copy sci") { model.copy(NumberFormat.scientific(d, significant: 4)) }
                    }
                case .failure(let error)?:
                    Text(error.localizedDescription).foregroundStyle(.red)
                case nil:
                    EmptyView()
                }
                Toggle("Angles in degrees", isOn: $model.settings.angleInDegrees)
            }
            if !history.isEmpty {
                Section("History") {
                    ForEach(Array(history.enumerated()), id: \.offset) { _, item in
                        Button {
                            expression = item.0
                        } label: {
                            LabeledContent(item.0, value: item.1)
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            Section("Constants you can type") {
                ForEach(ExpressionEvaluator.constants.keys.sorted(), id: \.self) { name in
                    LabeledContent(name, value: NumberFormat.general(ExpressionEvaluator.constants[name] ?? 0))
                        .font(.callout.monospaced())
                }
            }
        }
        .navigationTitle("Calculator")
    }

    private func commit() {
        guard case .success(let d)? = evaluation else { return }
        history.insert((expression, NumberFormat.general(d)), at: 0)
        ans = d
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section("Typing") {
                Toggle("Auto-capitalization", isOn: $model.settings.autoCapitalize)
                Toggle("“.” shortcut (double space)", isOn: $model.settings.doubleSpacePeriod)
                Toggle("Smart suggestions (H2O → H₂O, \\alpha → α…)", isOn: $model.settings.smartSuggestions)
                Toggle("Space bar moves the cursor", isOn: $model.settings.spaceCursorControl)
                Picker("iPad flick keys", selection: $model.settings.flickMode) {
                    ForEach(FlickMode.allCases) { Text($0.title).tag($0) }
                }
            }
            Section("Feedback") {
                Toggle("Key clicks", isOn: $model.settings.keyClicks)
                Toggle("Haptics (needs Full Access)", isOn: $model.settings.haptics)
                Toggle("Key pop-ups (iPhone)", isOn: $model.settings.keyPopups)
            }
            Section("Look") {
                Picker("Theme", selection: $model.settings.theme) {
                    ForEach(KeyboardTheme.allCases) { Text($0.title).tag($0) }
                }
                Picker("Accent", selection: $model.settings.accent) {
                    ForEach(AccentChoice.allCases) { c in
                        Label(c.title, systemImage: "circle.fill").foregroundStyle(c.appColor).tag(c)
                    }
                }
                VStack(alignment: .leading) {
                    Text("Keyboard height: \(Int(model.settings.heightScale * 100)) %")
                    Slider(value: $model.settings.heightScale, in: 0.8...1.35, step: 0.05)
                }
            }
            Section("Clipboard") {
                Toggle("Save clipboard when opening the tab", isOn: $model.settings.clipboardAutoCapture)
                Stepper("Keep \(model.settings.clipboardLimit) items", value: $model.settings.clipboardLimit, in: 10...300, step: 10)
            }
            Section("Calculator") {
                Toggle("Angles in degrees", isOn: $model.settings.angleInDegrees)
            }
            Section("Data") {
                Button("Clear recently used symbols") {
                    model.store.recents = []
                    model.show("Recents cleared")
                }
                Button("Clear favorites", role: .destructive) { model.favorites = [] }
                Button("Reset all settings", role: .destructive) { model.settings = KeyboardSettings() }
            }
            Section("About") {
                LabeledContent("App Group", value: AppGroup.identifier)
                LabeledContent("Sharing with keyboard", value: model.isAppGroupShared ? "Yes" : "No")
                LabeledContent("Builders", value: "\(model.allPresets.count)")
                LabeledContent("Elements", value: "\(PeriodicTable.elements.count)")
            }
        }
        .navigationTitle("Keyboard settings")
    }
}

// MARK: - Help

struct HelpView: View {
    var body: some View {
        List {
            Section("Keyboard basics") {
                help("Switching", "The top bar holds every panel. ∑ (function key) toggles between letters and your last panel. 🔍 searches every symbol by Unicode name.")
                help("iPad flick keys", "Swipe down on a key to type its small grey symbol. Choose numbers or Greek in Settings.")
                help("Long-press", "Hold a letter, number or punctuation key for accents and science variants (e.g. d → ∂ δ Δ ∇). In panels, long-press a symbol to favorite it.")
                help("Space bar trackpad", "Drag along the space bar to move the cursor.")
                help("Delete", "Hold delete to repeat; after a moment it deletes whole words.")
                help("Super/subscript & styles", "Super/Sub and Styles panels can switch the letter keys into x², x₂, 𝐁𝐨𝐥𝐝, 𝔉𝔯𝔞𝔨𝔱𝔲𝔯, 𝕯𝖔𝖚𝖇𝖑𝖊… typing modes. The chip in the top bar turns them off.")
            }
            Section("Smart suggestions") {
                help("Chemistry", "H2SO4 → H₂SO₄, Fe3+ → Fe³⁺, SO4^2- → SO₄²⁻, CuSO4.5H2O → CuSO₄·5H₂O, ^14C → ¹⁴C")
                help("LaTeX", "\\alpha → α, x^2 → x², a_n → aₙ, \\frac{1}{2} → ½, \\vec{F} → F⃗, \\mathbb{R} → ℝ, \\sqrt[3]{x} → ∛x")
                help("Units & numbers", "m/s2 → m/s², kg*m*s-2 → kg·m·s⁻², 6.022e23 → 6.022 × 10²³, 3/4 → ¾, U+2207 → ∇")
                help("Shortcuts", "-> → →, <=> → ⇌, <= → ≤, != → ≠, +- → ±, ~= → ≈, inf → ∞, deg → °, nabla → ∇")
            }
            Section("Builder template syntax") {
                help("Tokens", "{expression} inserts a value. {expression:modifier} transforms it. {{ and }} insert literal braces.")
                help("Variables", "Each step’s key. Element steps also give key.Z, key.A (most common isotope), key.name, key.mass, key.config.")
                help("Math", "+ − × ÷ ^ % !, implicit multiplication (2π), sqrt, cbrt, exp, ln, log, log(x, b), sin…, round(x, n), min, max, abs, nCr, nPr, hypot, if(cond, a, b), eq(a, b). Constants: pi, e, c, h, hbar, kB, NA, R, F, G, qe, me, mp, eps0, mu0…")
                help("Text", "sym(Z), name(Z), mass(Z), config(Z), fullconfig(Z), chem(text), sup(text), sub(text), charge(text), sci(x, digits), latex(text), root(n), upper, lower. Strings use \"double quotes\" and join with +.")
                help("Modifiers", PresetEngine.modifiers.map { ":\($0.name) \($0.help)" }.joined(separator: "  ·  "))
                help("Example", "{A:sup}{Z:sub}{el} → {A-4:sup}{Z-2:sub}{sym(Z-2)} + ⁴₂He")
            }
            Section("Privacy") {
                help("Full Access", "Needed only for clipboard access and haptics. The keyboard never uses the network; all data stays in the shared App Group on this device.")
            }
        }
        .navigationTitle("Help & syntax")
    }

    private func help(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(text).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }
}
