import SwiftUI

@main
struct ScienceKeyboardApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    let store = SharedStore.shared

    @Published var settings: KeyboardSettings { didSet { store.settings = settings } }
    @Published var snippets: [Snippet] { didSet { store.snippets = snippets } }
    @Published var clipboard: [ClipItem] { didSet { store.clipboard = clipboard } }
    @Published var customPresets: [Preset] { didSet { store.customPresets = customPresets } }
    @Published var favorites: [String] { didSet { store.favorites = favorites } }
    @Published var toast: String?

    private var toastTask: Task<Void, Never>?

    init() {
        let s = SharedStore.shared
        settings = s.settings
        snippets = s.snippets
        clipboard = s.clipboard
        customPresets = s.customPresets
        favorites = s.favorites
    }

    var allPresets: [Preset] { PresetLibrary.builtIn + customPresets }

    var isAppGroupShared: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) != nil
    }

    func reload() {
        let s = store
        if settings != s.settings { settings = s.settings }
        if snippets != s.snippets { snippets = s.snippets }
        if clipboard != s.clipboard { clipboard = s.clipboard }
        if customPresets != s.customPresets { customPresets = s.customPresets }
        if favorites != s.favorites { favorites = s.favorites }
    }

    func copy(_ text: String) {
        UIPasteboard.general.string = text
        store.lastPasteboardChangeCount = UIPasteboard.general.changeCount
        store.addClip(text, limit: settings.clipboardLimit)
        clipboard = store.clipboard
        show(text.count <= 40 ? "Copied \(text)" : "Copied \(text.count) characters")
    }

    func show(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if !Task.isCancelled { self?.toast = nil }
        }
    }

    func captureClipboard() {
        guard let s = UIPasteboard.general.string else {
            show("Clipboard has no text")
            return
        }
        store.addClip(s, limit: settings.clipboardLimit)
        clipboard = store.clipboard
        show("Saved to history")
    }

    func toggleFavorite(_ s: String) {
        if let i = favorites.firstIndex(of: s) {
            favorites.remove(at: i)
            show("Removed from favorites")
        } else {
            favorites.insert(s, at: 0)
            show("★ Added \(s) to favorites")
        }
    }
}

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case setup, playground, symbols, periodic, builders, snippets, clipboard, converter, calculator, settings, help

    var id: String { rawValue }

    var title: String {
        switch self {
        case .setup: return "Get started"
        case .playground: return "Playground"
        case .symbols: return "Symbol browser"
        case .periodic: return "Periodic table"
        case .builders: return "Builders"
        case .snippets: return "Snippets"
        case .clipboard: return "Clipboard history"
        case .converter: return "Converter"
        case .calculator: return "Calculator"
        case .settings: return "Keyboard settings"
        case .help: return "Help & syntax"
        }
    }

    var icon: String {
        switch self {
        case .setup: return "keyboard"
        case .playground: return "pencil.and.scribble"
        case .symbols: return "character.magnify"
        case .periodic: return "atom"
        case .builders: return "wand.and.stars"
        case .snippets: return "text.quote"
        case .clipboard: return "doc.on.clipboard"
        case .converter: return "arrow.triangle.2.circlepath"
        case .calculator: return "function"
        case .settings: return "gearshape"
        case .help: return "questionmark.circle"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var phase
    @State private var selection: AppSection? = .setup

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selection) { section in
                NavigationLink(value: section) {
                    Label(section.title, systemImage: section.icon)
                }
            }
            .navigationTitle("Science Keyboard")
        } detail: {
            NavigationStack {
                detail(for: selection ?? .setup)
            }
        }
        .tint(model.settings.accent.appColor)
        .overlay(alignment: .bottom) {
            if let toast = model.toast {
                Text(toast)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: model.toast)
        .onChange(of: phase) { _, newPhase in
            if newPhase == .active { model.reload() }
        }
    }

    @ViewBuilder private func detail(for section: AppSection) -> some View {
        switch section {
        case .setup: SetupView(selection: $selection)
        case .playground: PlaygroundView()
        case .symbols: SymbolBrowserView()
        case .periodic: PeriodicTableView()
        case .builders: PresetListView()
        case .snippets: SnippetsView()
        case .clipboard: ClipboardHistoryView()
        case .converter: ConverterView()
        case .calculator: CalculatorView()
        case .settings: SettingsView()
        case .help: HelpView()
        }
    }
}

extension AccentChoice {
    var appColor: Color {
        switch self {
        case .blue: return .blue
        case .indigo: return .indigo
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return .orange
        case .green: return .green
        case .teal: return .teal
        }
    }
}

extension ElementCategory {
    var appColor: Color { Color(red: rgb.0, green: rgb.1, blue: rgb.2) }
}

// MARK: - Setup & playground

struct SetupView: View {
    @Binding var selection: AppSection?
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("αβ ∫ ⚛︎ H₂O")
                        .font(.system(size: 40, weight: .semibold))
                    Text("A full keyboard for science: iOS-style letters plus Greek, every math operator, arrows, super/subscripts, a periodic table, step-by-step builders, a calculator, clipboard history and all of Unicode.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section("Turn it on") {
                step(1, "Open Settings → General → Keyboard → Keyboards → Add New Keyboard… and pick **Science Keyboard**.")
                step(2, "Tap **Science Keyboard** in that list and turn on **Allow Full Access** (needed for clipboard history, paste, and haptics; nothing leaves your device).")
                step(3, "In any app, hold or tap the 🌐 globe key to switch to it.")
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Open Settings", systemImage: "gear")
                }
                Button {
                    selection = .playground
                } label: {
                    Label("Try it in the playground", systemImage: "pencil.and.scribble")
                }
            }

            Section("Highlights") {
                feature("function", "∑ key / top bar", "Jump between letters and 17 science panels. The bar also shows smart suggestions: type H2SO4, \\alpha, x^2, m/s2, 6.02e23 or -> and tap the suggestion.")
                feature("hand.draw", "Flick & long-press", "On iPad, swipe down on a key for its grey symbol (numbers or Greek). Long-press letters for accents and science variants.")
                feature("atom", "Chemistry", "Periodic table, nuclide/decay/ion builders, formula formatting, electron configurations.")
                feature("wand.and.stars", "Builders", "Step-by-step presets — e.g. pick U, confirm Z = 92, A = 238 → ²³⁸₉₂U. Make your own in Builders.")
                feature("doc.on.clipboard", "Clipboard & snippets", "History with pinning, copy/cut/paste selection, reusable snippets.")
                feature("character.magnify", "Everything in Unicode", "Search 7 000+ symbols by name, browse 48 Unicode blocks or type a hex code point.")
            }

            Section("Status") {
                LabeledContent("App Group sharing") {
                    Text(model.isAppGroupShared ? "Active" : "Not available")
                        .foregroundStyle(model.isAppGroupShared ? .green : .orange)
                }
                if !model.isAppGroupShared {
                    Text("The app and keyboard are signed without a shared App Group, so snippets, builders and settings made here won’t reach the keyboard. Re-sign with the App Group entitlement (see README) to enable sharing.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Get started")
    }

    private func step(_ n: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.headline)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.accentColor.opacity(0.2)))
            Text(text)
        }
    }

    private func feature(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 30)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct PlaygroundView: View {
    @AppStorage("playgroundText") private var text = ""
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Switch to Science Keyboard with the 🌐 key and try things out. Text here is kept between launches.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextEditor(text: $text)
                .font(.system(size: 20))
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
        }
        .padding()
        .navigationTitle("Playground")
        .toolbar {
            ToolbarItemGroup {
                Button("Copy all") { model.copy(text) }
                Button("Clear", role: .destructive) { text = "" }
            }
        }
    }
}
