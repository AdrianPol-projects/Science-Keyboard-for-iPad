import SwiftUI

struct KeyboardRootView: View {
    @ObservedObject var state: KeyboardState

    var body: some View {
        GeometryReader { geo in
            let pad = geo.size.width > 600
            VStack(spacing: 0) {
                TopBarView(state: state, pad: pad)
                    .frame(height: pad ? 46 : 40)
                content(pad: pad)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .tint(state.settings.accent.color)
    }

    @ViewBuilder private func content(pad: Bool) -> some View {
        switch state.screen {
        case .keys(let page):
            KeysLayoutView(state: state, page: page)
        case .panel(let panel):
            PanelContainer(state: state, panel: panel, pad: pad)
        case .wizard:
            WizardView(state: state, pad: pad)
        }
    }
}

// MARK: - Top bar

struct TopBarView: View {
    @ObservedObject var state: KeyboardState
    let pad: Bool

    var body: some View {
        Group {
            switch state.sink {
            case .search?: SearchBar(state: state)
            case .wizardField?: WizardFieldBar(state: state)
            case nil: NormalBar(state: state, pad: pad)
            }
        }
        .padding(.horizontal, 6)
    }
}

struct BarChip: View {
    let text: String
    var selected = false
    var accent = false
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = KeyPalette(scheme)
        Button(action: action) {
            Text(text)
                .font(.system(size: 15, weight: selected || accent ? .semibold : .regular))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundColor(selected ? .white : p.text)
                .background(
                    Capsule().fill(selected ? Color.accentColor : (accent ? p.letter : p.chip))
                )
        }
        .buttonStyle(.plain)
    }
}

struct NormalBar: View {
    @ObservedObject var state: KeyboardState
    let pad: Bool

    private var onKeys: Bool {
        if case .keys = state.screen { return true }
        return false
    }

    var body: some View {
        HStack(spacing: 6) {
            if let mode = state.scriptMode {
                BarChip(text: "\(mode.short) ✕", accent: true) { state.scriptMode = nil }
            }
            if let style = state.alphabet {
                BarChip(text: "\(style.apply(to: "A")) \(style.title) ✕", accent: true) { state.alphabet = nil }
            }
            if onKeys && !state.suggestions.isEmpty {
                ForEach(state.suggestions) { s in
                    BarChip(text: s.replacement, accent: true) { state.applySuggestion(s) }
                }
                Divider().frame(height: 22)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    BarChip(text: "ABC", selected: onKeys) { state.showPage(.letters) }
                    ForEach(PanelID.allCases) { panel in
                        BarChip(text: pad ? "\(panel.glyph) \(panel.title)" : panel.glyph,
                                selected: state.screen == .panel(panel)) {
                            state.feedback()
                            state.openPanel(panel)
                        }
                    }
                }
            }
            Button {
                state.feedback()
                state.beginSearch()
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
        }
    }
}

struct SearchBar: View {
    @ObservedObject var state: KeyboardState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = KeyPalette(scheme)
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundColor(p.secondaryText)
            Text(state.buffer.isEmpty ? "Search by name, e.g. nabla" : state.buffer + "▏")
                .foregroundColor(state.buffer.isEmpty ? p.secondaryText : p.text)
                .lineLimit(1)
                .frame(minWidth: 80, alignment: .leading)
            Divider().frame(height: 22)
            if !UnicodeIndex.shared.isReady {
                ProgressView().scaleEffect(0.7)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 4) {
                    ForEach(state.searchResults) { entry in
                        Button {
                            state.insertSearchResult(entry)
                        } label: {
                            Text(entry.char.displayForm)
                                .font(.system(size: 22))
                                .frame(minWidth: 36, minHeight: 34)
                                .padding(.horizontal, 2)
                        }
                        .buttonStyle(KeyCapButtonStyle(radius: 6))
                    }
                }
            }
            BarChip(text: "Done", accent: true) { state.closeSink() }
        }
    }
}

struct WizardFieldBar: View {
    @ObservedObject var state: KeyboardState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = KeyPalette(scheme)
        HStack(spacing: 6) {
            BarChip(text: "‹ Back") { state.wizardBack() }
            if let w = state.wizard, let f = w.field {
                VStack(alignment: .leading, spacing: 0) {
                    Text(f.label).font(.system(size: 11)).foregroundColor(p.secondaryText).lineLimit(1)
                    Text(w.fresh ? state.buffer : state.buffer + "▏")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(w.fresh ? p.secondaryText : p.text)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Text(w.preview)
                    .font(.system(size: 17))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundColor(p.text)
                BarChip(text: w.isLast ? "Insert" : "Next ›", accent: true) { state.wizardNext() }
            }
        }
    }
}

// MARK: - Panels

struct PanelContainer: View {
    @ObservedObject var state: KeyboardState
    let panel: PanelID
    let pad: Bool

    var body: some View {
        VStack(spacing: 0) {
            panelBody
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            UtilityRow(state: state, pad: pad)
                .frame(height: pad ? 50 : 44)
        }
    }

    @ViewBuilder private var panelBody: some View {
        switch panel {
        case .recents: RecentsPanel(state: state)
        case .scripts: ScriptsPanel(state: state)
        case .alphabets: AlphabetPanel(state: state)
        case .chemistry: ChemistryPanel(state: state, pad: pad)
        case .physics: PhysicsPanel(state: state)
        case .presets: PresetsPanel(state: state)
        case .clipboard: ClipboardPanel(state: state)
        case .snippets: SnippetsPanel(state: state)
        case .tools: ToolsPanel(state: state, pad: pad)
        case .unicode: UnicodePanel(state: state)
        case .math, .calculus:
            SymbolCategoryPanel(state: state, category: panel.symbolCategory ?? SymbolCatalog.math, builderCategory: "Math")
        default:
            SymbolCategoryPanel(state: state, category: panel.symbolCategory ?? SymbolCatalog.greek, builderCategory: nil)
        }
    }
}

struct PanelHeader<Trailing: View>: View {
    @ObservedObject var state: KeyboardState
    let title: String
    var tabs: [String] = []
    var tabKey: String = ""
    @ViewBuilder var trailing: () -> Trailing
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = KeyPalette(scheme)
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(p.text)
            if !tabs.isEmpty {
                SegmentTabs(titles: tabs, selection: state.tabBinding(tabKey))
            }
            Text(state.status)
                .font(.system(size: 12))
                .foregroundColor(p.secondaryText)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .trailing)
            trailing()
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
    }
}

extension PanelHeader where Trailing == EmptyView {
    init(state: KeyboardState, title: String, tabs: [String] = [], tabKey: String = "") {
        self.init(state: state, title: title, tabs: tabs, tabKey: tabKey, trailing: { EmptyView() })
    }
}

struct SegmentTabs: View {
    let titles: [String]
    @Binding var selection: Int
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = KeyPalette(scheme)
        HStack(spacing: 2) {
            ForEach(Array(titles.enumerated()), id: \.offset) { i, title in
                Button {
                    selection = i
                } label: {
                    Text(title)
                        .font(.system(size: 13, weight: selection == i ? .semibold : .regular))
                        .lineLimit(1)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .foregroundColor(p.text)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(selection == i ? p.letter : Color.clear)
                                .shadow(color: selection == i ? p.shadow.opacity(0.6) : .clear, radius: 0, y: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(p.chip))
        .fixedSize()
    }
}

struct SmallButton: View {
    let title: String
    var icon: String? = nil
    var selected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon { Image(systemName: icon) }
                Text(title).lineLimit(1)
            }
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .buttonStyle(KeyCapButtonStyle(kind: .function, selected: selected, radius: 7))
    }
}

// MARK: - Symbol grid

struct SymbolCell: View {
    let symbol: String
    let state: KeyboardState
    @State private var longFired = false

    var body: some View {
        Button {
            if longFired { longFired = false; return }
            state.feedback()
            state.insertSymbol(symbol)
        } label: {
            Text(symbol.displayForm)
                .font(.system(size: symbol.count > 2 ? 15 : 22))
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .padding(.horizontal, 3)
                .frame(maxWidth: .infinity, minHeight: 40)
        }
        .buttonStyle(KeyCapButtonStyle(radius: 6))
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                longFired = true
                state.toggleFavorite(symbol)
            }
        )
    }
}

struct SymbolGrid: View {
    let state: KeyboardState
    let sections: [SymbolSection]
    var minCell: CGFloat = 44
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = KeyPalette(scheme)
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                if sections.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(sections) { section in
                                Button {
                                    withAnimation { proxy.scrollTo(section.id, anchor: .top) }
                                } label: {
                                    Text(section.title)
                                        .font(.system(size: 12))
                                        .lineLimit(1)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .foregroundColor(p.text)
                                        .background(Capsule().fill(p.chip))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    .frame(height: 28)
                }
                ScrollView(.vertical) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: minCell), spacing: 6)],
                              spacing: 6, pinnedViews: [.sectionHeaders]) {
                        ForEach(sections) { section in
                            Section {
                                ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                                    SymbolCell(symbol: item, state: state)
                                }
                            } header: {
                                Text(section.title.uppercased())
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(p.header)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 4)
                                    .background(.regularMaterial)
                                    .id(section.id)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                }
            }
        }
    }
}
