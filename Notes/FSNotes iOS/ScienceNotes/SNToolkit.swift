//
//  SNToolkit.swift
//  Science Notes additions to FSNotes.
//
//  A SwiftUI "toolkit" that is presented from the editor and inserts text or
//  images back into the current note.
//

import SwiftUI
import UIKit

// MARK: - Bridge to the editor

/// Everything a tool needs from the note editor.
final class SNContext: ObservableObject {
    weak var editor: EditorViewController?
    /// Selection when the toolkit was opened; insertions go here.
    private(set) var range: NSRange
    var close: () -> Void = {}
    @Published var toast: String?

    init(editor: EditorViewController) {
        self.editor = editor
        self.range = editor.editArea.selectedRange
    }

    var textView: EditTextView? { editor?.editArea }
    var noteTitle: String { editor?.note?.getName() ?? "Note" }
    var fullText: String { textView?.text ?? "" }
    var hasAttachments: Bool { fullText.contains("\u{FFFC}") }

    var selectedText: String {
        let ns = fullText as NSString
        guard range.length > 0, NSMaxRange(range) <= ns.length else { return "" }
        return ns.substring(with: range)
    }

    /// The line around the cursor, without its trailing newline.
    var currentLineRange: NSRange {
        let ns = fullText as NSString
        let loc = min(range.location, ns.length)
        var r = ns.lineRange(for: NSRange(location: loc, length: 0))
        while r.length > 0, let last = ns.substring(with: NSRange(location: NSMaxRange(r) - 1, length: 1)).first,
              last.isNewline {
            r.length -= 1
        }
        return r
    }

    func flash(_ message: String) {
        toast = message
        let current = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            if self?.toast == current { self?.toast = nil }
        }
    }

    private func clamp(_ r: NSRange) -> NSRange {
        let length = (fullText as NSString).length
        let loc = min(max(r.location, 0), length)
        return NSRange(location: loc, length: min(r.length, length - loc))
    }

    /// Inserts plain text at the saved cursor position (replacing any selection).
    func insert(_ text: String, message: String? = "Inserted") {
        replace(range, with: text)
        if let message { flash(message) }
    }

    func replace(_ target: NSRange, with text: String) {
        guard let tv = textView else { return }
        tv.selectedRange = clamp(target)
        var attributes = tv.typingAttributes
        attributes.removeValue(forKey: .attachmentSave)
        attributes.removeValue(forKey: .backgroundColor)
        tv.insertAttributedText(NSAttributedString(string: text, attributes: attributes))
        range = tv.selectedRange
    }

    func insertImage(_ image: UIImage, name: String) {
        guard let tv = textView, let data = image.pngData(),
              let attachment = NSMutableAttributedString.build(
                data: data, preferredName: "\(name)-\(UUID().uuidString.prefix(8)).png") else {
            flash("Couldn’t insert the image")
            return
        }
        attachment.append(NSAttributedString(string: "\n\n"))
        tv.selectedRange = clamp(range)
        tv.insertAttributedText(attachment)
        range = tv.selectedRange
        flash("Image inserted")
    }

    /// Applies a transform to the selection, or else to the current line.
    func transformSelectionOrLine(_ f: (String) -> String) {
        let target = range.length > 0 ? range : currentLineRange
        let ns = fullText as NSString
        guard target.length > 0, NSMaxRange(target) <= ns.length else {
            flash("Select text or put the cursor on a line")
            return
        }
        let original = ns.substring(with: target)
        let result = f(original)
        guard result != original else { flash("Nothing to change"); return }
        replace(target, with: result)
        flash("Converted")
    }

    /// Applies a transform to the whole note; refused when the note contains images.
    func transformWholeNote(_ f: (String) -> String) {
        guard !hasAttachments else {
            flash("This note has images — select the text to convert instead")
            return
        }
        let text = fullText
        let result = f(text)
        guard result != text else { flash("Nothing to change"); return }
        replace(NSRange(location: 0, length: (text as NSString).length), with: result)
        flash("Converted the whole note")
    }

    func select(_ target: NSRange) {
        guard let tv = textView else { return }
        let r = clamp(target)
        tv.selectedRange = r
        tv.scrollRangeToVisible(r)
        range = r
    }
}

// MARK: - Tools

enum SNTool: String, CaseIterable, Identifiable, Hashable {
    // Capture
    case sketch, scan, photoText, readAloud
    // Science
    case calculator, solveLines, molarMass, periodicTable, symbols, constants, units, graph, builders, convert
    // Study
    case stats, outline, flashcards, focus
    // Writing
    case templates, findReplace, transform, table, generators, qrCode, export, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sketch: return "Sketch & handwriting"
        case .scan: return "Scan document"
        case .photoText: return "Text from photo"
        case .readAloud: return "Read aloud"
        case .calculator: return "Calculator"
        case .solveLines: return "Solve “=” lines"
        case .molarMass: return "Molar mass"
        case .periodicTable: return "Periodic table"
        case .symbols: return "Symbols"
        case .constants: return "Physical constants"
        case .units: return "Unit converter"
        case .graph: return "Graph plotter"
        case .builders: return "Notation builders"
        case .convert: return "Convert text"
        case .stats: return "Statistics"
        case .outline: return "Outline & contents"
        case .flashcards: return "Flashcards"
        case .focus: return "Focus timer"
        case .templates: return "Templates"
        case .findReplace: return "Find & replace"
        case .transform: return "Line tools"
        case .table: return "Table builder"
        case .generators: return "Random & date"
        case .qrCode: return "QR code"
        case .export: return "Export & print"
        case .about: return "About Science Notes"
        }
    }

    var subtitle: String {
        switch self {
        case .sketch: return "Draw with Apple Pencil on plain, lined, grid or dotted paper"
        case .scan: return "Camera scan as images and/or recognized text"
        case .photoText: return "Recognize text in a photo (English & Czech)"
        case .readAloud: return "Listen to the note or selection"
        case .calculator: return "Scientific calculator with constants"
        case .solveLines: return "Fill in every line ending with =, like 2·π·3 ="
        case .molarMass: return "M(H₂O) = 2·1.008 + 15.999 = 18.015 g·mol⁻¹"
        case .periodicTable: return "Elements, nuclides, configurations"
        case .symbols: return "Greek, math, arrows, chemistry, physics…"
        case .constants: return "c, h, ℏ, Nₐ, R, G … with values"
        case .units: return "Length, mass, temperature, energy, pressure…"
        case .graph: return "Plot y = f(x) and insert it as an image"
        case .builders: return "Nuclides, decays, integrals, fractions…"
        case .convert: return "LaTeX → Unicode, chemistry, units, styles"
        case .stats: return "Words, reading time, top words, to-dos"
        case .outline: return "Jump to headings, insert a table of contents"
        case .flashcards: return "Study “term :: definition” and Q:/A: lines"
        case .focus: return "Pomodoro timer that logs sessions to the note"
        case .templates: return "Lecture, Cornell, lab report, journal…"
        case .findReplace: return "With regular expressions and match count"
        case .transform: return "Sort, dedupe, number, checkbox, case…"
        case .table: return "Markdown tables, CSV → table"
        case .generators: return "Dice, coin, passwords, dates, lorem ipsum"
        case .qrCode: return "Turn text or a link into a QR image"
        case .export: return "PDF, print, Markdown or plain text"
        case .about: return "Credits and license"
        }
    }

    var icon: String {
        switch self {
        case .sketch: return "pencil.tip.crop.circle"
        case .scan: return "doc.viewfinder"
        case .photoText: return "text.viewfinder"
        case .readAloud: return "speaker.wave.2"
        case .calculator: return "function"
        case .solveLines: return "equal.square"
        case .molarMass: return "scalemass"
        case .periodicTable: return "atom"
        case .symbols: return "sum"
        case .constants: return "c.circle"
        case .units: return "ruler"
        case .graph: return "chart.xyaxis.line"
        case .builders: return "wand.and.stars"
        case .convert: return "arrow.triangle.2.circlepath"
        case .stats: return "chart.bar"
        case .outline: return "list.bullet.indent"
        case .flashcards: return "rectangle.on.rectangle.angled"
        case .focus: return "timer"
        case .templates: return "doc.text"
        case .findReplace: return "magnifyingglass"
        case .transform: return "arrow.up.arrow.down"
        case .table: return "tablecells"
        case .generators: return "dice"
        case .qrCode: return "qrcode"
        case .export: return "square.and.arrow.up"
        case .about: return "info.circle"
        }
    }

    static let sections: [(String, [SNTool])] = [
        ("Capture", [.sketch, .scan, .photoText, .readAloud]),
        ("Science", [.calculator, .solveLines, .molarMass, .periodicTable, .symbols, .constants, .units, .graph, .builders, .convert]),
        ("Study", [.stats, .outline, .flashcards, .focus]),
        ("Writing", [.templates, .findReplace, .transform, .table, .generators, .qrCode, .export]),
        ("", [.about]),
    ]
}

// MARK: - Root view

struct SNToolkitView: View {
    @ObservedObject var context: SNContext
    @State private var path: [SNTool]
    @State private var query = ""

    init(context: SNContext, start: SNTool?) {
        self.context = context
        _path = State(initialValue: start.map { [$0] } ?? [])
    }

    private func matches(_ tool: SNTool) -> Bool {
        query.isEmpty || tool.title.localizedCaseInsensitiveContains(query)
            || tool.subtitle.localizedCaseInsensitiveContains(query)
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(Array(SNTool.sections.enumerated()), id: \.offset) { _, section in
                    let tools = section.1.filter(matches)
                    if !tools.isEmpty {
                        Section(section.0) {
                            ForEach(tools) { tool in
                                NavigationLink(value: tool) {
                                    HStack(spacing: 14) {
                                        SwiftUI.Image(systemName: tool.icon)
                                            .font(.title3)
                                            .foregroundStyle(SwiftUI.Color.accentColor)
                                            .frame(width: 32)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(tool.title)
                                            Text(tool.subtitle).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Find a tool")
            .navigationTitle("Toolkit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { context.close() }
                }
            }
            .navigationDestination(for: SNTool.self) { tool in
                SNToolScreen(tool: tool, context: context)
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = context.toast {
                Text(toast)
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 28)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: context.toast)
    }
}

struct SNToolScreen: View {
    let tool: SNTool
    @ObservedObject var context: SNContext

    var body: some View {
        content
            .navigationTitle(tool.title)
            .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var content: some View {
        switch tool {
        case .sketch: SNSketchView(context: context)
        case .scan: SNScanView(context: context)
        case .photoText: SNPhotoTextView(context: context)
        case .readAloud: SNReadAloudView(context: context)
        case .calculator: SNCalculatorView(context: context)
        case .solveLines: SNSolveLinesView(context: context)
        case .molarMass: SNMolarMassView(context: context)
        case .periodicTable: SNPeriodicTableView(context: context)
        case .symbols: SNSymbolsView(context: context)
        case .constants: SNConstantsView(context: context)
        case .units: SNUnitsView(context: context)
        case .graph: SNGraphView(context: context)
        case .builders: SNBuildersView(context: context)
        case .convert: SNConvertView(context: context)
        case .stats: SNStatsView(context: context)
        case .outline: SNOutlineView(context: context)
        case .flashcards: SNFlashcardsView(context: context)
        case .focus: SNFocusView(context: context)
        case .templates: SNTemplatesView(context: context)
        case .findReplace: SNFindReplaceView(context: context)
        case .transform: SNLineToolsView(context: context)
        case .table: SNTableView(context: context)
        case .generators: SNGeneratorsView(context: context)
        case .qrCode: SNQRView(context: context)
        case .export: SNExportView(context: context)
        case .about: SNAboutView()
        }
    }
}

/// A row showing a result with an Insert button.
struct SNInsertRow: View {
    let title: String
    let value: String
    let context: SNContext

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if !title.isEmpty {
                    Text(title).font(.caption).foregroundStyle(.secondary)
                }
                Text(value).font(.body).textSelection(.enabled)
            }
            Spacer(minLength: 8)
            Button("Insert") { context.insert(value) }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
    }
}

// MARK: - Presenting from the editor

extension EditorViewController {
    @objc func openScienceToolkit() {
        presentScienceToolkit(start: nil)
    }

    @objc func openSketchTool() {
        presentScienceToolkit(start: .sketch)
    }

    @objc func openScanTool() {
        presentScienceToolkit(start: .scan)
    }

    @objc func openCalculatorTool() {
        presentScienceToolkit(start: .calculator)
    }

    func presentScienceToolkit(start: SNTool?) {
        guard note != nil else { return }
        let context = SNContext(editor: self)
        let host = UIHostingController(rootView: SNToolkitView(context: context, start: start))
        host.modalPresentationStyle = start == .sketch ? .fullScreen : .pageSheet
        if let sheet = host.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        context.close = { [weak host] in host?.dismiss(animated: true) }
        present(host, animated: true)
    }

    /// Extra buttons appended to the editor's keyboard toolbar.
    func scienceToolbarItems() -> [UIBarButtonItem] {
        [
            UIBarButtonItem(systemImageName: "pencil.tip.crop.circle", target: self, selector: #selector(openSketchTool)),
            UIBarButtonItem(systemImageName: "doc.viewfinder", target: self, selector: #selector(openScanTool)),
            UIBarButtonItem(systemImageName: "function", target: self, selector: #selector(openCalculatorTool)),
            UIBarButtonItem(systemImageName: "square.grid.2x2", target: self, selector: #selector(openScienceToolkit)),
        ]
    }
}
