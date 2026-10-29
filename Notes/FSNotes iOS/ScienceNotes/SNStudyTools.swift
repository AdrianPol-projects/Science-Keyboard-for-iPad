//
//  SNStudyTools.swift
//  Science Notes additions to FSNotes: statistics, outline, flashcards, focus timer.
//

import AudioToolbox
import Combine
import SwiftUI

// MARK: - Statistics

struct SNStatsView: View {
    @ObservedObject var context: SNContext

    private static let stopWords: Set<String> = [
        "the", "a", "an", "and", "or", "of", "to", "in", "on", "is", "are", "was", "were", "be", "for", "with", "as",
        "at", "by", "it", "this", "that", "from", "not", "but", "if", "then", "so", "we", "you", "i", "he", "she", "they",
        "v", "na", "se", "je", "že", "s", "z", "do", "o", "k", "pro", "jako", "ale", "nebo", "si",
        "jsou", "být", "který", "která", "které", "po", "u", "ve", "od", "za",
    ]

    var body: some View {
        let raw = context.fullText
        let plain = SNText.plain(raw)
        let words = SNText.words(plain)
        let lines = raw.components(separatedBy: "\n")
        let paragraphs = raw.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var sentenceCount = 0
        plain.enumerateSubstrings(in: plain.startIndex..., options: .bySentences) { _, _, _, _ in sentenceCount += 1 }
        let headings = lines.filter { $0.hasPrefix("#") }.count
        let todosOpen = lines.filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("- [ ]") }.count
        let todosDone = lines.filter { $0.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("- [x]") }.count
        let images = raw.filter { $0 == "\u{FFFC}" }.count
        var tally: [String: Int] = [:]
        for word in words {
            let w = word.lowercased()
            if w.count > 2 && !Self.stopWords.contains(w) { tally[w, default: 0] += 1 }
        }
        let counts: [(key: String, value: Int)] = tally.sorted { (a: (key: String, value: Int), b: (key: String, value: Int)) -> Bool in
            a.value == b.value ? a.key < b.key : a.value > b.value
        }
        let longest = words.max { $0.count < $1.count } ?? "—"

        return Form {
            Section("Counts") {
                LabeledContent("Words", value: "\(words.count)")
                LabeledContent("Characters", value: "\(plain.count)")
                LabeledContent("Characters (no spaces)", value: "\(plain.filter { !$0.isWhitespace }.count)")
                LabeledContent("Sentences", value: "\(sentenceCount)")
                LabeledContent("Paragraphs", value: "\(paragraphs.count)")
                LabeledContent("Lines", value: "\(lines.count)")
                LabeledContent("Headings", value: "\(headings)")
                LabeledContent("Images", value: "\(images)")
            }
            Section("Time") {
                LabeledContent("Reading (230 wpm)", value: duration(Double(words.count) / 230))
                LabeledContent("Speaking (150 wpm)", value: duration(Double(words.count) / 150))
                LabeledContent("Handwriting (25 wpm)", value: duration(Double(words.count) / 25))
            }
            if todosOpen + todosDone > 0 {
                Section("To-dos") {
                    ProgressView(value: Double(todosDone), total: Double(todosOpen + todosDone)) {
                        Text("\(todosDone) of \(todosOpen + todosDone) done")
                    }
                }
            }
            Section("Most used words") {
                ForEach(Array(counts.prefix(12).enumerated()), id: \.offset) { _, item in
                    LabeledContent(item.key, value: "\(item.value)×")
                }
                LabeledContent("Longest word", value: longest)
                LabeledContent("Unique words", value: "\(Set(words.map { $0.lowercased() }).count)")
            }
            Section {
                Button("Insert summary") {
                    context.insert("> \(words.count) words · \(sentenceCount) sentences · \(duration(Double(words.count) / 230)) read\n")
                }
            }
        }
    }

    private func duration(_ minutes: Double) -> String {
        if minutes < 1 { return "\(Int((minutes * 60).rounded())) s" }
        if minutes < 60 { return "\(Int(minutes.rounded())) min" }
        return "\(Int(minutes) / 60) h \(Int(minutes) % 60) min"
    }
}

// MARK: - Outline

struct SNOutlineView: View {
    @ObservedObject var context: SNContext

    private struct Heading: Identifiable {
        let id: Int
        let level: Int
        let title: String
        let range: NSRange
    }

    private var headings: [Heading] {
        let ns = context.fullText as NSString
        var out: [Heading] = []
        var inCode = false
        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: .byLines) { line, range, _, _ in
            guard let line else { return }
            if line.hasPrefix("```") { inCode.toggle() }
            guard !inCode, line.hasPrefix("#") else { return }
            let level = line.prefix { $0 == "#" }.count
            let title = line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)
            guard level <= 6, !title.isEmpty else { return }
            out.append(Heading(id: out.count, level: level, title: title, range: range))
        }
        return out
    }

    var body: some View {
        let items = headings
        List {
            if items.isEmpty {
                Text("No headings yet. Start lines with #, ## or ### to build an outline.")
                    .foregroundStyle(.secondary)
            } else {
                Section("Tap to jump") {
                    ForEach(items) { h in
                        Button {
                            context.select(NSRange(location: h.range.location, length: 0))
                            context.close()
                        } label: {
                            Text(h.title)
                                .font(h.level == 1 ? .headline : .body)
                                .padding(.leading, CGFloat(h.level - 1) * 16)
                        }
                        .foregroundStyle(.primary)
                    }
                }
                Section {
                    Button("Insert table of contents") {
                        let toc = items.map { String(repeating: "  ", count: $0.level - 1) + "- [[\(context.noteTitle)#\($0.title)|\($0.title)]]" }
                        context.insert("## Contents\n" + toc.joined(separator: "\n") + "\n\n")
                    }
                    Button("Insert plain outline") {
                        let outline = items.map { String(repeating: "  ", count: $0.level - 1) + "- " + $0.title }
                        context.insert(outline.joined(separator: "\n") + "\n")
                    }
                }
            }
        }
    }
}

// MARK: - Flashcards

struct SNCard: Identifiable, Equatable {
    let id = UUID()
    let front: String
    let back: String
}

enum SNCardParser {
    /// Supports "term :: definition", "term = definition" (not math), and "Q: … / A: …" pairs.
    static func cards(from text: String) -> [SNCard] {
        var cards: [SNCard] = []
        var pendingQuestion: String?
        for raw in text.components(separatedBy: "\n") {
            var line = raw.trimmingCharacters(in: .whitespaces)
            for prefix in ["- ", "* "] where line.hasPrefix(prefix) { line.removeFirst(prefix.count) }
            if line.lowercased().hasPrefix("q:") {
                pendingQuestion = line.dropFirst(2).trimmingCharacters(in: .whitespaces)
                continue
            }
            if line.lowercased().hasPrefix("a:"), let q = pendingQuestion {
                cards.append(SNCard(front: q, back: line.dropFirst(2).trimmingCharacters(in: .whitespaces)))
                pendingQuestion = nil
                continue
            }
            if let r = line.range(of: "::") {
                let front = line[..<r.lowerBound].trimmingCharacters(in: .whitespaces)
                let back = line[r.upperBound...].trimmingCharacters(in: .whitespaces)
                if !front.isEmpty && !back.isEmpty { cards.append(SNCard(front: front, back: back)) }
            }
        }
        return cards
    }
}

struct SNFlashcardsView: View {
    @ObservedObject var context: SNContext
    @State private var deck: [SNCard] = []
    @State private var index = 0
    @State private var flipped = false
    @State private var known = 0
    @State private var again: [SNCard] = []
    @State private var finished = false

    var body: some View {
        VStack(spacing: 20) {
            if deck.isEmpty && !finished {
                ContentUnavailableView {
                    Label("No flashcards in this note", systemImage: "rectangle.on.rectangle.angled")
                } description: {
                    Text("Write lines like “mitochondria :: powerhouse of the cell”, or a “Q: …” line followed by an “A: …” line.")
                } actions: {
                    Button("Insert an example") {
                        context.insert("Q: What is the molar mass of water?\nA: 18.015 g·mol⁻¹\nAvogadro constant :: 6.022 × 10²³ mol⁻¹\n")
                        load()
                    }
                }
            } else if finished {
                Spacer()
                Text("🎉").font(.system(size: 64))
                Text("Done! \(known) known on the first try.").font(.title2)
                Button("Study again") { load() }.buttonStyle(.borderedProminent)
                Spacer()
            } else {
                Text("Card \(index + 1) of \(deck.count) · \(again.count) to repeat")
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(index), total: Double(max(deck.count, 1)))
                    .padding(.horizontal)
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(flipped ? SwiftUI.Color.accentColor.opacity(0.15) : SwiftUI.Color(.secondarySystemBackground))
                        .shadow(radius: 4, y: 2)
                    Text(flipped ? deck[index].back : deck[index].front)
                        .font(.title)
                        .multilineTextAlignment(.center)
                        .padding(30)
                }
                .frame(maxWidth: 640, minHeight: 260)
                .padding(.horizontal)
                .rotation3DEffect(.degrees(flipped ? 360 : 0), axis: (x: 0, y: 1, z: 0))
                .animation(.spring(duration: 0.45), value: flipped)
                .onTapGesture { flipped.toggle() }
                Text("Tap the card to flip it").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 20) {
                    Button { answer(knewIt: false) } label: {
                        Label("Again", systemImage: "arrow.counterclockwise").frame(minWidth: 120)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    Button { answer(knewIt: true) } label: {
                        Label("Got it", systemImage: "checkmark").frame(minWidth: 120)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                .controlSize(.large)
                Spacer()
            }
        }
        .padding(.top)
        .toolbar {
            Button { load() } label: { SwiftUI.Image(systemName: "shuffle") }
        }
        .onAppear(perform: load)
    }

    private func load() {
        let source = context.selectedText.isEmpty ? context.fullText : context.selectedText
        deck = SNCardParser.cards(from: source).shuffled()
        index = 0
        known = 0
        again = []
        flipped = false
        finished = false
    }

    private func answer(knewIt: Bool) {
        let card = deck[index]
        if knewIt { known += 1 } else { again.append(card) }
        flipped = false
        if index + 1 < deck.count {
            index += 1
        } else if !again.isEmpty {
            deck = again.shuffled()
            again = []
            index = 0
        } else {
            finished = true
            deck = []
        }
    }
}

// MARK: - Focus timer

struct SNFocusView: View {
    @ObservedObject var context: SNContext
    @AppStorage("sn.focus.minutes") private var focusMinutes = 25
    @AppStorage("sn.focus.break") private var breakMinutes = 5
    @State private var remaining = 25 * 60
    @State private var total = 25 * 60
    @State private var running = false
    @State private var onBreak = false
    @State private var sessions = 0
    @State private var started: Date?
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 24) {
            Text(onBreak ? "Break" : "Focus").font(.title2.weight(.semibold)).foregroundStyle(onBreak ? SwiftUI.Color.green : SwiftUI.Color.accentColor)
            ZStack {
                Circle().stroke(SwiftUI.Color.secondary.opacity(0.2), lineWidth: 16)
                Circle()
                    .trim(from: 0, to: CGFloat(1 - Double(remaining) / Double(max(total, 1))))
                    .stroke(onBreak ? SwiftUI.Color.green : SwiftUI.Color.accentColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: remaining)
                Text(String(format: "%02d:%02d", remaining / 60, remaining % 60))
                    .font(.system(size: 64, weight: .light, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: 280, height: 280)
            HStack(spacing: 16) {
                Button(running ? "Pause" : "Start") { running.toggle(); if running && started == nil { started = Date() } }
                    .buttonStyle(.borderedProminent)
                Button("Reset") { reset(break: false) }.buttonStyle(.bordered)
                Button("Skip") { finish() }.buttonStyle(.bordered)
            }
            .controlSize(.large)
            Form {
                Stepper("Focus: \(focusMinutes) min", value: $focusMinutes, in: 5...90, step: 5)
                    .onChange(of: focusMinutes) { _, _ in if !running && !onBreak { reset(break: false) } }
                Stepper("Break: \(breakMinutes) min", value: $breakMinutes, in: 1...30)
                LabeledContent("Sessions today", value: "\(sessions) 🍅")
            }
            .frame(maxHeight: 200)
        }
        .padding(.top, 20)
        .onAppear { if !running { reset(break: false) } }
        .onReceive(tick) { _ in
            guard running else { return }
            if remaining > 0 { remaining -= 1 } else { finish() }
        }
    }

    private func reset(break isBreak: Bool) {
        onBreak = isBreak
        total = (isBreak ? breakMinutes : focusMinutes) * 60
        remaining = total
    }

    private func finish() {
        AudioServicesPlaySystemSound(1005)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if !onBreak {
            sessions += 1
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            context.insert("- 🍅 Focus session \(sessions): \(focusMinutes) min, finished \(f.string(from: Date()))\n",
                           message: "Session logged to the note")
        }
        reset(break: !onBreak)
        running = true
        started = nil
    }
}
