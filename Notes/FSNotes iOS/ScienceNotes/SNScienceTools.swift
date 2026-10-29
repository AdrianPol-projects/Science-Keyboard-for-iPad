//
//  SNScienceTools.swift
//  Science Notes additions to FSNotes. Uses the shared Science Keyboard engine
//  (expression evaluator, molar mass, periodic table, LaTeX/chemistry converters).
//

import Charts
import SwiftUI

// MARK: - Calculator

struct SNCalculatorView: View {
    @ObservedObject var context: SNContext
    @AppStorage("sn.calc.degrees") private var degrees = false
    @State private var expression = ""
    @State private var history: [(String, String)] = []
    @FocusState private var focused: Bool

    private let keys: [[String]] = [
        ["sin(", "cos(", "tan(", "ln(", "log(", "√(", "^", "π"],
        ["(", ")", "×", "÷", "+", "−", "²", "!"],
        ["e", "ℏ", "c", "NA", "R", "kB", "h", "ans"],
    ]

    private var ans: Double {
        history.first.flatMap { Double($0.1) } ?? 0
    }

    private var result: Result<Double, Error>? {
        guard !expression.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let e = ExpressionEvaluator(variables: ["ans": .number(ans)], degrees: degrees)
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
                    .focused($focused)
                    .onSubmit(commit)
                switch result {
                case .success(let d)?:
                    Text("= \(NumberFormat.general(d))").font(.title2.weight(.semibold))
                case .failure(let error)?:
                    Text(error.localizedDescription).foregroundStyle(.orange)
                case nil:
                    EmptyView()
                }
                Toggle("Angles in degrees", isOn: $degrees)
            }
            Section {
                ForEach(keys, id: \.self) { row in
                    HStack {
                        ForEach(row, id: \.self) { key in
                            Button(key.replacingOccurrences(of: "(", with: "")) { expression += key }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            if case .success(let d)? = result {
                Section("Insert") {
                    SNInsertRow(title: "Result", value: NumberFormat.general(d), context: context)
                    SNInsertRow(title: "Equation", value: "\(expression) = \(NumberFormat.general(d))", context: context)
                    SNInsertRow(title: "Scientific", value: NumberFormat.scientific(d, significant: 4), context: context)
                }
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
            Section("Tip") {
                Text("Write lines ending with “=” in your note, e.g. “2·π·0.5 =”, then use Solve “=” lines to fill in all results at once.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            if expression.isEmpty {
                var line = context.selectedText.isEmpty
                    ? (context.fullText as NSString).substring(with: context.currentLineRange)
                    : context.selectedText
                line = line.trimmingCharacters(in: .whitespaces)
                if line.hasSuffix("=") { line.removeLast() }
                if (try? ExpressionEvaluator().evaluate(line)) != nil { expression = line }
            }
        }
    }

    private func commit() {
        guard case .success(let d)? = result else { return }
        history.insert((expression, NumberFormat.general(d)), at: 0)
    }
}

struct SNSolveLinesView: View {
    @ObservedObject var context: SNContext
    @AppStorage("sn.calc.degrees") private var degrees = false
    @State private var preview: [(range: NSRange, line: String, result: String)] = []

    var body: some View {
        Form {
            Section {
                Text("Finds every line that ends with “=” (for example “(3.2 + 4)·2 =” or “sqrt(2) =”) and writes the result after it.")
                    .font(.callout)
                Toggle("Angles in degrees", isOn: $degrees)
                    .onChange(of: degrees) { _, _ in scan() }
            }
            Section(preview.isEmpty ? "No lines to solve" : "\(preview.count) line(s)") {
                ForEach(Array(preview.enumerated()), id: \.offset) { _, item in
                    LabeledContent(item.line, value: item.result)
                        .font(.callout.monospaced())
                }
            }
            if !preview.isEmpty {
                Section {
                    Button("Fill in all results") { apply() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .onAppear(perform: scan)
    }

    private func scan() {
        let ns = context.fullText as NSString
        var found: [(NSRange, String, String)] = []
        let evaluator = ExpressionEvaluator(variables: [:], degrees: degrees)
        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: .byLines) { sub, range, _, _ in
            guard let line = sub, !line.contains("\u{FFFC}") else { return }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasSuffix("="), trimmed.count > 1 else { return }
            var expr = String(trimmed.dropLast())
            for prefix in ["- ", "* ", "> "] where expr.hasPrefix(prefix) { expr.removeFirst(prefix.count) }
            guard let value = try? evaluator.evaluate(expr), let d = value.asNumber else { return }
            found.append((range, line, NumberFormat.general(d)))
        }
        preview = found.map { (range: $0.0, line: $0.1, result: $0.2) }
    }

    private func apply() {
        // Replace from the end so earlier ranges stay valid.
        for item in preview.reversed() {
            let line = item.line.hasSuffix(" ") ? item.line : item.line + " "
            context.replace(item.range, with: line + item.result)
        }
        context.flash("Solved \(preview.count) line(s)")
        scan()
    }
}

// MARK: - Molar mass

struct SNMolarMassView: View {
    @ObservedObject var context: SNContext
    @AppStorage("sn.molar.formula") private var formula = "H2O"
    @State private var kind: MassKind = .molar
    @State private var precision: MassPrecision = .precise
    @State private var style: MultiplyStyle = .dot
    @State private var unit: MassUnitStyle = .superscript

    var body: some View {
        Form {
            Section {
                TextField("Formula, e.g. H2O, Ca(OH)2, CuSO4.5H2O", text: $formula)
                    .font(.title3.monospaced())
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !context.selectedText.isEmpty {
                    Button("Use the selected text") { formula = context.selectedText }
                }
            }
            Section("Options") {
                Picker("Quantity", selection: $kind) {
                    ForEach(MassKind.allCases) { Text($0.title).tag($0) }
                }
                Picker("Atomic masses", selection: $precision) {
                    ForEach(MassPrecision.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Steps", selection: $style) {
                    ForEach(MultiplyStyle.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                if kind == .molar {
                    Picker("Unit", selection: $unit) {
                        ForEach(MassUnitStyle.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }
            switch MolarMass.report(formula) {
            case .success(let r):
                Section("Insert") {
                    SNInsertRow(title: "Value", value: r.totalText(precision), context: context)
                    SNInsertRow(title: "With unit", value: r.totalText(precision) + r.unit(kind, unit), context: context)
                    SNInsertRow(title: "Equation", value: r.equation(kind, precision, style, unit, steps: false), context: context)
                    SNInsertRow(title: "With steps", value: r.equation(kind, precision, style, unit), context: context)
                    SNInsertRow(title: "Full working", value: r.equation(kind, precision, style, unit, symbolic: true), context: context)
                }
                Section("Composition by mass") {
                    ForEach(Array(r.composition(precision).enumerated()), id: \.offset) { _, item in
                        LabeledContent(item.0, value: String(format: "%.2f %%", item.1))
                    }
                }
            case .failure(let error):
                Section { Text(error.localizedDescription).foregroundStyle(.orange) }
            }
        }
    }
}

// MARK: - Periodic table

struct SNPeriodicTableView: View {
    @ObservedObject var context: SNContext
    @State private var selected: Element?

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(0..<10, id: \.self) { r in
                    if r == 7 {
                        Spacer().frame(height: 10)
                    } else {
                        HStack(spacing: 3) {
                            ForEach(0..<18, id: \.self) { c in
                                if let e = PeriodicTable.grid[r][c] {
                                    Button { selected = e } label: { SNElementTile(element: e) }
                                        .buttonStyle(.plain)
                                } else {
                                    SwiftUI.Color.clear.frame(width: 52, height: 58)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .sheet(item: $selected) { e in
            NavigationStack {
                List {
                    Section {
                        LabeledContent("Atomic number", value: "\(e.number)")
                        LabeledContent("Atomic mass", value: e.massText)
                        LabeledContent("Category", value: e.category.title)
                        LabeledContent("Group / period", value: "\(e.group.map(String.init) ?? "f") / \(e.period)")
                    }
                    Section("Insert") {
                        SNInsertRow(title: "Symbol", value: e.symbol, context: context)
                        SNInsertRow(title: "Name", value: e.name, context: context)
                        SNInsertRow(title: "Nuclide", value: e.nuclide, context: context)
                        SNInsertRow(title: "Configuration", value: e.configuration, context: context)
                        SNInsertRow(title: "Full configuration", value: e.fullConfiguration, context: context)
                        SNInsertRow(title: "Molar mass",
                                    value: "M(\(e.symbol)) = \(e.massText.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))) g·mol⁻¹",
                                    context: context)
                    }
                }
                .navigationTitle(e.name)
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium, .large])
        }
    }
}

struct SNElementTile: View {
    let element: Element

    var body: some View {
        VStack(spacing: 0) {
            Text("\(element.number)").font(.system(size: 9)).frame(maxWidth: .infinity, alignment: .leading)
            Text(element.symbol).font(.system(size: 19, weight: .bold))
            Text(element.name).font(.system(size: 7)).lineLimit(1).minimumScaleFactor(0.5)
        }
        .foregroundStyle(.black)
        .padding(3)
        .frame(width: 52, height: 58)
        .background(RoundedRectangle(cornerRadius: 6)
            .fill(SwiftUI.Color(red: element.category.rgb.0, green: element.category.rgb.1, blue: element.category.rgb.2).opacity(0.85)))
    }
}

// MARK: - Symbols & constants

struct SNSymbolsView: View {
    @ObservedObject var context: SNContext
    @State private var categoryID = SymbolCatalog.all.first?.id ?? ""

    private var sections: [SymbolSection] { SymbolCatalog.category(categoryID)?.sections ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(SymbolCatalog.all) { c in
                        SNCategoryChip(title: "\(c.glyph) \(c.title)", selected: c.id == categoryID) {
                            categoryID = c.id
                        }
                    }
                }
                .padding()
            }
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 8)], spacing: 8,
                          pinnedViews: [.sectionHeaders]) {
                    ForEach(sections) { section in
                        Section {
                            ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                                SNSymbolCell(symbol: item, context: context)
                            }
                        } header: {
                            SNSectionHeader(title: section.title)
                        }
                    }
                }
                .padding(.horizontal)
                .id(categoryID)
            }
        }
    }
}

struct SNCategoryChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        let tint: SwiftUI.Color = selected ? .accentColor : .gray
        Button(title, action: action)
            .buttonStyle(.bordered)
            .tint(tint)
    }
}

struct SNSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .background(.bar)
    }
}

struct SNSymbolCell: View {
    let symbol: String
    let context: SNContext

    var body: some View {
        let background: SwiftUI.Color = SwiftUI.Color(UIColor.secondarySystemBackground)
        Button {
            context.insert(symbol, message: "Inserted \(symbol.displayForm)")
        } label: {
            Text(symbol.displayForm)
                .font(.system(size: symbol.count > 2 ? 14 : 24))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(RoundedRectangle(cornerRadius: 8).fill(background))
        }
        .buttonStyle(.plain)
    }
}

struct SNConstantsView: View {
    @ObservedObject var context: SNContext

    var body: some View {
        List(PhysicsData.constants) { k in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(k.name).font(.caption).foregroundStyle(.secondary)
                    Text("\(k.symbol) = \(k.value) \(k.unit)")
                }
                Spacer()
                Button(k.symbol) { context.insert(k.symbol) }.buttonStyle(.bordered)
                Button("Full") { context.insert(k.full) }.buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - Unit converter

struct SNUnitsView: View {
    @ObservedObject var context: SNContext

    private struct Kind: Identifiable {
        let name: String
        let units: [(String, Dimension)]
        var id: String { name }
    }

    private let kinds: [Kind] = [
        Kind(name: "Length", units: [("m", UnitLength.meters), ("km", UnitLength.kilometers), ("cm", UnitLength.centimeters),
                                     ("mm", UnitLength.millimeters), ("µm", UnitLength.micrometers), ("nm", UnitLength.nanometers),
                                     ("pm", UnitLength.picometers), ("in", UnitLength.inches), ("ft", UnitLength.feet),
                                     ("mi", UnitLength.miles), ("ly", UnitLength.lightyears), ("AU", UnitLength.astronomicalUnits),
                                     ("pc", UnitLength.parsecs)]),
        Kind(name: "Mass", units: [("kg", UnitMass.kilograms), ("g", UnitMass.grams), ("mg", UnitMass.milligrams),
                                   ("µg", UnitMass.micrograms), ("t", UnitMass.metricTons), ("lb", UnitMass.pounds),
                                   ("oz", UnitMass.ounces)]),
        Kind(name: "Temperature", units: [("°C", UnitTemperature.celsius), ("K", UnitTemperature.kelvin), ("°F", UnitTemperature.fahrenheit)]),
        Kind(name: "Volume", units: [("L", UnitVolume.liters), ("mL", UnitVolume.milliliters), ("m³", UnitVolume.cubicMeters),
                                     ("dm³", UnitVolume.cubicDecimeters), ("cm³", UnitVolume.cubicCentimeters),
                                     ("gal", UnitVolume.gallons)]),
        Kind(name: "Energy", units: [("J", UnitEnergy.joules), ("kJ", UnitEnergy.kilojoules), ("cal", UnitEnergy.calories),
                                     ("kcal", UnitEnergy.kilocalories), ("kWh", UnitEnergy.kilowattHours),
                                     ("eV", UnitEnergy(symbol: "eV", converter: UnitConverterLinear(coefficient: 1.602176634e-19)))]),
        Kind(name: "Pressure", units: [("Pa", UnitPressure.newtonsPerMetersSquared), ("kPa", UnitPressure.kilopascals),
                                       ("bar", UnitPressure.bars), ("atm", UnitPressure(symbol: "atm", converter: UnitConverterLinear(coefficient: 101_325))),
                                       ("mmHg", UnitPressure.millimetersOfMercury), ("psi", UnitPressure.poundsForcePerSquareInch)]),
        Kind(name: "Speed", units: [("m/s", UnitSpeed.metersPerSecond), ("km/h", UnitSpeed.kilometersPerHour),
                                    ("mph", UnitSpeed.milesPerHour), ("kn", UnitSpeed.knots)]),
        Kind(name: "Time", units: [("s", UnitDuration.seconds), ("min", UnitDuration.minutes), ("h", UnitDuration.hours),
                                   ("ms", UnitDuration.milliseconds), ("µs", UnitDuration.microseconds), ("ns", UnitDuration.nanoseconds)]),
        Kind(name: "Area", units: [("m²", UnitArea.squareMeters), ("cm²", UnitArea.squareCentimeters), ("km²", UnitArea.squareKilometers),
                                   ("ha", UnitArea.hectares), ("acre", UnitArea.acres)]),
        Kind(name: "Power", units: [("W", UnitPower.watts), ("kW", UnitPower.kilowatts), ("MW", UnitPower.megawatts),
                                    ("hp", UnitPower.horsepower)]),
        Kind(name: "Angle", units: [("°", UnitAngle.degrees), ("rad", UnitAngle.radians), ("grad", UnitAngle.gradians),
                                    ("rev", UnitAngle.revolutions)]),
    ]

    @State private var kindIndex = 0
    @State private var fromIndex = 0
    @State private var toIndex = 1
    @State private var input = "1"

    private var kind: Kind { kinds[kindIndex] }

    private var output: String? {
        guard let v = Double(input.replacingOccurrences(of: ",", with: ".")),
              kind.units.indices.contains(fromIndex), kind.units.indices.contains(toIndex) else { return nil }
        let from = kind.units[fromIndex], to = kind.units[toIndex]
        let converted = Measurement(value: v, unit: from.1).converted(to: to.1).value
        return "\(NumberFormat.general(v)) \(from.0) = \(NumberFormat.general((converted * 1e9).rounded() / 1e9)) \(to.0)"
    }

    var body: some View {
        Form {
            Picker("Quantity", selection: $kindIndex) {
                ForEach(Array(kinds.enumerated()), id: \.offset) { i, k in Text(k.name).tag(i) }
            }
            .onChange(of: kindIndex) { _, _ in fromIndex = 0; toIndex = 1 }
            TextField("Value", text: $input).keyboardType(.decimalPad).font(.title3)
            Picker("From", selection: $fromIndex) {
                ForEach(Array(kind.units.enumerated()), id: \.offset) { i, u in Text(u.0).tag(i) }
            }
            Picker("To", selection: $toIndex) {
                ForEach(Array(kind.units.enumerated()), id: \.offset) { i, u in Text(u.0).tag(i) }
            }
            Button("Swap") {
                let t = fromIndex
                fromIndex = toIndex
                toIndex = t
            }
            if let output {
                Section("Result") { SNInsertRow(title: "", value: output, context: context) }
            }
        }
    }
}

// MARK: - Graph plotter

struct SNGraphView: View {
    @ObservedObject var context: SNContext
    @State private var functions = "sin(x); 0.5*x"
    @State private var xMin = "-6.28"
    @State private var xMax = "6.28"
    @State private var title = ""

    private struct Point: Identifiable {
        let id: Int
        let series: String
        let x: Double
        let y: Double
    }

    private var points: [Point] {
        guard let lo = Double(xMin), let hi = Double(xMax), hi > lo else { return [] }
        var out: [Point] = []
        let exprs = functions.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        for expr in exprs.prefix(4) {
            for i in 0...240 {
                let x = lo + (hi - lo) * Double(i) / 240
                let e = ExpressionEvaluator(variables: ["x": .number(x)])
                if let y = (try? e.evaluate(expr))?.asNumber, y.isFinite, abs(y) < 1e6 {
                    out.append(Point(id: out.count, series: expr, x: x, y: y))
                }
            }
        }
        return out
    }

    private var chart: some View {
        Chart(points) { p in
            LineMark(x: .value("x", p.x), y: .value("y", p.y))
                .foregroundStyle(by: .value("f(x)", p.series))
        }
        .chartXAxisLabel("x")
        .chartYAxisLabel("y")
    }

    var body: some View {
        Form {
            Section {
                TextField("Functions of x, separated by ;", text: $functions)
                    .font(.body.monospaced())
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                HStack {
                    TextField("x from", text: $xMin).keyboardType(.numbersAndPunctuation)
                    TextField("x to", text: $xMax).keyboardType(.numbersAndPunctuation)
                }
                TextField("Title (optional)", text: $title)
            }
            Section {
                if points.isEmpty {
                    Text("Nothing to plot — check the functions and range.").foregroundStyle(.secondary)
                } else {
                    chart.frame(height: 280)
                }
            }
            Section {
                Button("Insert graph into note") { insert() }
                    .buttonStyle(.borderedProminent)
                    .disabled(points.isEmpty)
            }
        }
    }

    @MainActor private func insert() {
        let content = VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty { Text(title).font(.headline) }
            chart.frame(width: 760, height: 440)
        }
        .padding(20)
        .background(SwiftUI.Color.white)
        .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        if let image = renderer.uiImage {
            context.insertImage(image, name: "graph")
        }
    }
}

// MARK: - Builders (presets)

struct SNBuildersView: View {
    @ObservedObject var context: SNContext

    var body: some View {
        List {
            ForEach(["Chemistry", "Physics", "Math"], id: \.self) { category in
                Section(category) {
                    ForEach(PresetLibrary.builtIn.filter { $0.category == category }) { preset in
                        NavigationLink {
                            SNBuilderRunner(preset: preset, context: context)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(preset.name)
                                Text(preset.example).font(.callout).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct SNBuilderRunner: View {
    let preset: Preset
    @ObservedObject var context: SNContext
    @State private var values: [String: String] = [:]
    @State private var edited: Set<String> = []

    private var output: String { PresetEngine.render(preset, values: values) }

    var body: some View {
        Form {
            Section("Result") {
                Text(output).font(.title2).textSelection(.enabled)
                Button("Insert") { context.insert(output) }.buttonStyle(.borderedProminent)
            }
            Section("Values") {
                ForEach(Array(preset.fields.enumerated()), id: \.offset) { index, field in
                    row(field, index: index)
                }
            }
        }
        .navigationTitle(preset.name)
        .onAppear { if values.isEmpty { recompute(from: 0) } }
    }

    private func binding(_ field: PresetField, _ index: Int) -> Binding<String> {
        Binding(get: { values[field.key] ?? "" }, set: {
            values[field.key] = $0
            edited.insert(field.key)
            recompute(from: index + 1)
        })
    }

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

    @ViewBuilder private func row(_ field: PresetField, index: Int) -> some View {
        switch field.kind {
        case .element:
            Picker(field.label, selection: binding(field, index)) {
                ForEach(PeriodicTable.elements) { e in Text("\(e.number) · \(e.symbol) · \(e.name)").tag(e.symbol) }
            }
        case .choice(let options):
            Picker(field.label, selection: binding(field, index)) {
                ForEach(options, id: \.self) { Text($0.isEmpty ? "(none)" : $0).tag($0) }
            }
        case .integer, .number, .charge:
            LabeledContent(field.label) {
                TextField("", text: binding(field, index))
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
            }
        case .text:
            LabeledContent(field.label) {
                TextField("", text: binding(field, index))
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
    }
}

// MARK: - Convert

struct SNConvertView: View {
    @ObservedObject var context: SNContext
    @State private var wholeNote = false

    private var conversions: [(String, (String) -> String)] {
        var list: [(String, (String) -> String)] = [
            ("LaTeX → Unicode   \\alpha^2 → α²", LatexConverter.convert),
            ("Chemistry   H2SO4 → H₂SO₄", ChemFormatter.formatText),
            ("Units   m/s2 → m/s²", ChemFormatter.formatUnits),
            ("Superscript", Scripts.superscript),
            ("Subscript", Scripts.subscripted),
            ("Plain text (undo styles)", { $0.precomposedStringWithCompatibilityMapping }),
        ]
        for style in MathAlphabet.allCases {
            list.append(("\(style.sample)   \(style.title)", { style.apply(to: $0) }))
        }
        return list
    }

    var body: some View {
        Form {
            Section {
                Picker("Apply to", selection: $wholeNote) {
                    Text(context.selectedText.isEmpty ? "Current line" : "Selection").tag(false)
                    Text("Whole note").tag(true)
                }
                .pickerStyle(.segmented)
                if wholeNote && context.hasAttachments {
                    Text("This note contains images, so whole-note conversion is disabled to keep them safe.")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
            Section {
                ForEach(Array(conversions.enumerated()), id: \.offset) { _, item in
                    Button(item.0) {
                        if wholeNote { context.transformWholeNote(item.1) } else { context.transformSelectionOrLine(item.1) }
                    }
                }
            }
        }
    }
}
