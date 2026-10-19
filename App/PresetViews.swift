import SwiftUI

struct PresetListView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editing: Preset?

    var body: some View {
        List {
            Section {
                Text("Builders walk you through each value step by step in the keyboard (∑ key → ✦ Builders, or the Builders tab in Chemistry/Physics/Math). Try them here, or create your own.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(PresetLibrary.categories, id: \.self) { category in
                let presets = model.allPresets.filter { category == "Custom" ? $0.isCustom : ($0.category == category && !$0.isCustom) }
                if !presets.isEmpty || category == "Custom" {
                    Section(category) {
                        ForEach(presets) { preset in
                            NavigationLink {
                                PresetRunnerView(preset: preset)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.name)
                                    Text(preset.example.isEmpty ? PresetEngine.sample(preset) : preset.example)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .contextMenu {
                                Button("Duplicate & edit") { editing = duplicate(preset) }
                                if preset.isCustom {
                                    Button("Edit") { editing = preset }
                                    Button("Delete", role: .destructive) { delete(preset) }
                                }
                            }
                            .swipeActions {
                                if preset.isCustom {
                                    Button("Delete", role: .destructive) { delete(preset) }
                                    Button("Edit") { editing = preset }
                                } else {
                                    Button("Duplicate") { editing = duplicate(preset) }
                                }
                            }
                        }
                        if category == "Custom" && presets.isEmpty {
                            Text("No custom builders yet — tap + to make one.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Builders")
        .toolbar {
            Button {
                editing = Preset(id: UUID().uuidString, name: "My builder", category: "Custom",
                                 fields: [PresetField(key: "x", label: "Value", kind: .text, defaultExpression: "\"x\"")],
                                 template: "{x:bold}", isCustom: true)
            } label: {
                Label("New builder", systemImage: "plus")
            }
        }
        .sheet(item: $editing) { preset in
            NavigationStack {
                PresetEditorView(preset: preset) { saved in
                    if let i = model.customPresets.firstIndex(where: { $0.id == saved.id }) {
                        model.customPresets[i] = saved
                    } else {
                        model.customPresets.append(saved)
                    }
                    model.show("Saved “\(saved.name)” — it’s in the keyboard now")
                }
            }
        }
    }

    private func duplicate(_ preset: Preset) -> Preset {
        var copy = preset
        copy.id = UUID().uuidString
        copy.name = preset.name + " (copy)"
        copy.isCustom = true
        return copy
    }

    private func delete(_ preset: Preset) {
        model.customPresets.removeAll { $0.id == preset.id }
    }
}

// MARK: - Runner

struct PresetRunnerView: View {
    let preset: Preset
    @EnvironmentObject private var model: AppModel
    @State private var values: [String: String] = [:]
    @State private var edited: Set<String> = []

    private var output: String { PresetEngine.render(preset, values: values) }

    var body: some View {
        Form {
            Section("Result") {
                Text(output.isEmpty ? " " : output)
                    .font(.system(size: 30))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    model.copy(output)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
            Section("Values") {
                ForEach(Array(preset.fields.enumerated()), id: \.offset) { index, field in
                    fieldRow(field, index: index)
                }
                Button("Reset to defaults") {
                    edited = []
                    values = [:]
                    recompute(from: 0)
                }
            }
            Section("Template") {
                Text(preset.template).font(.callout.monospaced()).textSelection(.enabled)
            }
        }
        .navigationTitle(preset.name)
        .onAppear { if values.isEmpty { recompute(from: 0) } }
    }

    private func binding(_ field: PresetField, index: Int) -> Binding<String> {
        Binding(
            get: { values[field.key] ?? "" },
            set: { newValue in
                values[field.key] = newValue
                edited.insert(field.key)
                recompute(from: index + 1)
            }
        )
    }

    /// Re-fills defaults for fields the user has not touched (e.g. Z after choosing an element).
    private func recompute(from start: Int) {
        guard start < preset.fields.count else { return }
        var v = values
        for field in preset.fields[start...] where !edited.contains(field.key) {
            if case .element = field.kind, (v[field.key] ?? "").isEmpty {
                v[field.key] = "U"
            } else {
                v[field.key] = PresetEngine.defaultValue(for: field, in: preset, values: v)
            }
        }
        values = v
    }

    @ViewBuilder private func fieldRow(_ field: PresetField, index: Int) -> some View {
        switch field.kind {
        case .element:
            Picker(field.label, selection: binding(field, index: index)) {
                ForEach(PeriodicTable.elements) { e in
                    Text("\(e.number) · \(e.symbol) · \(e.name)").tag(e.symbol)
                }
            }
        case .choice(let options):
            Picker(field.label, selection: binding(field, index: index)) {
                ForEach(options, id: \.self) { option in
                    Text(option.isEmpty ? "(none)" : option).tag(option)
                }
            }
        case .integer, .number, .charge:
            LabeledContent(field.label) {
                TextField(field.optional ? "optional" : "", text: binding(field, index: index))
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
            }
        case .text:
            LabeledContent(field.label) {
                TextField(field.optional ? "optional" : "", text: binding(field, index: index))
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
    }
}

// MARK: - Editor

private enum KindOption: String, CaseIterable, Identifiable {
    case element, integer, number, charge, text, choice
    var id: String { rawValue }

    init(_ kind: PresetFieldKind) {
        switch kind {
        case .element: self = .element
        case .integer: self = .integer
        case .number: self = .number
        case .charge: self = .charge
        case .text: self = .text
        case .choice: self = .choice
        }
    }
}

private struct EditableField: Identifiable {
    var id = UUID()
    var key: String
    var label: String
    var kind: KindOption
    var options: String
    var defaultExpression: String
    var optional: Bool

    init(_ f: PresetField) {
        key = f.key
        label = f.label
        kind = KindOption(f.kind)
        if case .choice(let opts) = f.kind { options = opts.joined(separator: ", ") } else { options = "" }
        defaultExpression = f.defaultExpression ?? ""
        optional = f.optional
    }

    var field: PresetField {
        let k: PresetFieldKind
        switch kind {
        case .element: k = .element
        case .integer: k = .integer
        case .number: k = .number
        case .charge: k = .charge
        case .text: k = .text
        case .choice:
            k = .choice(options.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        }
        let key = self.key.trimmingCharacters(in: .whitespaces)
        return PresetField(key: key.isEmpty ? "x" : key, label: label, kind: k,
                           defaultExpression: defaultExpression.isEmpty ? nil : defaultExpression,
                           optional: optional)
    }
}

struct PresetEditorView: View {
    let onSave: (Preset) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Preset
    @State private var fields: [EditableField]

    init(preset: Preset, onSave: @escaping (Preset) -> Void) {
        self.onSave = onSave
        _draft = State(initialValue: preset)
        _fields = State(initialValue: preset.fields.map(EditableField.init))
    }

    private var built: Preset {
        var p = draft
        p.fields = fields.map(\.field)
        p.isCustom = true
        p.category = "Custom"
        return p
    }

    var body: some View {
        Form {
            Section("Preview (with default values)") {
                Text(PresetEngine.sample(built))
                    .font(.system(size: 26))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Section("Name") {
                TextField("Name", text: $draft.name)
                TextField("Example shown on the card (optional)", text: $draft.example)
            }
            Section {
                ForEach($fields) { $f in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            TextField("key", text: $f.key)
                                .font(.body.monospaced())
                                .frame(maxWidth: 90)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                            TextField("Label shown in the keyboard", text: $f.label)
                        }
                        Picker("Type", selection: $f.kind) {
                            ForEach(KindOption.allCases) { Text($0.rawValue.capitalized).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        if f.kind == .choice {
                            TextField("Options, comma separated", text: $f.options)
                        }
                        TextField("Default (expression, e.g. el.Z or \"H2O\")", text: $f.defaultExpression)
                            .font(.callout.monospaced())
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        Toggle("Optional (can be skipped)", isOn: $f.optional)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { fields.remove(atOffsets: $0) }
                .onMove { fields.move(fromOffsets: $0, toOffset: $1) }
                Button {
                    fields.append(EditableField(PresetField(key: "v\(fields.count + 1)", label: "Value", kind: .text)))
                } label: {
                    Label("Add step", systemImage: "plus")
                }
            } header: {
                Text("Steps (asked in this order)")
            } footer: {
                Text("Element steps show the periodic table and expose key.Z, key.A, key.name, key.mass, key.config.")
            }
            Section {
                TextEditor(text: $draft.template)
                    .font(.body.monospaced())
                    .frame(minHeight: 90)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: {
                Text("Template")
            } footer: {
                Text("Write {expression} or {expression:modifier}. Example: {A:sup}{Z:sub}{el} → ²³⁸₉₂U. See Help & syntax for every modifier and function.")
            }
            Section("Modifiers") {
                ForEach(Array(PresetEngine.modifiers.enumerated()), id: \.offset) { _, m in
                    LabeledContent(":" + m.name, value: m.help)
                        .font(.callout)
                }
            }
        }
        .navigationTitle(draft.name.isEmpty ? "Builder" : draft.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(built)
                    dismiss()
                }
                .disabled(draft.name.isEmpty || fields.isEmpty)
            }
            ToolbarItem(placement: .primaryAction) { EditButton() }
        }
    }
}
