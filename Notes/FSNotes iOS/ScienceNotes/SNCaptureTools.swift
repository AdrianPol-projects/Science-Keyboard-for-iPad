//
//  SNCaptureTools.swift
//  Science Notes additions to FSNotes: sketching, scanning, OCR, read aloud.
//

import AVFoundation
import PencilKit
import PhotosUI
import SwiftUI
import Vision
import VisionKit

// MARK: - Sketch (PencilKit)

enum SNPaper: String, CaseIterable, Identifiable {
    case plain, lined, grid, dots
    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    /// A small tile repeated as the canvas background.
    func tile(spacing: CGFloat = 28) -> UIImage {
        let size = CGSize(width: spacing, height: spacing)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let line = UIColor(red: 0.62, green: 0.74, blue: 0.9, alpha: 0.7)
            line.setStroke()
            line.setFill()
            let path = UIBezierPath()
            path.lineWidth = 0.6
            switch self {
            case .plain:
                return
            case .lined:
                path.move(to: CGPoint(x: 0, y: spacing - 0.5))
                path.addLine(to: CGPoint(x: spacing, y: spacing - 0.5))
            case .grid:
                path.move(to: CGPoint(x: 0, y: spacing - 0.5))
                path.addLine(to: CGPoint(x: spacing, y: spacing - 0.5))
                path.move(to: CGPoint(x: spacing - 0.5, y: 0))
                path.addLine(to: CGPoint(x: spacing - 0.5, y: spacing))
            case .dots:
                UIBezierPath(ovalIn: CGRect(x: spacing / 2 - 1, y: spacing / 2 - 1, width: 2, height: 2)).fill()
                return
            }
            path.stroke()
        }
    }
}

struct SNCanvas: UIViewRepresentable {
    let canvas: PKCanvasView
    let picker: PKToolPicker
    let paper: SNPaper
    let fingerDrawing: Bool

    func makeUIView(context: Context) -> PKCanvasView {
        canvas.overrideUserInterfaceStyle = .light
        canvas.isOpaque = true
        canvas.alwaysBounceVertical = true
        canvas.contentSize = CGSize(width: 2000, height: 3000)
        picker.addObserver(canvas)
        picker.setVisible(true, forFirstResponder: canvas)
        DispatchQueue.main.async { canvas.becomeFirstResponder() }
        return canvas
    }

    func updateUIView(_ view: PKCanvasView, context: Context) {
        view.backgroundColor = UIColor(patternImage: paper.tile())
        view.drawingPolicy = fingerDrawing ? .anyInput : .pencilOnly
    }
}

struct SNSketchView: View {
    let context: SNContext
    @State private var canvas = PKCanvasView()
    @State private var picker = PKToolPicker()
    @State private var paper: SNPaper = .grid
    @State private var fingerDrawing = true
    @State private var includePaper = false

    var body: some View {
        SNCanvas(canvas: canvas, picker: picker, paper: paper, fingerDrawing: fingerDrawing)
            .ignoresSafeArea(edges: .bottom)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Picker("Paper", selection: $paper) {
                            ForEach(SNPaper.allCases) { Text($0.title).tag($0) }
                        }
                        Toggle("Draw with finger", isOn: $fingerDrawing)
                        Toggle("Keep paper in image", isOn: $includePaper)
                        Button("Clear page", role: .destructive) { canvas.drawing = PKDrawing() }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    Button { canvas.undoManager?.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                    Button { canvas.undoManager?.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                    Button("Insert") { insert() }
                        .buttonStyle(.borderedProminent)
                }
            }
    }

    private func insert() {
        let drawing = canvas.drawing
        guard !drawing.bounds.isEmpty else {
            context.flash("Draw something first")
            return
        }
        let bounds = drawing.bounds.insetBy(dx: -24, dy: -24)
        var ink = UIImage()
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            ink = drawing.image(from: bounds, scale: 2)
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let image = UIGraphicsImageRenderer(size: bounds.size, format: format).image { ctx in
            if includePaper {
                UIColor(patternImage: paper.tile()).setFill()
            } else {
                UIColor.white.setFill()
            }
            ctx.fill(CGRect(origin: .zero, size: bounds.size))
            ink.draw(in: CGRect(origin: .zero, size: bounds.size))
        }
        context.insertImage(image, name: "sketch")
        canvas.drawing = PKDrawing()
    }
}

// MARK: - Text recognition

enum SNTextRecognizer {
    /// Prefers English and Czech when the device supports them.
    static func languages() -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        let supported = (try? request.supportedRecognitionLanguages()) ?? []
        let wanted = ["en-US", "cs-CZ", "en-GB", "de-DE"]
        let chosen = wanted.filter { supported.contains($0) }
        return chosen.isEmpty ? ["en-US"] : chosen
    }

    static func recognize(_ image: UIImage) -> String {
        guard let cg = image.cgImage else { return "" }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = languages()
        let handler = VNImageRequestHandler(cgImage: cg, orientation: cgOrientation(image.imageOrientation))
        try? handler.perform([request])
        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        return lines.joined(separator: "\n")
    }

    private static func cgOrientation(_ o: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch o {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}

// MARK: - Document scanner

struct SNDocumentScanner: UIViewControllerRepresentable {
    let onFinish: ([UIImage]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onFinish: ([UIImage]) -> Void
        init(onFinish: @escaping ([UIImage]) -> Void) { self.onFinish = onFinish }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            onFinish((0..<scan.pageCount).map { scan.imageOfPage(at: $0) })
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onFinish([])
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            onFinish([])
        }
    }
}

struct SNScanView: View {
    let context: SNContext
    @State private var showScanner = false
    @State private var pages: [UIImage] = []
    @State private var text = ""
    @State private var recognizing = false
    @State private var insertImages = true
    @State private var insertText = true

    var body: some View {
        Form {
            Section {
                Button {
                    showScanner = true
                } label: {
                    Label(pages.isEmpty ? "Start scanning" : "Scan again", systemImage: "doc.viewfinder")
                }
                .disabled(!VNDocumentCameraViewController.isSupported)
                if !VNDocumentCameraViewController.isSupported {
                    Text("This device has no camera that supports document scanning.")
                        .foregroundStyle(.secondary)
                }
            }
            if !pages.isEmpty {
                Section("\(pages.count) page(s)") {
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(Array(pages.enumerated()), id: \.offset) { _, page in
                                Image(uiImage: page).resizable().scaledToFit().frame(height: 160)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    Toggle("Insert the pages as images", isOn: $insertImages)
                    Toggle("Insert the recognized text", isOn: $insertText)
                }
                Section(recognizing ? "Recognizing text…" : "Recognized text (editable)") {
                    TextEditor(text: $text).frame(minHeight: 180)
                }
                Section {
                    Button("Insert into note") {
                        if insertImages { pages.forEach { context.insertImage($0, name: "scan") } }
                        if insertText && !text.isEmpty { context.insert(text + "\n") }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            SNDocumentScanner { images in
                showScanner = false
                guard !images.isEmpty else { return }
                pages = images
                recognize()
            }
            .ignoresSafeArea()
        }
    }

    private func recognize() {
        recognizing = true
        let images = pages
        Task.detached(priority: .userInitiated) {
            let result = images.map { SNTextRecognizer.recognize($0) }.joined(separator: "\n\n")
            await MainActor.run {
                text = result
                recognizing = false
            }
        }
    }
}

struct SNPhotoTextView: View {
    let context: SNContext
    @State private var item: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var text = ""
    @State private var working = false

    var body: some View {
        Form {
            Section {
                PhotosPicker(selection: $item, matching: .images) {
                    Label("Choose a photo", systemImage: "photo")
                }
                Text("Languages: \(SNTextRecognizer.languages().joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let image {
                Section {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 220)
                }
            }
            if working || !text.isEmpty {
                Section(working ? "Recognizing…" : "Text (editable)") {
                    TextEditor(text: $text).frame(minHeight: 200)
                    Button("Insert text") { context.insert(text + "\n") }
                        .buttonStyle(.borderedProminent)
                        .disabled(text.isEmpty)
                }
            }
        }
        .onChange(of: item) { _, newItem in
            guard let newItem else { return }
            working = true
            text = ""
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                    image = img
                    let result = await Task.detached(priority: .userInitiated) { SNTextRecognizer.recognize(img) }.value
                    text = result.isEmpty ? "" : result
                    if result.isEmpty { context.flash("No text found") }
                }
                working = false
            }
        }
    }
}

// MARK: - Read aloud

final class SNSpeaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    private let synth = AVSpeechSynthesizer()
    @Published var speaking = false
    @Published var paused = false
    @Published var progress: Double = 0
    private var length = 1

    override init() {
        super.init()
        synth.delegate = self
    }

    func speak(_ text: String, language: String, rate: Float) {
        stop()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: language)
        u.rate = rate
        length = max((text as NSString).length, 1)
        synth.speak(u)
        speaking = true
        paused = false
    }

    func togglePause() {
        if synth.isPaused {
            synth.continueSpeaking()
            paused = false
        } else {
            synth.pauseSpeaking(at: .word)
            paused = true
        }
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        speaking = false
        paused = false
        progress = 0
    }

    func speechSynthesizer(_ s: AVSpeechSynthesizer, willSpeakRangeOfSpeechString range: NSRange, utterance: AVSpeechUtterance) {
        let value = Double(NSMaxRange(range)) / Double(length)
        DispatchQueue.main.async { self.progress = value }
    }

    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.speaking = false
            self.progress = 1
        }
    }
}

struct SNReadAloudView: View {
    let context: SNContext
    @StateObject private var speaker = SNSpeaker()
    @State private var language = "en-US"
    @State private var rate: Double = Double(AVSpeechUtteranceDefaultSpeechRate)
    @State private var selectionOnly = false

    private let languages = [("English (US)", "en-US"), ("English (UK)", "en-GB"), ("Čeština", "cs-CZ"),
                             ("Deutsch", "de-DE"), ("Français", "fr-FR"), ("Español", "es-ES")]

    private var text: String {
        let source = selectionOnly && !context.selectedText.isEmpty ? context.selectedText : context.fullText
        return SNText.plain(source)
    }

    var body: some View {
        Form {
            Section {
                Picker("Voice", selection: $language) {
                    ForEach(languages, id: \.1) { Text($0.0).tag($0.1) }
                }
                VStack(alignment: .leading) {
                    Text("Speed")
                    Slider(value: $rate, in: Double(AVSpeechUtteranceMinimumSpeechRate)...Double(AVSpeechUtteranceMaximumSpeechRate))
                }
                Toggle("Only the selection", isOn: $selectionOnly)
                    .disabled(context.selectedText.isEmpty)
            }
            Section {
                ProgressView(value: speaker.progress)
                HStack(spacing: 20) {
                    Button {
                        speaker.speak(text, language: language, rate: Float(rate))
                    } label: {
                        Label("Read", systemImage: "play.fill")
                    }
                    Button {
                        speaker.togglePause()
                    } label: {
                        Label(speaker.paused ? "Resume" : "Pause", systemImage: speaker.paused ? "play" : "pause")
                    }
                    .disabled(!speaker.speaking)
                    Button(role: .destructive) {
                        speaker.stop()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .disabled(!speaker.speaking)
                }
                .buttonStyle(.bordered)
            }
            Section("Will read") {
                Text(text.isEmpty ? "The note is empty." : String(text.prefix(600)) + (text.count > 600 ? "…" : ""))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .onDisappear { speaker.stop() }
    }
}

// MARK: - Text helpers

enum SNText {
    /// Rough Markdown → plain text for speaking and counting.
    static func plain(_ markdown: String) -> String {
        var lines: [String] = []
        for raw in markdown.components(separatedBy: "\n") {
            var line = raw.replacingOccurrences(of: "\u{FFFC}", with: "")
            while line.hasPrefix("#") { line.removeFirst() }
            for prefix in ["- [ ] ", "- [x] ", "- ", "* ", "> "] where line.hasPrefix(prefix) {
                line.removeFirst(prefix.count)
            }
            for token in ["**", "__", "`", "~~"] { line = line.replacingOccurrences(of: token, with: "") }
            lines.append(line.trimmingCharacters(in: .whitespaces))
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func words(_ text: String) -> [String] {
        var words: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .byWords) { word, _, _, _ in
            if let word { words.append(word) }
        }
        return words
    }
}
