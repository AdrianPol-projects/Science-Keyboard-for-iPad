//
//  SNWritingTools.swift
//  Science Notes additions to FSNotes: templates, find & replace, line tools,
//  tables, generators, QR codes, export.
//

import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

// MARK: - Templates

struct SNTemplate: Identifiable {
    let name: String
    let icon: String
    let body: String
    var id: String { name }

    func expanded(title: String) -> String {
        let now = Date()
        let date = DateFormatter()
        date.dateStyle = .long
        let time = DateFormatter()
        time.timeStyle = .short
        let weekday = DateFormatter()
        weekday.dateFormat = "EEEE"
        return body
            .replacingOccurrences(of: "{date}", with: date.string(from: now))
            .replacingOccurrences(of: "{time}", with: time.string(from: now))
            .replacingOccurrences(of: "{weekday}", with: weekday.string(from: now))
            .replacingOccurrences(of: "{title}", with: title)
    }

    static let all: [SNTemplate] = [
        SNTemplate(name: "Lecture notes", icon: "graduationcap", body: """
        # {title}
        **Course:**  · **Lecturer:**  · **Date:** {date}

        ## Key ideas
        -

        ## Definitions
        term :: definition

        ## Equations


        ## Questions to follow up
        - [ ]

        ## Summary

        """),
        SNTemplate(name: "Cornell notes", icon: "rectangle.split.2x1", body: """
        # {title} — Cornell notes ({date})

        | Cues / questions | Notes |
        | --- | --- |
        |  |  |
        |  |  |
        |  |  |

        ## Summary

        """),
        SNTemplate(name: "Lab report", icon: "flask", body: """
        # Lab report: {title}
        **Date:** {date} · **Partners:**

        ## Aim


        ## Hypothesis


        ## Materials & chemicals
        -

        ## Method
        1.

        ## Safety
        - ⚠️

        ## Results
        | Trial | Measurement | Unit |
        | --- | --- | --- |
        | 1 |  |  |

        ## Calculations


        ## Discussion & sources of error


        ## Conclusion

        """),
        SNTemplate(name: "Chemistry problem", icon: "atom", body: """
        ## Problem


        **Given:**
        - m =
        - M =

        **Find:** n = ?

        **Solution:**
        n = m / M =

        **Answer:**
        """),
        SNTemplate(name: "Physics problem (GFSA)", icon: "bolt", body: """
        ## Problem


        **Given:**
        **Find:**
        **Formula:**
        **Substitute:**
        **Answer:**
        """),
        SNTemplate(name: "Exam revision", icon: "checklist", body: """
        # Revision: {title}
        Exam on:

        ## Topics
        - [ ]
        - [ ]
        - [ ]

        ## Flashcards
        Q:
        A:

        ## Weak spots
        -
        """),
        SNTemplate(name: "Meeting", icon: "person.3", body: """
        # Meeting — {date}, {time}
        **Attendees:**

        ## Agenda
        1.

        ## Notes
        -

        ## Action items
        - [ ]  — owner, due
        """),
        SNTemplate(name: "Daily journal", icon: "sun.max", body: """
        # {weekday}, {date}

        **Mood:** 😀 🙂 😐 🙁 😞
        **Grateful for:**

        ## Today
        - [ ]
        - [ ]

        ## Notes


        ## Tomorrow
        -
        """),
        SNTemplate(name: "Weekly plan", icon: "calendar", body: """
        # Week of {date}

        | Day | Plan | Done |
        | --- | --- | --- |
        | Mon |  |  |
        | Tue |  |  |
        | Wed |  |  |
        | Thu |  |  |
        | Fri |  |  |
        | Sat |  |  |
        | Sun |  |  |
        """),
        SNTemplate(name: "Book / paper summary", icon: "book", body: """
        # {title}
        **Author(s):**  · **Year:**  · **Read on:** {date}

        ## One-sentence summary


        ## Key points
        1.

        ## Quotes
        >

        ## My thoughts

        """),
    ]
}

struct SNTemplatesView: View {
    @ObservedObject var context: SNContext

    var body: some View {
        List(SNTemplate.all) { template in
            NavigationLink {
                ScrollView {
                    Text(template.expanded(title: context.noteTitle))
                        .font(.body.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .navigationTitle(template.name)
                .toolbar {
                    Button("Insert") { context.insert(template.expanded(title: context.noteTitle)) }
                        .buttonStyle(.borderedProminent)
                }
            } label: {
                Label(template.name, systemImage: template.icon)
            }
        }
    }
}

// MARK: - Find & replace

struct SNFindReplaceView: View {
    @ObservedObject var context: SNContext
    @State private var find = ""
    @State private var replacement = ""
    @State private var caseSensitive = false
    @State private var useRegex = false
    @State private var wholeWord = false

    private var regex: NSRegularExpression? {
        guard !find.isEmpty else { return nil }
        var pattern = useRegex ? find : NSRegularExpression.escapedPattern(for: find)
        if wholeWord { pattern = "\\b" + pattern + "\\b" }
        return try? NSRegularExpression(pattern: pattern, options: caseSensitive ? [] : [.caseInsensitive])
    }

    private var matches: [NSTextCheckingResult] {
        guard let regex else { return [] }
        let text = context.fullText
        return regex.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length))
            .filter { !(text as NSString).substring(with: $0.range).contains("\u{FFFC}") }
    }

    var body: some View {
        let found = matches
        Form {
            Section {
                TextField("Find", text: $find).autocorrectionDisabled().textInputAutocapitalization(.never)
                TextField(useRegex ? "Replace ($1 = first group)" : "Replace with", text: $replacement)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                Toggle("Match case", isOn: $caseSensitive)
                Toggle("Whole words", isOn: $wholeWord)
                Toggle("Regular expression", isOn: $useRegex)
                if useRegex && !find.isEmpty && regex == nil {
                    Text("Invalid regular expression").foregroundStyle(.orange)
                }
            }
            Section(find.isEmpty ? "" : "\(found.count) match(es)") {
                ForEach(Array(found.prefix(30).enumerated()), id: \.offset) { _, m in
                    Button {
                        context.select(m.range)
                        context.close()
                    } label: {
                        Text(snippet(around: m.range)).font(.callout).lineLimit(2)
                    }
                    .foregroundStyle(.primary)
                }
            }
            Section {
                Button("Replace all") { replaceAll(found) }
                    .buttonStyle(.borderedProminent)
                    .disabled(found.isEmpty)
            }
        }
    }

    private func snippet(around range: NSRange) -> String {
        let ns = context.fullText as NSString
        let start = max(range.location - 30, 0)
        let end = min(NSMaxRange(range) + 30, ns.length)
        return "…" + ns.substring(with: NSRange(location: start, length: end - start))
            .replacingOccurrences(of: "\n", with: " ") + "…"
    }

    private func replaceAll(_ found: [NSTextCheckingResult]) {
        guard let regex else { return }
        let text = context.fullText
        for m in found.reversed() {
            let value = useRegex
                ? regex.replacementString(for: m, in: text, offset: 0, template: replacement)
                : replacement
            context.replace(m.range, with: value)
        }
        context.flash("Replaced \(found.count)")
    }
}

// MARK: - Line tools

struct SNLineToolsView: View {
    @ObservedObject var context: SNContext

    private func lines(_ s: String) -> [String] { s.components(separatedBy: "\n") }

    private var operations: [(String, String, (String) -> String)] {
        [
            ("Sort A → Z", "arrow.up", { lines($0).sorted { $0.localizedStandardCompare($1) == .orderedAscending }.joined(separator: "\n") }),
            ("Sort Z → A", "arrow.down", { lines($0).sorted { $0.localizedStandardCompare($1) == .orderedDescending }.joined(separator: "\n") }),
            ("Reverse order", "arrow.up.arrow.down", { lines($0).reversed().joined(separator: "\n") }),
            ("Shuffle", "shuffle", { lines($0).shuffled().joined(separator: "\n") }),
            ("Remove duplicates", "square.on.square.dashed", { text in
                var seen = Set<String>()
                return lines(text).filter { $0.isEmpty || seen.insert($0).inserted }.joined(separator: "\n")
            }),
            ("Remove empty lines", "text.badge.minus", { lines($0).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: "\n") }),
            ("Trim spaces", "scissors", { lines($0).map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: "\n") }),
            ("Numbered list", "list.number", { text in
                var n = 0
                return lines(text).map { l in
                    guard !l.isEmpty else { return l }
                    n += 1
                    return "\(n). \(Self.stripMarker(l))"
                }.joined(separator: "\n")
            }),
            ("Bullet list", "list.bullet", { lines($0).map { $0.isEmpty ? $0 : "- " + Self.stripMarker($0) }.joined(separator: "\n") }),
            ("Checklist", "checklist", { lines($0).map { $0.isEmpty ? $0 : "- [ ] " + Self.stripMarker($0) }.joined(separator: "\n") }),
            ("Remove list markers", "list.dash", { lines($0).map(Self.stripMarker).joined(separator: "\n") }),
            ("UPPERCASE", "textformat.size.larger", { $0.uppercased() }),
            ("lowercase", "textformat.size.smaller", { $0.lowercased() }),
            ("Title Case", "textformat", { $0.capitalized }),
            ("Join lines", "arrow.right.to.line", { lines($0).filter { !$0.isEmpty }.joined(separator: " ") }),
            ("Quote", "quote.opening", { lines($0).map { "> " + $0 }.joined(separator: "\n") }),
        ]
    }

    static func stripMarker(_ line: String) -> String {
        var l = line.trimmingCharacters(in: .whitespaces)
        for prefix in ["- [ ] ", "- [x] ", "- [X] ", "- ", "* ", "+ "] where l.hasPrefix(prefix) {
            l.removeFirst(prefix.count)
            return l
        }
        if let dot = l.firstIndex(of: "."), l[..<dot].allSatisfy(\.isNumber), !l[..<dot].isEmpty {
            return l[l.index(after: dot)...].trimmingCharacters(in: .whitespaces)
        }
        return l
    }

    var body: some View {
        List {
            Section {
                Text(context.selectedText.isEmpty
                     ? "No selection: tools apply to the whole note (notes with images need a selection)."
                     : "Applies to the selected \(lines(context.selectedText).count) line(s).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(operations.enumerated()), id: \.offset) { _, op in
                Button {
                    if context.selectedText.isEmpty {
                        context.transformWholeNote(op.2)
                    } else {
                        context.transformSelectionOrLine(op.2)
                    }
                } label: {
                    Label(op.0, systemImage: op.1)
                }
            }
        }
    }
}

// MARK: - Table builder

struct SNTableView: View {
    @ObservedObject var context: SNContext
    @State private var rows = 3
    @State private var columns = 3
    @State private var header = true
    @State private var alignment = 0

    private var markdown: String {
        let align = [" --- ", " :--- ", " :---: ", " ---: "][alignment]
        var out: [String] = []
        let cells = Array(repeating: "   ", count: columns)
        if header {
            out.append("|" + (1...columns).map { " Column \($0) " }.joined(separator: "|") + "|")
        } else {
            out.append("|" + cells.joined(separator: "|") + "|")
        }
        out.append("|" + Array(repeating: align, count: columns).joined(separator: "|") + "|")
        for _ in 0..<rows { out.append("|" + cells.joined(separator: "|") + "|") }
        return out.joined(separator: "\n") + "\n"
    }

    var body: some View {
        Form {
            Section("New table") {
                Stepper("Rows: \(rows)", value: $rows, in: 1...30)
                Stepper("Columns: \(columns)", value: $columns, in: 1...10)
                Toggle("Header row", isOn: $header)
                Picker("Alignment", selection: $alignment) {
                    Text("Default").tag(0)
                    Text("Left").tag(1)
                    Text("Center").tag(2)
                    Text("Right").tag(3)
                }
                .pickerStyle(.segmented)
                Text(markdown).font(.caption.monospaced())
                Button("Insert table") { context.insert(markdown) }.buttonStyle(.borderedProminent)
            }
            Section {
                Button("Convert selected CSV / tab-separated text to a table") { convertCSV() }
                    .disabled(context.selectedText.isEmpty)
            } footer: {
                Text("Select lines like “Na, 22.99, 1” and the first line becomes the header.")
            }
        }
    }

    private func convertCSV() {
        context.transformSelectionOrLine { text in
            let lines = text.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            guard let first = lines.first else { return text }
            let separator: Character = first.contains("\t") ? "\t" : (first.contains(";") ? ";" : ",")
            let table = lines.map { $0.split(separator: separator, omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) } }
            let width = table.map(\.count).max() ?? 1
            func row(_ cells: [String]) -> String {
                "| " + (0..<width).map { $0 < cells.count ? cells[$0] : "" }.joined(separator: " | ") + " |"
            }
            var out = [row(table[0]), "|" + Array(repeating: " --- ", count: width).joined(separator: "|") + "|"]
            out += table.dropFirst().map(row)
            return out.joined(separator: "\n")
        }
    }
}

// MARK: - Random & date

struct SNGeneratorsView: View {
    @ObservedObject var context: SNContext
    @State private var minValue = 1
    @State private var maxValue = 100
    @State private var dice = 2
    @State private var sides = 6
    @State private var passwordLength = 16
    @State private var symbols = true
    @State private var paragraphs = 1
    @State private var target = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @State private var event = "Exam"

    private static let lorem = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur."

    private func format(_ style: String, locale: String = "en_US") -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: locale)
        f.dateFormat = style
        return f.string(from: Date())
    }

    var body: some View {
        Form {
            Section("Date & time") {
                SNInsertRow(title: "ISO date", value: format("yyyy-MM-dd"), context: context)
                SNInsertRow(title: "Long date", value: format("EEEE, d MMMM yyyy"), context: context)
                SNInsertRow(title: "Czech date", value: format("EEEE d. MMMM yyyy", locale: "cs_CZ"), context: context)
                SNInsertRow(title: "Time", value: format("HH:mm"), context: context)
                SNInsertRow(title: "Timestamp", value: format("yyyy-MM-dd HH:mm:ss"), context: context)
            }
            Section("Countdown") {
                TextField("Event", text: $event)
                DatePicker("Date", selection: $target, displayedComponents: .date)
                let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()),
                                                           to: Calendar.current.startOfDay(for: target)).day ?? 0
                SNInsertRow(title: "", value: days >= 0 ? "⏳ \(days) day(s) until \(event)" : "\(event) was \(-days) day(s) ago",
                            context: context)
            }
            Section("Random number") {
                Stepper("From \(minValue)", value: $minValue, in: -1000...maxValue)
                Stepper("To \(maxValue)", value: $maxValue, in: minValue...100_000)
                Button("Insert random number") { context.insert(String(Int.random(in: minValue...maxValue))) }
            }
            Section("Dice & coin") {
                Stepper("\(dice) dice", value: $dice, in: 1...10)
                Picker("Sides", selection: $sides) {
                    ForEach([4, 6, 8, 10, 12, 20, 100], id: \.self) { Text("d\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
                Button("Roll") {
                    let rolls = (0..<dice).map { _ in Int.random(in: 1...sides) }
                    context.insert("🎲 \(dice)d\(sides): \(rolls.map(String.init).joined(separator: " + ")) = \(rolls.reduce(0, +))")
                }
                Button("Flip a coin") { context.insert(Bool.random() ? "🪙 Heads" : "🪙 Tails") }
                Button("Pick a random line from the selection") {
                    let options = context.selectedText.components(separatedBy: "\n").filter { !$0.isEmpty }
                    if let pick = options.randomElement() { context.insert("\n🎯 " + pick) } else { context.flash("Select some lines first") }
                }
            }
            Section("Password & IDs") {
                Stepper("Length \(passwordLength)", value: $passwordLength, in: 8...64)
                Toggle("Symbols", isOn: $symbols)
                Button("Insert password") {
                    var chars = Array("abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789")
                    if symbols { chars += Array("!@#$%^&*-_=+?") }
                    context.insert(String((0..<passwordLength).compactMap { _ in chars.randomElement() }))
                }
                Button("Insert UUID") { context.insert(UUID().uuidString) }
            }
            Section("Placeholder text") {
                Stepper("\(paragraphs) paragraph(s)", value: $paragraphs, in: 1...10)
                Button("Insert lorem ipsum") {
                    context.insert(Array(repeating: Self.lorem, count: paragraphs).joined(separator: "\n\n") + "\n")
                }
            }
        }
    }
}

// MARK: - QR code

struct SNQRView: View {
    @ObservedObject var context: SNContext
    @State private var text = ""

    private var image: UIImage? {
        guard !text.isEmpty else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)),
              let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    var body: some View {
        Form {
            Section {
                TextField("Text or link", text: $text, axis: .vertical)
                    .lineLimit(1...5)
            }
            if let image {
                Section {
                    Image(uiImage: image).interpolation(.none).resizable().scaledToFit().frame(maxHeight: 260)
                    Button("Insert QR code") { context.insertImage(image, name: "qr") }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .onAppear { if text.isEmpty { text = context.selectedText } }
    }
}

// MARK: - Export

struct SNExportView: View {
    @ObservedObject var context: SNContext
    @State private var files: [URL] = []

    var body: some View {
        Form {
            Section {
                Button {
                    files = [SNExporter.pdf(context: context)].compactMap { $0 }
                } label: {
                    Label("Create PDF", systemImage: "doc.richtext")
                }
                Button {
                    files = [SNExporter.file(context.fullText.replacingOccurrences(of: "\u{FFFC}", with: ""),
                                             name: context.noteTitle, ext: "md")].compactMap { $0 }
                } label: {
                    Label("Create Markdown file", systemImage: "doc.text")
                }
                Button {
                    files = [SNExporter.file(SNText.plain(context.fullText), name: context.noteTitle, ext: "txt")].compactMap { $0 }
                } label: {
                    Label("Create plain-text file", systemImage: "doc.plaintext")
                }
                Button {
                    SNExporter.print(context: context)
                } label: {
                    Label("Print…", systemImage: "printer")
                }
            } footer: {
                Text("PDF and print use the note's text and headings; inserted images are left out.")
            }
            if let file = files.first {
                Section("Ready") {
                    ShareLink(item: file) {
                        Label("Share \(file.lastPathComponent)", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

enum SNExporter {
    /// Builds a printable attributed string: headings bold and larger, black text.
    static func printable(_ markdown: String, title: String) -> NSAttributedString {
        let out = NSMutableAttributedString()
        let body: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.black]
        out.append(NSAttributedString(string: title + "\n\n", attributes: [.font: UIFont.boldSystemFont(ofSize: 22), .foregroundColor: UIColor.black]))
        for raw in markdown.replacingOccurrences(of: "\u{FFFC}", with: "").components(separatedBy: "\n") {
            if raw.hasPrefix("#") {
                let level = raw.prefix { $0 == "#" }.count
                let text = raw.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)
                let size: CGFloat = level == 1 ? 18 : (level == 2 ? 15 : 13)
                out.append(NSAttributedString(string: text + "\n", attributes: [.font: UIFont.boldSystemFont(ofSize: size), .foregroundColor: UIColor.black]))
            } else {
                out.append(NSAttributedString(string: raw + "\n", attributes: body))
            }
        }
        return out
    }

    static func file(_ text: String, name: String, ext: String) -> URL? {
        let safe = name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safe).\(ext)")
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    static func pdf(context: SNContext) -> URL? {
        let formatter = UISimpleTextPrintFormatter(attributedText: printable(context.fullText, title: context.noteTitle))
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)
        let page = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4
        renderer.setValue(NSValue(cgRect: page), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: page.insetBy(dx: 50, dy: 56)), forKey: "printableRect")
        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, page, [kCGPDFContextTitle as String: context.noteTitle])
        renderer.prepare(forDrawingPages: NSRange(location: 0, length: renderer.numberOfPages))
        for i in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: i, in: UIGraphicsGetPDFContextBounds())
        }
        UIGraphicsEndPDFContext()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(context.noteTitle.replacingOccurrences(of: "/", with: "-") + ".pdf")
        do {
            try (data as Data).write(to: url)
            return url
        } catch {
            return nil
        }
    }

    static func print(context: SNContext) {
        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil)
        info.jobName = context.noteTitle
        info.outputType = .general
        controller.printInfo = info
        controller.printFormatter = UISimpleTextPrintFormatter(attributedText: printable(context.fullText, title: context.noteTitle))
        controller.present(animated: true)
    }
}

// MARK: - About

struct SNAboutView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Science Notes").font(.title.bold())
                    Text("A notes app for science students, built on FSNotes and extended with sketching, scanning, OCR, a calculator, a molar-mass calculator, a periodic table, graphs, flashcards, a focus timer and more.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
            Section("Credits") {
                Link("FSNotes by Oleksandr Glushchenko (MIT license)", destination: URL(string: "https://github.com/glushchenko/fsnotes")!)
                Text("Science engine (LaTeX → Unicode, chemistry formatting, molar mass, expression evaluator, periodic table) shared with the Science Keyboard in this repository.")
                    .font(.callout)
            }
            Section("License") {
                Text("FSNotes is © 2018 Oleksandr Glushchenko and released under the MIT license. The Science Notes additions are released under the same terms.")
                    .font(.callout)
            }
        }
    }
}
